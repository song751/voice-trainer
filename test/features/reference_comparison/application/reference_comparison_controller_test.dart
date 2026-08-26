import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/analysis/feature_series.dart';
import 'package:voice_trainer/core/domain/analysis/session_summary.dart';
import 'package:voice_trainer/core/domain/persistence/recording_locator.dart';
import 'package:voice_trainer/core/domain/persistence/audio_content_identity.dart';
import 'package:voice_trainer/core/domain/persistence/verified_recording_resolver.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/core/domain/reference/reference_comparison.dart';
import 'package:voice_trainer/core/domain/reference/song_reference.dart';
import 'package:voice_trainer/features/reference_comparison/application/reference_comparison_controller.dart';
import 'package:voice_trainer/features/song_reference/application/song_reference_controller.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_session_repository.dart';

void main() {
  test('newer load invalidates an in-flight comparison result', () async {
    final extractor = _DelayedExtractor();
    final harness = await _createHarness(extractor: extractor);
    addTearDown(harness.dispose);
    final controller = harness.container.read(
      referenceComparisonControllerProvider.notifier,
    );
    controller
      ..setArtifactsAcceptable(true)
      ..setMonophonicLeadConfirmed(true);

    final comparison = controller.compare();
    await extractor.started.future;
    await controller.loadSessions();
    extractor.complete(_series());
    await comparison;

    final state = harness.container.read(referenceComparisonControllerProvider);
    expect(state.status, ReferenceComparisonStatus.ready);
    expect(state.report, isNull);
  });

  test('dispose cancels extraction and stops queued playback', () async {
    final extractor = _DelayedExtractor();
    final preview = _PreviewProbe();
    final harness = await _createHarness(
      extractor: extractor,
      preview: preview,
    );
    final controller = harness.container.read(
      referenceComparisonControllerProvider.notifier,
    );
    controller
      ..setArtifactsAcceptable(true)
      ..setMonophonicLeadConfirmed(true);

    final comparison = controller.compare();
    await extractor.started.future;
    harness.dispose();
    await comparison;
    await Future<void>.delayed(Duration.zero);

    expect(extractor.cancelCalls, 1);
    expect(preview.stopCalls, 1);
  });

  test(
    'rapid preview requests serialize and only play the latest source',
    () async {
      final preview = _PreviewProbe(blockFirstStop: true);
      final harness = await _createHarness(
        extractor: _DelayedExtractor(),
        preview: preview,
      );
      addTearDown(harness.dispose);
      final controller = harness.container.read(
        referenceComparisonControllerProvider.notifier,
      );

      final referencePreview = controller.previewReference();
      await preview.firstStopStarted.future;
      final userPreview = controller.previewUser();
      preview.releaseFirstStop();
      await Future.wait(<Future<void>>[referencePreview, userPreview]);

      expect(preview.events, <String>[
        'stop',
        'stop',
        r'play:C:\test\practice.wav',
      ]);
    },
  );

  test('legacy-unbound recording produces a metric-free report', () async {
    final harness = await _createHarness(
      extractor: _DelayedExtractor(),
      session: _legacySession(),
    );
    addTearDown(harness.dispose);
    final controller = harness.container.read(
      referenceComparisonControllerProvider.notifier,
    );
    controller
      ..setArtifactsAcceptable(true)
      ..setMonophonicLeadConfirmed(true);

    await controller.compare();
    final report = harness.container
        .read(referenceComparisonControllerProvider)
        .report!;
    expect(report.suppressed, isTrue);
    expect(report.metrics, isNull);
    expect(
      report.recommendations.map((item) => item.exerciseId),
      isNot(contains('REFERENCE-AB-01')),
    );
  });

  test('verified file mismatch produces typed suppression', () async {
    final harness = await _createHarness(
      extractor: _DelayedExtractor(),
      recordingResolver: const _FailingRecordingResolver(
        AudioContentFailureReason.hashMismatch,
      ),
    );
    addTearDown(harness.dispose);
    final controller = harness.container.read(
      referenceComparisonControllerProvider.notifier,
    );
    controller
      ..setArtifactsAcceptable(true)
      ..setMonophonicLeadConfirmed(true);

    await controller.compare();
    final report = harness.container
        .read(referenceComparisonControllerProvider)
        .report!;
    expect(report.suppressedReason, 'user_content_hashMismatch');
    expect(report.metrics, isNull);
  });
}

