import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_quality_flag.dart';
import 'package:voice_trainer/core/domain/analysis/voice_comparison.dart';
import 'package:voice_trainer/core/domain/analysis/voice_production_profile.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/domain/persistence/recording_locator.dart';
import 'package:voice_trainer/core/domain/persistence/recording_sink.dart';
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
    'three recordings reuse capture, sink and worker without stale state',
    () async {
      final capture = FakeAudioCapture();
      final analysis = FakeAnalysisEngine();
      final store = InMemoryRecordingStore();
      final sink = InMemoryRecordingSink(store);
      final repository = InMemorySessionRepository(recordingStore: store);
      final coordinator = PracticeSessionCoordinator(
        audioCapture: capture,
        analysisEngine: analysis,
        recordingSink: sink,
        recordingStore: store,
        sessionRepository: repository,
      );
      addTearDown(coordinator.dispose);

      for (var index = 0; index < 3; index += 1) {
        final id = 'repeat-$index';
        expect(await coordinator.start(_request(id, index)), isA<Running>());
        capture.emit(_chunk(value: index + 1));
        await _drainMicrotasks();
        expect(await coordinator.stop(), isA<Completed>());

        final record = await repository.findById(id);
        expect(record, isNotNull);
        expect(record!.summary.validFrameCount, 1);
        expect(
          record.summary.qualityFlags,
          isNot(contains(AnalysisQualityFlag.discontinuity)),
        );
        expect(record.features.frames, hasLength(1));
        expect(sink.chunks, hasLength(1));
        expect(coordinator.analysisQueueAccounting.droppedSamples, 0);
      }

      expect(capture.startCallCount, 3);
      expect(analysis.initializeCallCount, 1);
      expect(analysis.resetCallCount, 2);
      expect(repository.records, hasLength(3));
    },
  );

  test(
    'a failed worker aborts its partial sink and the next start recovers',
    () async {
      final capture = FakeAudioCapture();
      final analysis = FakeAnalysisEngine(failPushes: 1);
      final store = InMemoryRecordingStore();
      final sink = InMemoryRecordingSink(store);
      final repository = InMemorySessionRepository(recordingStore: store);
      final coordinator = PracticeSessionCoordinator(
        audioCapture: capture,
        analysisEngine: analysis,
        recordingSink: sink,
        recordingStore: store,
        sessionRepository: repository,
      );
      addTearDown(coordinator.dispose);

      expect(await coordinator.start(_request('failed', 0)), isA<Running>());
      capture.emit(_chunk());
      await _drainMicrotasks();
      expect(coordinator.state, isA<Failed>());

      expect(await coordinator.start(_request('recovered', 1)), isA<Running>());
      expect(sink.chunks, isEmpty);
      capture.emit(_chunk(value: 2));
      await _drainMicrotasks();
      expect(await coordinator.stop(), isA<Completed>());
      expect(await repository.findById('failed'), isNull);
      expect(
        (await repository.findById('recovered'))!.summary.validFrameCount,
        1,
      );
      expect(analysis.initializeCallCount, 1);
      expect(analysis.resetCallCount, 1);
    },
  );

  test(
    'finalize failure is aborted before the same sink is opened again',
    () async {
      final capture = FakeAudioCapture();
      final analysis = FakeAnalysisEngine();
      final store = InMemoryRecordingStore();
      final delegate = InMemoryRecordingSink(store);
      final sink = _FailOnceFinalizeSink(delegate);
      final repository = InMemorySessionRepository(recordingStore: store);
      final coordinator = PracticeSessionCoordinator(
        audioCapture: capture,
        analysisEngine: analysis,
        recordingSink: sink,
        recordingStore: store,
        sessionRepository: repository,
      );
      addTearDown(coordinator.dispose);

      expect(
        await coordinator.start(_request('finalize-failed', 0)),
        isA<Running>(),
      );
      capture.emit(_chunk());
      await _drainMicrotasks();
      expect(await coordinator.stop(), isA<Failed>());
      expect(sink.abortCallCount, 1);

      expect(
        await coordinator.start(_request('finalize-recovered', 1)),
        isA<Running>(),
      );
      capture.emit(_chunk(value: 2));
      await _drainMicrotasks();
      expect(await coordinator.stop(), isA<Completed>());
      expect(await repository.findById('finalize-failed'), isNull);
      expect(await repository.findById('finalize-recovered'), isNotNull);
    },
  );

  test(
    'analysis failure while stopping retains the recording for retry',
    () async {
      final analysisGate = Completer<void>();
      final capture = FakeAudioCapture();
      final analysis = FakeAnalysisEngine(
        beforePush: () => analysisGate.future,
        failPushes: 1,
      );
      final store = InMemoryRecordingStore();
      final sink = InMemoryRecordingSink(store);
      final repository = InMemorySessionRepository(recordingStore: store);
      final coordinator = PracticeSessionCoordinator(
        audioCapture: capture,
        analysisEngine: analysis,
        recordingSink: sink,
        recordingStore: store,
        sessionRepository: repository,
      );
      addTearDown(coordinator.dispose);

      expect(
        await coordinator.start(_request('retry-finalize', 0)),
        isA<Running>(),
      );
      capture.emit(_chunk());
      await _drainMicrotasks();

      final stopping = coordinator.stop();
      expect(coordinator.state, isA<Finalizing>());
      analysisGate.complete();
      final failed = await stopping;
      expect(failed, isA<Failed>());
      expect(
        (failed as Failed).retryState,
        PracticeSessionStateKind.finalizing,
      );

      expect(await coordinator.retry(), isA<Completed>());
      expect(await repository.findById('retry-finalize'), isNotNull);
      expect(sink.chunks, hasLength(1));
    },
  );

  test(
    'completed recording preserves its immutable A/B take context',
    () async {
      final capture = FakeAudioCapture();
      final analysis = FakeAnalysisEngine();
      final store = InMemoryRecordingStore();
      final sink = InMemoryRecordingSink(store);
      final repository = InMemorySessionRepository(recordingStore: store);
      final coordinator = PracticeSessionCoordinator(
        audioCapture: capture,
        analysisEngine: analysis,
        recordingSink: sink,
        recordingStore: store,
        sessionRepository: repository,
      );
      addTearDown(coordinator.dispose);

      final context = VoiceComparisonTakeContext(
        plan: VoiceComparisonPlan(
          id: 'comparison-1',
          labelA: _label(VoiceIntentKey.chestVoice),
          labelB: _label(VoiceIntentKey.weakMix),
          scope: VoiceProductionScope(
            protocolId: 'VP-MIX-01',
            taskKind: VoiceProductionTaskKind.matchedPitchContrast,
            pitchContextKey: 'C4',
            vowelIpa: 'a',
            loudnessConditionKey: 'comfortable',
            styleContextKey: 'sustained',
            captureProfileKey: 'same-device-distance',
            algorithmVersion: 'analysis-v1',
          ),
          updatedAt: DateTime.utc(2026, 8, 27),
        ),
        side: VoiceComparisonSide.b,
      );
      final request = PracticeSessionRequest(
        sessionId: 'comparison-take-b',
        template: _request('unused', 0).template,
        startedAt: DateTime.utc(2026, 8, 27),
        voiceComparison: context,
      );

      expect(await coordinator.start(request), isA<Running>());
      capture.emit(_chunk());
      await _drainMicrotasks();
      expect(await coordinator.stop(), isA<Completed>());

      final saved = await repository.findById('comparison-take-b');
      expect(saved?.voiceComparison?.plan.id, 'comparison-1');
      expect(saved?.voiceComparison?.side, VoiceComparisonSide.b);
      expect(saved?.voiceComparison?.label.labelKey, 'weakMix');
      expect(saved?.voiceComparison?.plan.scope.pitchContextKey, 'C4');
    },
  );

  test('aborting an in-memory sink discards PCM before reuse', () async {
    final store = InMemoryRecordingStore();
    final sink = InMemoryRecordingSink(store);
    await sink.open(
      RecordingMetadata(sessionId: 'cancelled', startedAt: DateTime.utc(2026)),
    );
    await sink.append(_chunk(value: 1));
    await sink.abort();
    expect(sink.chunks, isEmpty);

    await sink.open(
      RecordingMetadata(sessionId: 'kept', startedAt: DateTime.utc(2026, 1, 2)),
    );
    await sink.append(_chunk(value: 2));
    final locator = await sink.finalize();
    expect(locator.value, 'memory://kept');
    expect(sink.chunks.single.bytes.first, 2);
  });
}

