import '../../core/domain/analysis/analysis_config.dart';
import '../../core/domain/analysis/analysis_engine.dart';
import '../../core/domain/analysis/analysis_frame.dart';
import '../../core/domain/analysis/feature_series.dart';
import '../../core/domain/analysis/session_summary.dart';
import '../../core/domain/audio/pcm_chunk.dart';
import '../../core/errors/failure.dart';

/// Deterministic analysis engine that emits one valid frame per PCM batch.
final class FakeAnalysisEngine implements AnalysisEngine {
  FakeAnalysisEngine({
    this.beforePush,
    this.failPushes = 0,
    this.initializeFailure,
  });

  Future<void> Function()? beforePush;
  int failPushes;
  AnalysisFailure? initializeFailure;
  AnalysisConfig? config;
  final List<PcmBatch> receivedBatches = <PcmBatch>[];
  final List<AnalysisFrame> _frames = <AnalysisFrame>[];
  int initializeCallCount = 0;
  int resetCallCount = 0;
  bool _disposed = false;

  @override
  AnalysisWorkerMetrics get workerMetrics => const AnalysisWorkerMetrics(
    droppedSamples: 0,
    restartCount: 0,
    usingFallback: false,
    state: AnalysisWorkerState.primary,
  );

  @override
  Stream<AnalysisWorkerMetrics> get workerMetricsStream =>
      const Stream<AnalysisWorkerMetrics>.empty();

  @override
  Future<void> initialize(AnalysisConfig config) async {
    initializeCallCount += 1;
    final failure = initializeFailure;
    if (failure != null) {
      throw failure;
    }
    this.config = config;
  }

  @override
  Future<AnalysisBatch> pushPcm(PcmBatch batch) async {
    final gate = beforePush;
    if (gate != null) {
      await gate();
    }
    if (failPushes > 0) {
      failPushes -= 1;
      throw StateError('Configured fake analysis failure.');
    }
    receivedBatches.add(batch);
    final frame = AnalysisFrame(
      sampleIndex: batch.firstSampleIndex,
      rmsDbfs: -12,
      peakDbfs: -3,
      pitchClarity: 0.9,
      voiced: true,
      algorithmVersion: 'fake-v1',
      f0Hz: 220,
      pitchCents: 5700,
    );
    _frames.add(frame);
    return AnalysisBatch(<AnalysisFrame>[frame]);
  }

  @override
  Future<AnalysisFinalization> finish() async => AnalysisFinalization(
    featureSeries: FeatureSeries(frameRateHz: 100, frames: _frames),
    finalFrames: const <AnalysisFrame>[],
    segmentSummary: SessionSummary(
      validFrameCount: _frames.length,
      totalFrameCount: _frames.length,
      qualityFlags: const {},
    ),
  );

  @override
  Future<void> reset() async {
    resetCallCount += 1;
    _frames.clear();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }

  bool get isDisposed => _disposed;
}
