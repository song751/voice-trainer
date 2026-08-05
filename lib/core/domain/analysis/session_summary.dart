import 'analysis_quality_flag.dart';

final class SessionSummary {
  SessionSummary({
    required this.validFrameCount,
    required this.totalFrameCount,
    required Set<AnalysisQualityFlag> qualityFlags,
  }) : assert(validFrameCount >= 0),
       assert(totalFrameCount >= validFrameCount),
       qualityFlags = Set.unmodifiable(qualityFlags);

  final int validFrameCount;
  final int totalFrameCount;
  final Set<AnalysisQualityFlag> qualityFlags;

  double get validFrameRatio =>
      totalFrameCount == 0 ? 0 : validFrameCount / totalFrameCount;
}
