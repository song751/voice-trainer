import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/app/app.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/app/router/app_router.dart';
import 'package:voice_trainer/app/router/route_names.dart';
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
import 'package:voice_trainer/infrastructure/persistence/in_memory_session_repository.dart';
import 'package:voice_trainer/features/song_reference/application/song_reference_controller.dart';
import 'package:voice_trainer/features/reference_comparison/application/reference_comparison_controller.dart';

void main() {
  testWidgets('A/B flow exposes gates, alignment, coverage and no score', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = InMemorySessionRepository();
    await repository.save(_session());
    final container = ProviderContainer(
      overrides: <Override>[
        appInitialLocationProvider.overrideWithValue(
          RoutePaths.referenceComparison,
        ),
        songFilePickerProvider.overrideWithValue(const _Picker(_Source())),
        songSeparatorProvider.overrideWithValue(const _Separator()),
        sessionRepositoryProvider.overrideWithValue(repository),
        referenceFeatureExtractorProvider.overrideWithValue(const _Extractor()),
        audioPreviewProvider.overrideWithValue(const UnavailableAudioPreview()),
        verifiedRecordingResolverProvider.overrideWithValue(
          const _RecordingResolver(),
        ),
        verifiedSongStemResolverProvider.overrideWithValue(
          const _StemResolver(),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Prepare the same application-state handoff used by the import page.
    final songController = container.read(
      songReferenceControllerProvider.notifier,
    );
    await songController.selectSong();
    songController.setRightsAcknowledged(true);
    await songController.separate();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const VoiceTrainerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('歌曲分离估计'), findsOneWidget);
    expect(find.byKey(const Key('comparison-session-picker')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('artifact-review-confirmed')),
      300,
    );
    await tester.tap(find.byKey(const Key('artifact-review-confirmed')));
    await tester.pump();
    expect(
      container.read(referenceComparisonControllerProvider).artifactsAcceptable,
      isTrue,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('monophonic-review-confirmed')),
      300,
    );
    await tester.tap(find.byKey(const Key('monophonic-review-confirmed')));
    await tester.pump();
    expect(
      container
          .read(referenceComparisonControllerProvider)
          .monophonicLeadConfirmed,
      isTrue,
    );
    container
        .read(referenceComparisonControllerProvider.notifier)
        .setReferenceRange(
          const PhraseRange(startSeconds: 0.5, endSeconds: 7.5),
        );
    await tester.pump();
    final resetReview = container.read(referenceComparisonControllerProvider);
    expect(resetReview.artifactsAcceptable, isFalse);
    expect(resetReview.monophonicLeadConfirmed, isFalse);
    await tester.tap(find.byKey(const Key('artifact-review-confirmed')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('monophonic-review-confirmed')));
    await tester.pump();
    container
        .read(referenceComparisonControllerProvider.notifier)
        .setUserRange(const PhraseRange(startSeconds: 0.25, endSeconds: 7.25));
    await tester.pump();
    final userRangeReset = container.read(
      referenceComparisonControllerProvider,
    );
    expect(userRangeReset.artifactsAcceptable, isFalse);
    expect(userRangeReset.monophonicLeadConfirmed, isFalse);
    await tester.tap(find.byKey(const Key('artifact-review-confirmed')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('monophonic-review-confirmed')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('run-reference-comparison')),
      300,
    );
    await tester.tap(find.byKey(const Key('run-reference-comparison')));
    await tester.pumpAndSettle();

    expect(
      container.read(referenceComparisonControllerProvider).report?.suppressed,
      isFalse,
    );

    await tester.scrollUntilVisible(find.textContaining('对齐参数'), 300);
    expect(find.textContaining('对齐参数'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('互相可比覆盖'), 300);
    expect(find.textContaining('互相可比覆盖'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('REFERENCE-AB-01'),
      300,
    );
    expect(find.textContaining('REFERENCE-AB-01'), findsOneWidget);
    expect(find.textContaining('未审核'), findsOneWidget);
    expect(find.textContaining('总分'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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

final class _Extractor implements ReferenceFeatureExtractor {
  const _Extractor();

  @override
  bool get available => true;

  @override
  Future<ReferenceAnalysisSeries> analyze({
    required VerifiedAudioLease vocals,
    required void Function(double progress) onProgress,
  }) async {
    onProgress(1);
    return ReferenceAnalysisSeries(
      sampleRate: 44100,
      frameRateHz: 100,
      algorithmVersion: 'reference-test-v1',
      frames: _frames(0),
      sourceAudioIdentity: vocals.identity,
    );
  }

  @override
  Future<void> cancel() async {}
}

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
    validFrameCount: 700,
    totalFrameCount: 800,
    targetHitRate: 0.8,
    qualityFlags: {},
  ),
  features: FeatureSeries(
    frameRateHz: 100,
    frames: _frames(200),
    sourceAudioIdentity: _identity,
  ),
  recording: const RecordingLocator(
    value: r'C:\test\practice.wav',
    storageKind: RecordingStorageKind.file,
    identity: _identity,
  ),
);

const _identity = AudioContentIdentity(
  sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  byteLength: 100,
);

final class _Lease implements VerifiedAudioLease {
  const _Lease(this.path);
  final String path;
  @override
  Uint8List get bytes => Uint8List.fromList(const <int>[1, 2, 3]);
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

final class _StemResolver implements VerifiedSongStemResolver {
  const _StemResolver();
  @override
  bool get available => true;
  @override
  Future<VerifiedAudioLease> openVerified(SongStemReference stem) async =>
      _Lease(stem.locator);
}

List<AnalysisFrame> _frames(double offset) =>
    List<AnalysisFrame>.generate(800, (index) {
      return AnalysisFrame(
        sampleIndex: index * 480,
        rmsDbfs: -24,
        peakDbfs: -18,
        pitchClarity: 0.9,
        voiced: true,
        algorithmVersion: 'user-test-v1',
        pitchCents: 5700 + offset,
      );
    });
