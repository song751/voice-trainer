import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/domain/analysis/analysis_engine.dart';
import '../core/domain/audio/audio_capture.dart';
import '../core/domain/persistence/recording_sink.dart';
import '../core/domain/persistence/recording_store.dart';
import '../core/domain/persistence/session_repository.dart';
import '../core/domain/practice/practice_target.dart';
import '../core/domain/practice/practice_template.dart';
import '../features/live_practice/application/practice_session_coordinator.dart';
import '../infrastructure/audio/fake_audio_capture.dart';
import '../infrastructure/dsp/fake_analysis_engine.dart';
import '../infrastructure/persistence/in_memory_recording_store.dart';
import '../infrastructure/persistence/in_memory_session_repository.dart';

/// Every platform-facing implementation is exposed separately for overrides.
/// The Phase 1 shell deliberately uses deterministic fakes until a later card
/// promotes each production adapter into the composition root.
final audioCaptureProvider = Provider<AudioCapture>(
  (ref) => FakeAudioCapture(),
);

final analysisEngineProvider = Provider<AnalysisEngine>(
  (ref) => FakeAnalysisEngine(),
);

final recordingStoreProvider = Provider<RecordingStore>(
  (ref) => InMemoryRecordingStore(),
);

final recordingSinkProvider = Provider<RecordingSink>((ref) {
  final store = ref.watch(recordingStoreProvider);
  if (store is! InMemoryRecordingStore) {
    throw StateError(
      'Provide a RecordingSink override when replacing the default store.',
    );
  }
  return InMemoryRecordingSink(store);
});

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => InMemorySessionRepository(),
);

final practiceTemplateProvider = Provider<PracticeTemplate>(
  (ref) => const PracticeTemplate(
    id: 'phase1-fake-sustained-note',
    version: 1,
    kind: PracticeKind.sustainedNote,
    target: PracticeTarget(targetMidiNote: 57),
    reviewStatus: ContentReviewStatus.draft,
  ),
);

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
      sessionRepository: ref.watch(sessionRepositoryProvider),
    );
    ref.onDispose(() => unawaited(coordinator.dispose()));
    return coordinator;
  },
);
