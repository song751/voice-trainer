import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_config.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_engine.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/analysis/feature_series.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/infrastructure/dsp/analysis_worker_supervisor.dart';
import 'package:voice_trainer/infrastructure/dsp/rust_analysis_engine.dart';

void main() {
  const config = AnalysisConfig(inputFormatSampleRate: 48000);

  group('AnalysisWorkerSupervisor', () {
    test('restarts a crashed primary worker and retries its batch', () async {
      var factoryCalls = 0;
      final supervisor = AnalysisWorkerSupervisor(
        primaryWorkerFactory: () async {
          factoryCalls += 1;
          return _TestWorker(failFirstPush: factoryCalls == 1);
        },
      );

      await supervisor.initialize(config);
      final result = await supervisor.pushPcm(_batch(0));

      expect(result.frames.single.sampleIndex, 0);
      expect(factoryCalls, 2);
      expect(supervisor.metrics.restartCount, 1);
      expect(supervisor.metrics.usingFallback, isFalse);
      await supervisor.dispose();
    });

    test('falls back when the primary worker cannot start', () async {
      final fallback = _TestWorker();
      final supervisor = AnalysisWorkerSupervisor(
        primaryWorkerFactory: () async =>
            throw StateError('worker start failed'),
        fallbackWorkerFactory: () async => fallback,
      );

      await supervisor.initialize(config);
      final result = await supervisor.pushPcm(_batch(0));

      expect(result.frames, hasLength(1));
      expect(supervisor.metrics.usingFallback, isTrue);
      expect(fallback.initialized, isTrue);
      await supervisor.dispose();
    });

    test(
      'drops the oldest queued worker batch and accounts for samples',
      () async {
        final gate = Completer<void>();
        final worker = _TestWorker(beforePush: () => gate.future);
        final supervisor = AnalysisWorkerSupervisor(
          primaryWorkerFactory: () async => worker,
          maxQueuedSamples: 1024,
        );
        await supervisor.initialize(config);

        final first = supervisor.pushPcm(_batch(0));
        await Future<void>.delayed(Duration.zero);
        final dropped = supervisor.pushPcm(_batch(1024));
        final last = supervisor.pushPcm(_batch(2048));

        gate.complete();
        expect((await first).frames, hasLength(1));
        expect((await dropped).frames, isEmpty);
        expect((await last).frames.single.sampleIndex, 2048);
        expect(supervisor.metrics.droppedSamples, 1024);
        expect(worker.receivedSampleIndices, <int>[0, 2048]);
        await supervisor.dispose();
      },
    );

    test(
      'keeps the main isolate heartbeat alive during a ten-minute flow',
      () async {
        final worker = _TestWorker(
          beforePush: () =>
              Future<void>.delayed(const Duration(milliseconds: 1)),
        );
        final supervisor = AnalysisWorkerSupervisor(
          primaryWorkerFactory: () async => worker,
        );
        await supervisor.initialize(
          const AnalysisConfig(inputFormatSampleRate: 1),
        );
        var heartbeatTicks = 0;
        final heartbeat = Timer.periodic(
          const Duration(milliseconds: 1),
          (_) => heartbeatTicks += 1,
        );
        try {
          // 600 one-sample batches at 1 Hz model ten minutes without turning a
          // unit test into a ten-minute wall-clock soak.
          for (var second = 0; second < 600; second += 1) {
            await supervisor.pushPcm(_batch(second, sampleRate: 1, samples: 1));
          }
        } finally {
          heartbeat.cancel();
        }

        expect(heartbeatTicks, greaterThan(10));
        expect(worker.receivedSampleIndices, hasLength(600));
        await supervisor.dispose();
      },
    );
  });

  test(
    'RustAnalysisEngine splits a capture chunk into 1024-sample messages',
    () async {
      final worker = _TestWorker();
      final engine = RustAnalysisEngine(
        primaryWorkerFactory: () async => worker,
        fallbackWorkerFactory: () async => _TestWorker(),
      );
      await engine.initialize(config);

      await engine.pushPcm(_batch(0, samples: 2400));

      expect(worker.receivedSampleCounts, <int>[1024, 1024, 352]);
      await engine.dispose();
    },
  );
}

PcmBatch _batch(
  int firstSample, {
  int sampleRate = 48000,
  int samples = 1024,
}) => PcmBatch(
  firstSampleIndex: firstSample,
  format: CaptureFormat(sampleRate: sampleRate, channels: 1),
  bytes: Uint8List(samples * 2),
);

final class _TestWorker implements AnalysisWorker {
  _TestWorker({this.failFirstPush = false, this.beforePush});

  final bool failFirstPush;
  final Future<void> Function()? beforePush;
  final List<int> receivedSampleIndices = <int>[];
  final List<int> receivedSampleCounts = <int>[];
  bool initialized = false;
  bool _failed = false;

  @override
  Future<void> initialize(AnalysisConfig config) async {
    initialized = true;
  }

  @override
  Future<AnalysisBatch> pushPcm(PcmBatch batch) async {
    final gate = beforePush;
    if (gate != null) {
      await gate();
    }
    if (failFirstPush && !_failed) {
      _failed = true;
      throw StateError('simulated worker crash');
    }
    receivedSampleIndices.add(batch.firstSampleIndex);
    receivedSampleCounts.add(batch.frameCount);
    return AnalysisBatch(<AnalysisFrame>[
      AnalysisFrame(
        sampleIndex: batch.firstSampleIndex,
        rmsDbfs: -12,
        peakDbfs: -3,
        pitchClarity: 0.9,
        voiced: true,
        algorithmVersion: 'test-v1',
        f0Hz: 220,
      ),
    ]);
  }

  @override
  Future<AnalysisFinalization> finish() async => AnalysisFinalization(
    featureSeries: FeatureSeries(frameRateHz: 100, frames: const []),
    finalFrames: const <AnalysisFrame>[],
  );

  @override
  Future<void> reset() async {}

  @override
  Future<void> dispose() async {}
}
