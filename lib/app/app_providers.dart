import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/domain/analysis/analysis_engine.dart';
import '../core/domain/observation/observation_engine.dart';
import '../core/domain/audio/audio_capture.dart';
import '../core/domain/persistence/recording_sink.dart';
import '../core/domain/persistence/recording_store.dart';
import '../core/domain/persistence/session_repository.dart';
import '../core/domain/persistence/voice_comparison_plan_store.dart';
import '../core/domain/practice/practice_target.dart';
import '../core/domain/practice/practice_template.dart';
import '../core/domain/reference/song_reference.dart';
import '../core/errors/app_exception.dart';
import '../core/logging/app_logger.dart';
import '../core/platform/platform_capabilities.dart';
import '../core/platform/application_lifecycle.dart';
import '../features/live_practice/application/practice_session_coordinator.dart';
import '../features/voice_comparison/application/active_voice_comparison_take.dart';
import '../features/session_result/application/deterministic_observation_engine.dart';
import '../infrastructure/audio_import/file_selector_song_picker.dart';
import '../infrastructure/audio_import/file_selector_song_model_picker.dart';
import '../infrastructure/song_separation/default_song_separator.dart';
import 'default_adapters.dart';
import 'default_lifecycle.dart';
import 'default_persistence.dart';
import 'platform_capabilities.dart';

/// The sole application-level platform detector. Features and presentation
/// consume this immutable profile instead of importing platform APIs.
final platformCapabilitiesProvider = Provider<PlatformCapabilities>(
  (ref) => createDefaultPlatformCapabilities(),
);

/// Every platform-facing implementation is exposed separately for overrides.
/// Windows defaults to the P3 production capture/DSP pair; tests and other
/// platforms retain explicit deterministic replacements until their gates.
final audioCaptureProvider = Provider<AudioCapture>(
  (ref) => createDefaultAudioCapture(ref.watch(platformCapabilitiesProvider)),
);

final analysisEngineProvider = Provider<AnalysisEngine>(
  (ref) => createDefaultAnalysisEngine(ref.watch(platformCapabilitiesProvider)),
);

final applicationLifecycleProvider = Provider<ApplicationLifecycle>((ref) {
  final lifecycle = createDefaultApplicationLifecycle(
    ref.watch(platformCapabilitiesProvider),
  );
  unawaited(lifecycle.initialize());
  ref.onDispose(() => unawaited(lifecycle.dispose()));
  return lifecycle;
});

final applicationLifecycleEventsProvider =
    StreamProvider<ApplicationLifecycleEvent>((ref) {
      return ref.watch(applicationLifecycleProvider).events;
    });

final defaultPersistenceAdaptersProvider = Provider<DefaultPersistenceAdapters>(
  (ref) {
    final adapters = createDefaultPersistenceAdapters(
      ref.watch(platformCapabilitiesProvider),
    );
    ref.onDispose(() => unawaited(adapters.dispose()));
    return adapters;
  },
);

final recordingStoreProvider = Provider<RecordingStore>(
  (ref) => ref.watch(defaultPersistenceAdaptersProvider).recordingStore,
);

final recordingSinkProvider = Provider<RecordingSink>(
  (ref) => ref.watch(defaultPersistenceAdaptersProvider).recordingSink,
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => ref.watch(defaultPersistenceAdaptersProvider).sessionRepository,
);

final voiceComparisonPlanStoreProvider = Provider<VoiceComparisonPlanStore>(
  (ref) =>
      ref.watch(defaultPersistenceAdaptersProvider).voiceComparisonPlanStore,
);

final appErrorMapperProvider = Provider<AppErrorMapper>(
  (ref) => const AppErrorMapper(),
);

final appLoggerProvider = Provider<AppLogger>((ref) => AppLogger());

final observationEngineProvider = Provider<ObservationEngine>(
  (ref) => const DeterministicObservationEngine(),
);

final songFilePickerProvider = Provider<SongFilePicker>(
  (ref) => const FileSelectorSongPicker(),
);

final songModelFilePickerProvider = Provider<FileSelectorSongModelPicker>(
  (ref) => const FileSelectorSongModelPicker(),
);

/// Replaced by a platform model runtime only after its weights, operators,
/// numerical parity and license gates pass. The fallback reports a typed
/// unavailable result and never fabricates stems.
final songSeparatorProvider = Provider<SongSeparator>(
  (ref) => createDefaultSongSeparator(ref.watch(platformCapabilitiesProvider)),
);

final songModelManagerProvider = Provider<SongModelManager>((ref) {
  final separator = ref.watch(songSeparatorProvider);
  if (separator is SongModelManager) return separator as SongModelManager;
  return const UnavailableSongSeparator();
});

final practiceTemplateProvider = Provider<PracticeTemplate>((ref) {
  final comparison = ref.watch(activeVoiceComparisonTakeProvider);
  if (comparison != null) {
    return PracticeTemplate(
      id: 'voice-comparison-${comparison.plan.scope.protocolId}',
      version: comparison.plan.schemaVersion,
      kind: PracticeKind.targetNote,
      target: PracticeTarget(
        targetMidiNote: switch (comparison.plan.scope.pitchContextKey) {
          'C4' => 60,
          'E4' => 64,
          _ => 57,
        },
      ),
      reviewStatus: ContentReviewStatus.draft,
    );
  }
  return const PracticeTemplate(
    id: 'phase1-fake-sustained-note',
    version: 1,
    kind: PracticeKind.sustainedNote,
    target: PracticeTarget(targetMidiNote: 57),
    reviewStatus: ContentReviewStatus.draft,
  );
});

final sessionIdGeneratorProvider = Provider<String Function()>(
  (ref) =>
      () => 'session-${DateTime.now().microsecondsSinceEpoch}',
);

final practiceSessionCoordinatorProvider = Provider<PracticeSessionCoordinator>(
  (ref) {
    final coordinator = PracticeSessionCoordinator(
      audioCapture: ref.watch(audioCaptureProvider),
      analysisEngine: ref.watch(analysisEngineProvider),
      recordingSink: ref.watch(recordingSinkProvider),
      recordingStore: ref.watch(recordingStoreProvider),
      sessionRepository: ref.watch(sessionRepositoryProvider),
    );
    ref.onDispose(() => unawaited(coordinator.dispose()));
    return coordinator;
  },
);
