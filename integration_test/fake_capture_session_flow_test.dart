import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_engine.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_quality_flag.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/capture_health.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/errors/failure.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/features/live_practice/application/practice_session_coordinator.dart';
import 'package:voice_trainer/features/live_practice/domain/practice_session_state.dart';
import 'package:voice_trainer/infrastructure/audio/fake_audio_capture.dart';
import 'package:voice_trainer/infrastructure/dsp/fake_analysis_engine.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_recording_store.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_session_repository.dart';

void main() {
  group('fake capture session flow', () {
    test(
      'completes start, pause, resume, and stop with monotonic sample indices',
      () async {
        final capture = FakeAudioCapture();
        final analysis = FakeAnalysisEngine();
        final repository = InMemorySessionRepository();
        final recordingStore = InMemoryRecordingStore();
        final recordingSink = InMemoryRecordingSink(recordingStore);
        final coordinator = _coordinator(
          capture: capture,
          analysis: analysis,
          recordingSink: recordingSink,
          repository: repository,
        );

        expect(
          await coordinator.start(_request('session-happy')),
          isA<Running>(),
        );
        capture.emit(_chunk(sequence: 0, firstSample: 0));
        await _drainMicrotasks();

        expect(await coordinator.pause(), isA<Paused>());
        capture.emit(_chunk(sequence: 1, firstSample: 4));
        expect(await coordinator.resume(), isA<Running>());
        capture.emit(_chunk(sequence: 2, firstSample: 8));

        expect(await coordinator.stop(), isA<Completed>());
        expect(
          analysis.receivedBatches.map((batch) => batch.firstSampleIndex),
          <int>[0, 8],
        );
        expect(analysis.config!.inputFormat, capture.effectiveFormat);
        expect(analysis.receivedBatches.last.discontinuityBefore, isTrue);
        expect(
          recordingSink.chunks.map((chunk) => chunk.firstSampleIndex),
          <int>[0, 8],
        );
        expect(repository.records, hasLength(1));
        expect(
          repository.records.single.features.frames.map(
            (frame) => frame.sampleIndex,
          ),
          <int>[0, 8],
        );
        expect(coordinator.analysisQueueAccounting.droppedSamples, 4);
        expect(coordinator.analysisQueueAccounting.hasDiscontinuity, isTrue);
        expect(
          repository.records.single.summary.qualityFlags,
          containsAll(<AnalysisQualityFlag>[
            AnalysisQualityFlag.discontinuity,
            AnalysisQualityFlag.droppedSamples,
          ]),
        );
      },
    );

    test(
      'slow analysis drops the oldest queued PCM and records discontinuity',
      () async {
        final analysisGate = Completer<void>();
        final capture = FakeAudioCapture();
        final analysis = FakeAnalysisEngine(
          beforePush: () => analysisGate.future,
        );
        final repository = InMemorySessionRepository();
        final coordinator = _coordinator(
          capture: capture,
          analysis: analysis,
          recordingSink: InMemoryRecordingSink(InMemoryRecordingStore()),
          repository: repository,
          maxQueuedSamples: 8,
        );

        await coordinator.start(_request('session-overflow'));
        capture.emit(_chunk(sequence: 0, firstSample: 0));
        await _drainMicrotasks();
        capture.emit(_chunk(sequence: 1, firstSample: 4));
        capture.emit(_chunk(sequence: 2, firstSample: 8));
        capture.emit(_chunk(sequence: 3, firstSample: 12));

        final stop = coordinator.stop();
        analysisGate.complete();
        expect(await stop, isA<Completed>());
        expect(coordinator.analysisQueueAccounting.droppedSamples, 4);
        expect(coordinator.analysisQueueAccounting.hasDiscontinuity, isTrue);
        expect(
          analysis.receivedBatches.map((batch) => batch.firstSampleIndex),
          <int>[0, 8, 12],
        );
        expect(
          repository.records.single.summary.qualityFlags.map(
            (flag) => flag.name,
          ),
          containsAll(<String>['droppedSamples', 'discontinuity']),
        );
      },
    );

    test(
      'format changes fail analysis explicitly instead of reinterpreting PCM',
      () async {
        final capture = FakeAudioCapture();
        final coordinator = _coordinator(
          capture: capture,
          analysis: FakeAnalysisEngine(),
          recordingSink: InMemoryRecordingSink(InMemoryRecordingStore()),
          repository: InMemorySessionRepository(),
        );

        expect(
          await coordinator.start(_request('session-format-change')),
          isA<Running>(),
        );
        capture.emit(
          PcmChunk(
            sequenceNumber: 0,
            firstSampleIndex: 0,
            format: const CaptureFormat(sampleRate: 44100, channels: 1),
            bytes: Uint8List(8),
            captureMonotonicTime: Duration.zero,
          ),
        );
        await _drainMicrotasks();

        final failed = coordinator.state;
        expect(failed, isA<Failed>());
        expect(
          (failed as Failed).failure,
          isA<AnalysisFailure>().having(
            (failure) => failure.reason,
            'reason',
            AnalysisFailureReason.formatChanged,
          ),
        );
      },
    );

    test(
      'analysis initialization failure remains typed and stops capture',
      () async {
        final capture = FakeAudioCapture();
        final coordinator = _coordinator(
          capture: capture,
          analysis: FakeAnalysisEngine(
            initializeFailure: const AnalysisFailure(
              AnalysisFailureReason.unsupportedFormat,
            ),
          ),
          recordingSink: InMemoryRecordingSink(InMemoryRecordingStore()),
          repository: InMemorySessionRepository(),
        );

        final state = await coordinator.start(
          _request('session-analysis-failure'),
        );
        expect(state, isA<Failed>());
        expect(
          (state as Failed).failure,
          isA<AnalysisFailure>().having(
            (failure) => failure.reason,
            'reason',
            AnalysisFailureReason.unsupportedFormat,
          ),
        );
      },
    );

    test(
      'Coordinator publishes frames, capture health, and worker metrics',
      () async {
        final capture = FakeAudioCapture();
        final coordinator = _coordinator(
          capture: capture,
          analysis: FakeAnalysisEngine(),
          recordingSink: InMemoryRecordingSink(InMemoryRecordingStore()),
          repository: InMemorySessionRepository(),
        );
        final frames = <int>[];
        final health = <CaptureHealth>[];
        final metrics = <AnalysisWorkerMetrics>[];
        final frameSubscription = coordinator.realtimeFrames.listen(
          (frame) => frames.add(frame.sampleIndex),
        );
        final healthSubscription = coordinator.captureHealth.listen(health.add);
        final metricsSubscription = coordinator.workerMetrics.listen(
          metrics.add,
        );

        await coordinator.start(_request('session-streams'));
        capture.emit(_chunk(sequence: 0, firstSample: 0));
        capture.emitHealth(
          CaptureHealth(
            effectiveFormat: capture.effectiveFormat,
            flags: const {CaptureHealthFlag.processingAdjusted},
          ),
        );
        await _drainMicrotasks();

        expect(frames, <int>[0]);
        expect(
          health.single.flags,
          contains(CaptureHealthFlag.processingAdjusted),
        );
        expect(metrics.single.state, AnalysisWorkerState.primary);
        await frameSubscription.cancel();
        await healthSubscription.cancel();
        await metricsSubscription.cancel();
        await coordinator.dispose();
      },
    );

    test('stop during an analysis failure remains recoverable', () async {
      final analysisGate = Completer<void>();
      final capture = FakeAudioCapture();
      final analysis = FakeAnalysisEngine(
        beforePush: () => analysisGate.future,
        failPushes: 1,
      );
      final repository = InMemorySessionRepository();
      final coordinator = _coordinator(
        capture: capture,
        analysis: analysis,
        recordingSink: InMemoryRecordingSink(InMemoryRecordingStore()),
        repository: repository,
      );

      await coordinator.start(_request('session-recovery'));
      capture.emit(_chunk(sequence: 0, firstSample: 0));
      await _drainMicrotasks();

      final stop = coordinator.stop();
      expect(coordinator.state, isA<Finalizing>());
      analysisGate.complete();
      final failed = await stop;
      expect(failed, isA<Failed>());
      expect(
        (failed as Failed).retryState,
        PracticeSessionStateKind.finalizing,
      );

      expect(await coordinator.retry(), isA<Completed>());
      expect(repository.records, hasLength(1));
    });
  });
}

