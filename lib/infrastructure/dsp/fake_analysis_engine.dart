import '../../core/domain/analysis/analysis_config.dart';
import '../../core/domain/analysis/analysis_engine.dart';
import '../../core/domain/analysis/analysis_frame.dart';
import '../../core/domain/analysis/feature_series.dart';
import '../../core/domain/audio/pcm_chunk.dart';

/// Deterministic analysis engine that emits one valid frame per PCM batch.
final class FakeAnalysisEngine implements AnalysisEngine {
  FakeAnalysisEngine({this.beforePush, this.failPushes = 0});

  Future<void> Function()? beforePush;
  int failPushes;
  AnalysisConfig? config;
  final List<PcmBatch> receivedBatches = <PcmBatch>[];
  final List<AnalysisFrame> _frames = <AnalysisFrame>[];
  bool _disposed = false;

  @override
  Future<void> initialize(AnalysisConfig config) async {
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
    );
    _frames.add(frame);
    return AnalysisBatch(<AnalysisFrame>[frame]);
  }

  @override
  Future<AnalysisFinalization> finish() async => AnalysisFinalization(
    featureSeries: FeatureSeries(frameRateHz: 100, frames: _frames),
    finalFrames: const <AnalysisFrame>[],
  );

  @override
  Future<void> reset() async {
    _frames.clear();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }

  bool get isDisposed => _disposed;
}