Future<_Harness> _createHarness({
  required ReferenceFeatureExtractor extractor,
  AudioPreview? preview,
  PracticeSessionRecord? session,
  VerifiedRecordingResolver? recordingResolver,
}) async {
  final repository = InMemorySessionRepository();
  await repository.save(session ?? _session());
  final container = ProviderContainer(
    overrides: <Override>[
      songFilePickerProvider.overrideWithValue(const _Picker(_Source())),
      songSeparatorProvider.overrideWithValue(const _Separator()),
      sessionRepositoryProvider.overrideWithValue(repository),
      referenceFeatureExtractorProvider.overrideWithValue(extractor),
      audioPreviewProvider.overrideWithValue(preview ?? _PreviewProbe()),
      verifiedRecordingResolverProvider.overrideWithValue(
        recordingResolver ?? const _RecordingResolver(),
      ),
      verifiedSongStemResolverProvider.overrideWithValue(const _StemResolver()),
    ],
  );
  final subscription = container.listen(
    referenceComparisonControllerProvider,
    (_, _) {},
    fireImmediately: true,
  );
  final songController = container.read(
    songReferenceControllerProvider.notifier,
  );
  await songController.selectSong();
  songController.setRightsAcknowledged(true);
  await songController.separate();
  await container
      .read(referenceComparisonControllerProvider.notifier)
      .loadSessions();
  return _Harness(container, subscription);
}

final class _Harness {
  _Harness(this.container, this.subscription);

  final ProviderContainer container;
  final ProviderSubscription<ReferenceComparisonState> subscription;
  var _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    subscription.close();
    container.dispose();
  }
}

final class _DelayedExtractor implements ReferenceFeatureExtractor {
  final started = Completer<void>();
  final _result = Completer<ReferenceAnalysisSeries>();
  var cancelCalls = 0;
  var _analysisStarted = false;

  @override
  bool get available => true;

  @override
  Future<ReferenceAnalysisSeries> analyze({
    required VerifiedAudioLease vocals,
    required void Function(double progress) onProgress,
  }) {
    _analysisStarted = true;
    if (!started.isCompleted) started.complete();
    return _result.future;
  }

  void complete(ReferenceAnalysisSeries series) {
    if (!_result.isCompleted) _result.complete(series);
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    if (_analysisStarted && !_result.isCompleted) {
      _result.completeError(
        const ReferenceAnalysisFailure(
          ReferenceAnalysisFailureReason.cancelled,
        ),
      );
    }
  }
}

final class _PreviewProbe implements AudioPreview {
  _PreviewProbe({this.blockFirstStop = false});

  final bool blockFirstStop;
  final events = <String>[];
  final firstStopStarted = Completer<void>();
  final _firstStopRelease = Completer<void>();
  var stopCalls = 0;

  @override
  bool get available => true;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playFile({
    required VerifiedAudioLease source,
    required PhraseRange range,
  }) async {
    events.add('play:${source.path}');
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    events.add('stop');
    if (blockFirstStop && stopCalls == 1) {
      firstStopStarted.complete();
      await _firstStopRelease.future;
    }
  }

  void releaseFirstStop() {
    if (!_firstStopRelease.isCompleted) _firstStopRelease.complete();
  }
}

final class _Picker implements SongFilePicker {
  const _Picker(this.source);
  final SongFileSource source;

  @override
  Future<SongFileSource?> pickSong() async => source;
}

final class _Source implements SongFileSource {
  const _Source();

  @override
  String get displayName => 'licensed.wav';

  @override
  Future<int> length() async => 1024;

  @override
  Stream<List<int>> openRead() => Stream.value(Uint8List(16));
}

final class _Separator implements SongSeparator, SongModelManager {
  const _Separator();