PracticeSessionCoordinator _coordinator({
  required FakeAudioCapture capture,
  required FakeAnalysisEngine analysis,
  required InMemoryRecordingSink recordingSink,
  required InMemorySessionRepository repository,
  int maxQueuedSamples = 12000,
}) {
  return PracticeSessionCoordinator(
    audioCapture: capture,
    analysisEngine: analysis,
    recordingSink: recordingSink,
    recordingStore: InMemoryRecordingStore(),
    sessionRepository: repository,
    maxQueuedSamples: maxQueuedSamples,
  );
}

PracticeSessionRequest _request(String sessionId) => PracticeSessionRequest(
  sessionId: sessionId,
  template: const PracticeTemplate(
    id: 'target-note',
    version: 1,
    kind: PracticeKind.targetNote,
    target: PracticeTarget(targetMidiNote: 57),
    reviewStatus: ContentReviewStatus.approved,
  ),
  startedAt: DateTime.utc(2026, 8, 4),
);

PcmChunk _chunk({required int sequence, required int firstSample}) => PcmChunk(
  sequenceNumber: sequence,
  firstSampleIndex: firstSample,
  format: const CaptureFormat(sampleRate: 48000, channels: 1),
  bytes: Uint8List(8),
  captureMonotonicTime: Duration(microseconds: firstSample),
);

Future<void> _drainMicrotasks() => Future<void>.delayed(Duration.zero);
