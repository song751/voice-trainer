import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_quality_flag.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/core/errors/failure.dart';
import 'package:voice_trainer/core/platform/application_lifecycle.dart';
import 'package:voice_trainer/features/live_practice/application/practice_session_coordinator.dart';
import 'package:voice_trainer/features/live_practice/domain/practice_session_state.dart';
import 'package:voice_trainer/infrastructure/audio/fake_audio_capture.dart';
import 'package:voice_trainer/infrastructure/dsp/fake_analysis_engine.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_recording_store.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_session_repository.dart';

void main() {
  test(
    'hidden page pauses at sample checkpoint and requires visible recovery',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.coordinator.start(_request('hidden'));
      fixture.capture.emit(_chunk(0, 0));
      await _drain();

      await fixture.coordinator.handleLifecycleEvent(
        _event(ApplicationLifecycleEventKind.pageHidden),
      );
      final interrupted = fixture.coordinator.state as Paused;
      expect(
        interrupted.interruption?.reason,
        SessionInterruptionReason.pageHidden,
      );
      expect(interrupted.interruption?.sampleIndex, 4);
      expect(interrupted.interruption?.recoveryReady, isFalse);
      await expectLater(
        fixture.coordinator.resume(),
        throwsA(isA<InvalidSessionTransition>()),
      );

      await fixture.coordinator.handleLifecycleEvent(
        _event(ApplicationLifecycleEventKind.pageVisible),
      );
      expect(
        (fixture.coordinator.state as Paused).interruption?.recoveryReady,
        isTrue,
      );
      expect(await fixture.coordinator.resume(), isA<Running>());
      fixture.capture.emit(_chunk(1, 4));
      await _drain();
      expect(await fixture.coordinator.stop(), isA<Completed>());
      final record = await fixture.repository.findById('hidden');
      expect(
        record!.summary.qualityFlags,
        contains(AnalysisQualityFlag.discontinuity),
      );
    },
  );

  test('permission revocation and worker recovery remain typed', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final checkpoints = <SessionInterruption>[];
    final subscription = fixture.coordinator.lifecycleCheckpoints.listen(
      checkpoints.add,
    );
    addTearDown(subscription.cancel);
    await fixture.coordinator.start(_request('typed'));

    await fixture.coordinator.handleLifecycleEvent(
      _event(ApplicationLifecycleEventKind.workerRecovered),
    );
    expect(checkpoints, isEmpty);

    await fixture.coordinator.handleLifecycleEvent(
      _event(ApplicationLifecycleEventKind.workerInterrupted),
    );
    await fixture.coordinator.handleLifecycleEvent(
      _event(ApplicationLifecycleEventKind.workerRecovered),
    );
    expect(
      checkpoints.map((item) => item.reason),
      everyElement(SessionInterruptionReason.workerRestarted),
    );
    expect(checkpoints.map((item) => item.recoveryReady), <bool>[false, true]);

    await fixture.coordinator.handleLifecycleEvent(
      _event(ApplicationLifecycleEventKind.microphonePermissionDenied),
    );
    final failed = fixture.coordinator.state as Failed;
    expect(failed.failure, isA<PermissionDeniedFailure>());
  });
}

final class _Fixture {
  _Fixture() {
    repository = InMemorySessionRepository(recordingStore: store);
    coordinator = PracticeSessionCoordinator(
      audioCapture: capture,
      analysisEngine: FakeAnalysisEngine(),
      recordingSink: InMemoryRecordingSink(store),
      recordingStore: store,
      sessionRepository: repository,
    );
  }

  final capture = FakeAudioCapture();
  final store = InMemoryRecordingStore();
  late final InMemorySessionRepository repository;
  late final PracticeSessionCoordinator coordinator;

  Future<void> dispose() async {
    await coordinator.dispose();
  }
}

ApplicationLifecycleEvent _event(ApplicationLifecycleEventKind kind) =>
    ApplicationLifecycleEvent(kind: kind);

PracticeSessionRequest _request(String id) => PracticeSessionRequest(
  sessionId: id,
  template: const PracticeTemplate(
    id: 'web-lifecycle',
    version: 1,
    kind: PracticeKind.targetNote,
    target: PracticeTarget(targetMidiNote: 57),
    reviewStatus: ContentReviewStatus.reviewed,
  ),
  startedAt: DateTime.utc(2026, 8, 27),
);

PcmChunk _chunk(int sequence, int firstSample) => PcmChunk(
  sequenceNumber: sequence,
  firstSampleIndex: firstSample,
  format: const CaptureFormat(sampleRate: 48000, channels: 1),
  bytes: Uint8List(8),
  captureMonotonicTime: Duration(milliseconds: sequence * 10),
);

Future<void> _drain() async {
  for (var index = 0; index < 6; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