  @override
  bool get automaticSeparationAvailable => true;

  @override
  Future<void> cancel() async {}

  @override
  Future<SongModelStatus> installModel(SongFileSource source) async => probe();

  @override
  Future<SongModelStatus> probe() async => const SongModelStatus(
    availability: SongModelAvailability.ready,
    modelId: 'umxhq-vocals',
  );

  @override
  Future<SeparatedSongReference> separate({
    required SongFileSource source,
    required bool rightsAcknowledged,
    required void Function(double progress) onProgress,
  }) async => const SeparatedSongReference(
    displayName: 'licensed.wav',
    generatedByModel: true,
    modelId: 'umxhq-vocals',
    algorithmVersion: 'srd04-v1',
    sampleRate: 44100,
    channels: 2,
    durationSamples: 44100 * 8,
    artifactWarning: true,
    vocals: SongStemReference(
      locator: r'C:\test\vocals.wav',
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      byteLength: 100,
    ),
  );
}

ReferenceAnalysisSeries _series() => ReferenceAnalysisSeries(
  sampleRate: 44100,
  frameRateHz: 100,
  algorithmVersion: 'reference-test-v1',
  frames: _frames(),
  sourceAudioIdentity: _identity,
);

PracticeSessionRecord _session() => PracticeSessionRecord(
  id: 'session-1',
  template: const PracticeTemplate(
    id: 'phrase',
    version: 1,
    kind: PracticeKind.sustainedNote,
    target: PracticeTarget(targetMidiNote: 57),
    reviewStatus: ContentReviewStatus.draft,
  ),
  startedAt: DateTime.utc(2026, 8, 27),
  summary: SessionSummary(
    validFrameCount: 300,
    totalFrameCount: 300,
    targetHitRate: 1,
    qualityFlags: {},
  ),
  features: FeatureSeries(
    frameRateHz: 100,
    frames: _frames(),
    sourceAudioIdentity: _identity,
  ),
  recording: const RecordingLocator(
    value: r'C:\test\practice.wav',
    storageKind: RecordingStorageKind.file,
    identity: _identity,
  ),
);

PracticeSessionRecord _legacySession() {
  final current = _session();
  return PracticeSessionRecord(
    id: current.id,
    template: current.template,
    startedAt: current.startedAt,
    summary: current.summary,
    features: FeatureSeries(
      frameRateHz: current.features.frameRateHz,
      frames: current.features.frames,
    ),
    recording: RecordingLocator(
      value: current.recording!.value,
      storageKind: current.recording!.storageKind,
    ),
  );
}

const _identity = AudioContentIdentity(
  sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  byteLength: 100,
);

final class _Lease implements VerifiedAudioLease {
  const _Lease(this.path);

  @override
  final String path;

  @override
  AudioContentIdentity get identity => _identity;

  @override
  Future<void> dispose() async {}
}

final class _RecordingResolver implements VerifiedRecordingResolver {
  const _RecordingResolver();

  @override
  bool get available => true;

  @override
  Future<VerifiedAudioLease> openVerified(RecordingLocator locator) async =>
      _Lease(locator.value);
}

final class _FailingRecordingResolver implements VerifiedRecordingResolver {
  const _FailingRecordingResolver(this.reason);

  final AudioContentFailureReason reason;

  @override
  bool get available => true;

  @override
  Future<VerifiedAudioLease> openVerified(RecordingLocator locator) async {
    throw AudioContentFailure(reason);
  }
}

final class _StemResolver implements VerifiedSongStemResolver {
  const _StemResolver();

  @override
  bool get available => true;

  @override
  Future<VerifiedAudioLease> openVerified(SongStemReference stem) async =>
      _Lease(stem.locator);
}

List<AnalysisFrame> _frames() => List<AnalysisFrame>.generate(
  300,
  (index) => AnalysisFrame(
    sampleIndex: index * 480,
    rmsDbfs: -24,
    peakDbfs: -18,
    pitchClarity: 0.9,
    voiced: true,
    algorithmVersion: 'test-v1',
    pitchCents: 5700,
  ),
);
