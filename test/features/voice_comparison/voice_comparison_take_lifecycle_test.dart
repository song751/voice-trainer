import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/core/domain/analysis/voice_comparison.dart';
import 'package:voice_trainer/core/domain/analysis/voice_production_profile.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/errors/failure.dart';
import 'package:voice_trainer/features/live_practice/application/live_practice_controller.dart';
import 'package:voice_trainer/features/live_practice/application/practice_session_coordinator.dart';
import 'package:voice_trainer/features/live_practice/domain/practice_session_state.dart';
import 'package:voice_trainer/features/voice_comparison/application/active_voice_comparison_take.dart';
import 'package:voice_trainer/infrastructure/audio/fake_audio_capture.dart';
import 'package:voice_trainer/infrastructure/dsp/fake_analysis_engine.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_recording_store.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_session_repository.dart';

void main() {
  test(
    'completed take clears active side after preserving its snapshot',
    () async {
      final capture = FakeAudioCapture();
      final setup = _setup(capture);
      addTearDown(setup.dispose);
      setup.container.read(activeVoiceComparisonTakeProvider.notifier).state =
          _takeContext;

      final controller = setup.container.read(
        livePracticeControllerProvider.notifier,
      );
      await controller.start();
      capture.emit(_chunk);
      await _drainMicrotasks();
      await controller.stop();

      expect(
        setup.container.read(livePracticeControllerProvider),
        isA<Completed>(),
      );
      expect(setup.container.read(activeVoiceComparisonTakeProvider), isNull);
      final saved = await setup.repository.findById('comparison-lifecycle');
      expect(saved?.voiceComparison?.side, VoiceComparisonSide.a);
      expect(saved?.voiceComparison?.plan.hasSameSnapshotAs(_plan), isTrue);
    },
  );

  test('unrecoverable start failure clears the active side', () async {
    final setup = _setup(
      FakeAudioCapture(
        startFailure: const CaptureFailure(
          CaptureFailureReason.deviceUnavailable,
          isRecoverable: false,
        ),
      ),
    );
    addTearDown(setup.dispose);
    setup.container.read(activeVoiceComparisonTakeProvider.notifier).state =
        _takeContext;

    await setup.container.read(livePracticeControllerProvider.notifier).start();

    final state = setup.container.read(livePracticeControllerProvider);
    expect(state, isA<Failed>());
    expect((state as Failed).canRetry, isFalse);
    expect(setup.container.read(activeVoiceComparisonTakeProvider), isNull);
  });

  test('recoverable failure retains side for an explicit retry', () async {
    final setup = _setup(
      FakeAudioCapture(
        startFailure: const CaptureFailure(
          CaptureFailureReason.deviceUnavailable,
        ),
      ),
    );
    addTearDown(setup.dispose);
    setup.container.read(activeVoiceComparisonTakeProvider.notifier).state =
        _takeContext;

    await setup.container.read(livePracticeControllerProvider.notifier).start();

    expect(setup.container.read(livePracticeControllerProvider), isA<Failed>());
    expect(
      setup.container.read(activeVoiceComparisonTakeProvider),
      _takeContext,
    );
  });
}

final class _Setup {
  const _Setup(this.container, this.coordinator, this.repository);

  final ProviderContainer container;
  final PracticeSessionCoordinator coordinator;
  final InMemorySessionRepository repository;

  Future<void> dispose() async {
    container.dispose();
    await coordinator.dispose();
  }
}

_Setup _setup(FakeAudioCapture capture) {
  final store = InMemoryRecordingStore();
  final repository = InMemorySessionRepository(recordingStore: store);
  final coordinator = PracticeSessionCoordinator(
    audioCapture: capture,
    analysisEngine: FakeAnalysisEngine(),
    recordingSink: InMemoryRecordingSink(store),
    recordingStore: store,
    sessionRepository: repository,
  );
  final container = ProviderContainer(
    overrides: <Override>[
      practiceSessionCoordinatorProvider.overrideWithValue(coordinator),
      sessionRepositoryProvider.overrideWithValue(repository),
      sessionIdGeneratorProvider.overrideWithValue(
        () => 'comparison-lifecycle',
      ),
      applicationLifecycleEventsProvider.overrideWith(
        (ref) => const Stream.empty(),
      ),
    ],
  );
  return _Setup(container, coordinator, repository);
}

final _plan = VoiceComparisonPlan(
  id: 'lifecycle-plan',
  labelA: _label(VoiceIntentKey.weakMix),
  labelB: _label(VoiceIntentKey.strongMix),
  scope: VoiceProductionScope(
    protocolId: 'VP-MIX-01@1',
    taskKind: VoiceProductionTaskKind.matchedPitchContrast,
    pitchContextKey: 'A3',
    vowelIpa: 'a',
    loudnessConditionKey: 'medium',
    styleContextKey: 'pop',
    captureProfileKey: 'same-device-15cm',
    algorithmVersion: 'realtime-analysis-v1',
  ),
  updatedAt: DateTime.utc(2026, 8, 27),
);

final _takeContext = VoiceComparisonTakeContext(
  plan: _plan,
  side: VoiceComparisonSide.a,
);

PedagogicalVoiceLabel _label(VoiceIntentKey intent) => PedagogicalVoiceLabel(
  labelKey: intent.name,
  vocabularyId: 'teacher-li',
  vocabularyVersion: '2',
  source: PedagogicalLabelSource.teacherPrompt,
);

final _chunk = PcmChunk(
  sequenceNumber: 0,
  firstSampleIndex: 0,
  format: const CaptureFormat(sampleRate: 48000, channels: 1),
  bytes: Uint8List(8),
  captureMonotonicTime: Duration.zero,
);

Future<void> _drainMicrotasks() async {
  for (var index = 0; index < 6; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
