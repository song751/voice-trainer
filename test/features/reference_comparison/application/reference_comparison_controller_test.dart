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
      extractor: const _ImmediateExtractor(),
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

  test('resource limit is typed for comparison and preview', () async {
    final harness = await _createHarness(
      extractor: const _ImmediateExtractor(),
      recordingResolver: const _FailingRecordingResolver(
        AudioContentFailureReason.resourceLimit,
      ),
    );
    addTearDown(harness.dispose);
    final controller = harness.container.read(
      referenceComparisonControllerProvider.notifier,
    );

    await controller.compare();
    var state = harness.container.read(referenceComparisonControllerProvider);
    expect(state.report!.suppressedReason, 'user_content_resourceLimit');
    expect(
      state.report!.qualityFlags,
      contains(ReferenceComparisonQualityFlag.userResourceLimit),
    );

    await controller.previewUser();
    state = harness.container.read(referenceComparisonControllerProvider);
    expect(state.previewFailure, AudioPreviewFailureReason.resourceLimit);
  });

  test(
    'gap capture uses compact verified WAV time for range and preview',
    () async {
      final preview = _PreviewProbe();
      final harness = await _createHarness(
        extractor: const _ImmediateExtractor(),
        preview: preview,
        session: _sessionWithCaptureGap(),
      );
      addTearDown(harness.dispose);
      final controller = harness.container.read(
        referenceComparisonControllerProvider.notifier,
      );
      final loaded = harness.container.read(
        referenceComparisonControllerProvider,
      );
      expect(loaded.selectedUserMediaDuration, 3);
      expect(loaded.userRange.endSeconds, 3);

      const mediaRange = PhraseRange(startSeconds: 2, endSeconds: 2.5);
      controller.setUserRange(mediaRange);
      await controller.previewUser();
      expect(preview.playedRanges.single.startSeconds, 2);
      expect(preview.playedRanges.single.endSeconds, 2.5);
    },
  );

  test('duration verification opens only the selected session', () async {
    final resolver = _CountingRecordingResolver();
    final harness = await _createHarness(
      extractor: const _ImmediateExtractor(),
      recordingResolver: resolver,
      additionalSession: _olderSession(),
    );
    addTearDown(harness.dispose);
    expect(resolver.openedLocators, <String>[r'C:\test\practice.wav']);

    await harness.container
        .read(referenceComparisonControllerProvider.notifier)
        .selectSession('session-older');
    expect(resolver.openedLocators, <String>[
      r'C:\test\practice.wav',
      r'C:\test\older.wav',
    ]);
  });

  test('comparison and preview dispose verified bytes immediately', () async {
    final loadingLease = _Lease(r'C:\test\practice.wav');
    final referenceLease = _Lease(r'C:\test\vocals.wav');
    final comparisonUserLease = _Lease(r'C:\test\practice.wav');
    final previewUserLease = _Lease(r'C:\test\practice.wav');
    final recordingResolver = _LeaseQueueRecordingResolver(
      <_Lease>[loadingLease, comparisonUserLease, previewUserLease],
      onOpen: (openCall) {
        if (openCall == 2) expect(referenceLease.disposeCalls, 1);
      },
    );
    final harness = await _createHarness(
      extractor: const _ImmediateExtractor(),
      recordingResolver: recordingResolver,
      stemResolver: _LeaseStemResolver(referenceLease),
    );
    addTearDown(harness.dispose);
    final controller = harness.container.read(
      referenceComparisonControllerProvider.notifier,
    );
    controller
      ..setArtifactsAcceptable(true)
      ..setMonophonicLeadConfirmed(true);

    await controller.compare();
    await controller.previewUser();

    expect(referenceLease.disposeCalls, 1);
    expect(loadingLease.disposeCalls, 1);
    expect(comparisonUserLease.disposeCalls, 1);
    expect(previewUserLease.disposeCalls, 1);
  });
}

