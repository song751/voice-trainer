import 'analysis_config.dart';
import 'analysis_frame.dart';
import 'feature_series.dart';
import '../audio/pcm_chunk.dart';

final class AnalysisFinalization {
  AnalysisFinalization({
    required this.featureSeries,
    required List<AnalysisFrame> finalFrames,
  }) : finalFrames = List.unmodifiable(finalFrames);

  final FeatureSeries featureSeries;
  final List<AnalysisFrame> finalFrames;
}

abstract interface class AnalysisEngine {
  Future<void> initialize(AnalysisConfig config);

  Future<AnalysisBatch> pushPcm(PcmBatch batch);

  Future<AnalysisFinalization> finish();

  Future<void> reset();

  Future<void> dispose();
}
