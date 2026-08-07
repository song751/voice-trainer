import 'analysis_config.dart';
import 'analysis_frame.dart';
import 'feature_series.dart';
import 'session_summary.dart';
import '../audio/pcm_chunk.dart';

enum AnalysisWorkerState {
  uninitialized,
  primary,
  restartOnce,
  fallback,
  terminalFailure,
  disposed,
}

final class AnalysisWorkerMetrics {
  const AnalysisWorkerMetrics({
    required this.droppedSamples,
    required this.restartCount,
    required this.usingFallback,
    required this.state,
  });

  final int droppedSamples;
  final int restartCount;
  final bool usingFallback;
  final AnalysisWorkerState state;
}

final class AnalysisFinalization {
  AnalysisFinalization({
    required this.featureSeries,
    required List<AnalysisFrame> finalFrames,
    required this.segmentSummary,
  }) : finalFrames = List.unmodifiable(finalFrames);

  final FeatureSeries featureSeries;
  final List<AnalysisFrame> finalFrames;
  final SessionSummary segmentSummary;
}

abstract interface class AnalysisEngine {
  AnalysisWorkerMetrics get workerMetrics;

  Stream<AnalysisWorkerMetrics> get workerMetricsStream;

  Future<void> initialize(AnalysisConfig config);

  Future<AnalysisBatch> pushPcm(PcmBatch batch);

  Future<AnalysisFinalization> finish();

  Future<void> reset();

  Future<void> dispose();
}
