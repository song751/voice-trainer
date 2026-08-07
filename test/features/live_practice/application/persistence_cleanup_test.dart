import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/domain/persistence/recording_locator.dart';
import 'package:voice_trainer/core/domain/persistence/recording_sink.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/features/live_practice/application/practice_session_coordinator.dart';
import 'package:voice_trainer/features/live_practice/domain/practice_session_state.dart';
import 'package:voice_trainer/infrastructure/audio/fake_audio_capture.dart';
import 'package:voice_trainer/infrastructure/dsp/fake_analysis_engine.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_recording_store.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_session_repository.dart';

void main() {
  test(
    'database save failure removes the finalized recording reference',
    () async {
      final capture = FakeAudioCapture();
      final store = InMemoryRecordingStore();
      final sink = InMemoryRecordingSink(store);
      final coordinator = PracticeSessionCoordinator(
        audioCapture: capture,
        analysisEngine: FakeAnalysisEngine(),
        recordingSink: sink,
        recordingStore: store,
        sessionRepository: _FailingSessionRepository(),
      );
      addTearDown(coordinator.dispose);

      expect(await coordinator.start(_request()), isA<Running>());
      capture.emit(
        PcmChunk(
          sequenceNumber: 0,
          firstSampleIndex: 0,
          format: const CaptureFormat(sampleRate: 48000, channels: 1),
          bytes: Uint8List(8),
          captureMonotonicTime: Duration.zero,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(await coordinator.stop(), isA<Failed>());
      expect(await store.exists(_locator), isFalse);
    },
  );

  test(
    'append failure stops capture and aborts the partial recording',
    () async {
      final capture = FakeAudioCapture();
      final store = InMemoryRecordingStore();
      final sink = _FailingRecordingSink(failAppend: true);
      final coordinator = PracticeSessionCoordinator(
        audioCapture: capture,
        analysisEngine: FakeAnalysisEngine(),
        recordingSink: sink,
        recordingStore: store,
        sessionRepository: InMemorySessionRepository(recordingStore: store),
      );
      addTearDown(coordinator.dispose);

      await coordinator.start(_request());
      capture.emit(_chunk());
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.state, isA<Failed>());
      expect(sink.aborted, isTrue);
    },
  );

  test(
    'finalize failure aborts the partial recording without a session',
    () async {
      final capture = FakeAudioCapture();
      final store = InMemoryRecordingStore();
      final sink = _FailingRecordingSink(failFinalize: true);
      final repository = InMemorySessionRepository(recordingStore: store);
      final coordinator = PracticeSessionCoordinator(
        audioCapture: capture,
        analysisEngine: FakeAnalysisEngine(),
        recordingSink: sink,
        recordingStore: store,
        sessionRepository: repository,
      );
      addTearDown(coordinator.dispose);

      await coordinator.start(_request());
      capture.emit(_chunk());
      await Future<void>.delayed(Duration.zero);

      expect(await coordinator.stop(), isA<Failed>());
      expect(sink.aborted, isTrue);
      expect(await repository.findById('persistence-failure'), isNull);
    },
  );
}

const _locatorValue = 'memory://persistence-failure';

final _locator = const RecordingLocator(
  value: _locatorValue,
  storageKind: RecordingStorageKind.none,
);

PracticeSessionRequest _request() => PracticeSessionRequest(
  sessionId: 'persistence-failure',
  template: const PracticeTemplate(
    id: 'target-note',
    version: 1,
    kind: PracticeKind.targetNote,
    target: PracticeTarget(targetMidiNote: 57),
    reviewStatus: ContentReviewStatus.reviewed,
  ),
  startedAt: DateTime.utc(2026, 8, 6),
);

PcmChunk _chunk() => PcmChunk(
  sequenceNumber: 0,
  firstSampleIndex: 0,
  format: const CaptureFormat(sampleRate: 48000, channels: 1),
  bytes: Uint8List(8),
  captureMonotonicTime: Duration.zero,
);

final class _FailingRecordingSink implements RecordingSink {
  _FailingRecordingSink({this.failAppend = false, this.failFinalize = false});

  final bool failAppend;
  final bool failFinalize;
  bool aborted = false;

  @override
  Future<void> open(RecordingMetadata metadata) async {}

  @override
  Future<void> append(PcmChunk chunk) {
    if (failAppend) return Future<void>.error(StateError('Injected append'));
    return Future<void>.value();
  }

  @override
  Future<RecordingLocator> finalize() {
    if (failFinalize) {
      return Future<RecordingLocator>.error(StateError('Injected finalize'));
    }
    return Future<RecordingLocator>.value(_locator);
  }

  @override
  Future<void> abort() async {
    aborted = true;
  }
}

final class _FailingSessionRepository implements SessionRepository {
  @override
  Future<void> save(PracticeSessionRecord record) =>
      Future<void>.error(StateError('Injected database failure.'));

  @override
  Future<PracticeSessionRecord?> findById(String id) async => null;

  @override
  Future<List<PracticeSessionRecord>> listRecent({int limit = 20}) async =>
      const <PracticeSessionRecord>[];

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> deleteRecording(String id) async {}
}