Future<_Harness> _createHarness({
  required ReferenceFeatureExtractor extractor,
  AudioPreview? preview,
  PracticeSessionRecord? session,
  VerifiedRecordingResolver? recordingResolver,
  VerifiedSongStemResolver? stemResolver,
  PracticeSessionRecord? additionalSession,
}) async {
  final repository = InMemorySessionRepository();
  await repository.save(session ?? _session());
  if (additionalSession != null) await repository.save(additionalSession);
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
      verifiedSongStemResolverProvider.overrideWithValue(
        stemResolver ?? const _StemResolver(),
      ),
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

final class _ImmediateExtractor implements ReferenceFeatureExtractor {
  const _ImmediateExtractor();

  @override
  bool get available => true;

  @override
  Future<ReferenceAnalysisSeries> analyze({
    required VerifiedAudioLease vocals,
    required void Function(double progress) onProgress,
  }) async => _series();

  @override
  Future<void> cancel() async {}
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
  final playedRanges = <PhraseRange>[];
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
    events.add('play:${(source as _Lease).path}');
    playedRanges.add(range);
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

PracticeSessionRecord _sessionWithCaptureGap() {
  final session = _session();
  final frames = _frames();
  final discontinuous = List<AnalysisFrame>.generate(frames.length, (index) {
    final frame = frames[index];
    return AnalysisFrame(
      sampleIndex: frame.sampleIndex + (index < 150 ? 0 : 48_000),
      rmsDbfs: frame.rmsDbfs,
      peakDbfs: frame.peakDbfs,
      pitchClarity: frame.pitchClarity,
      voiced: frame.voiced,
      algorithmVersion: frame.algorithmVersion,
      pitchCents: frame.pitchCents,
    );
  });
  return PracticeSessionRecord(
    id: session.id,
    template: session.template,
    startedAt: session.startedAt,
    summary: session.summary,
    features: FeatureSeries(
      frameRateHz: 100,
      frames: discontinuous,
      sourceAudioIdentity: _identity,
    ),
    recording: session.recording,
  );
}

PracticeSessionRecord _olderSession() {
  final session = _session();
  return PracticeSessionRecord(
    id: 'session-older',
    template: session.template,
    startedAt: DateTime.utc(2026, 8, 26),
    summary: session.summary,
    features: session.features,
    recording: const RecordingLocator(
      value: r'C:\test\older.wav',
      storageKind: RecordingStorageKind.file,
      identity: _identity,
    ),
  );
}

const _identity = AudioContentIdentity(
  sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  byteLength: 100,
);

final class _Lease implements VerifiedAudioLease {
  _Lease(this.path);

  final String path;
  var disposeCalls = 0;

  @override
  Uint8List get bytes => _wavBytes(sampleRate: 100, frameCount: 300);

  @override
  AudioContentIdentity get identity => _identity;

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

Uint8List _wavBytes({required int sampleRate, required int frameCount}) {
  final dataBytes = frameCount * 2;
  final bytes = Uint8List(44 + dataBytes);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  data.setUint32(4, 36 + dataBytes, Endian.little);
  bytes.setRange(8, 12, 'WAVE'.codeUnits);
  bytes.setRange(12, 16, 'fmt '.codeUnits);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, 'data'.codeUnits);
  data.setUint32(40, dataBytes, Endian.little);
  return bytes;
}

final class _RecordingResolver implements VerifiedRecordingResolver {
  const _RecordingResolver();

  @override
  bool get available => true;

  @override
  Future<VerifiedAudioLease> openVerified(RecordingLocator locator) async =>
      _Lease(locator.value);
}

final class _CountingRecordingResolver implements VerifiedRecordingResolver {
  final openedLocators = <String>[];

  @override
  bool get available => true;

  @override
  Future<VerifiedAudioLease> openVerified(RecordingLocator locator) async {
    openedLocators.add(locator.value);
    return _Lease(locator.value);
  }
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

final class _LeaseQueueRecordingResolver implements VerifiedRecordingResolver {
  _LeaseQueueRecordingResolver(this.leases, {this.onOpen});

  final List<_Lease> leases;
  final void Function(int openCall)? onOpen;
  var _openCalls = 0;

  @override
  bool get available => true;

  @override
  Future<VerifiedAudioLease> openVerified(RecordingLocator locator) async {
    _openCalls++;
    onOpen?.call(_openCalls);
    return leases.removeAt(0);
  }
}

final class _LeaseStemResolver implements VerifiedSongStemResolver {
  const _LeaseStemResolver(this.lease);

  final _Lease lease;

  @override
  bool get available => true;

  @override
  Future<VerifiedAudioLease> openVerified(SongStemReference stem) async =>
      lease;
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