PracticeSessionRequest _request(String sessionId, int dayOffset) =>
    PracticeSessionRequest(
      sessionId: sessionId,
      template: const PracticeTemplate(
        id: 'repeat-target-note',
        version: 1,
        kind: PracticeKind.targetNote,
        target: PracticeTarget(targetMidiNote: 57),
        reviewStatus: ContentReviewStatus.approved,
      ),
      startedAt: DateTime.utc(2026, 8, 26 + dayOffset),
    );

PcmChunk _chunk({int value = 1}) => PcmChunk(
  sequenceNumber: 0,
  firstSampleIndex: 0,
  format: const CaptureFormat(sampleRate: 48000, channels: 1),
  bytes: Uint8List(8)..[0] = value,
  captureMonotonicTime: Duration.zero,
);

Future<void> _drainMicrotasks() async {
  for (var index = 0; index < 4; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

PedagogicalVoiceLabel _label(VoiceIntentKey intent) => PedagogicalVoiceLabel(
  labelKey: intent.name,
  vocabularyId: 'voice-intent',
  vocabularyVersion: '1',
  source: PedagogicalLabelSource.singerIntent,
);

final class _FailOnceFinalizeSink implements RecordingSink {
  _FailOnceFinalizeSink(this._delegate);

  final InMemoryRecordingSink _delegate;
  int _remainingFailures = 1;
  int abortCallCount = 0;

  @override
  Future<void> open(RecordingMetadata metadata) => _delegate.open(metadata);

  @override
  Future<void> append(PcmChunk chunk) => _delegate.append(chunk);

  @override
  Future<RecordingLocator> finalize() {
    if (_remainingFailures > 0) {
      _remainingFailures -= 1;
      return Future<RecordingLocator>.error(StateError('Injected finalize'));
    }
    return _delegate.finalize();
  }

  @override
  Future<void> abort() async {
    abortCallCount += 1;
    await _delegate.abort();
  }
}
