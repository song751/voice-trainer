import 'analysis_quality_flag.dart';

final class SessionSummary {
  SessionSummary({
    required this.validFrameCount,
    required this.totalFrameCount,
    required Set<AnalysisQualityFlag> qualityFlags,
    this.droppedSamples = 0,
    this.targetHitRate,
    this.targetDeviationMedianCents,
    this.pitchStability,
    this.levelStability,
    this.onsetDelaySamples,
  }) : assert(validFrameCount >= 0),
       assert(totalFrameCount >= validFrameCount),
       assert(droppedSamples >= 0),
       assert(
         targetHitRate == null || (targetHitRate >= 0 && targetHitRate <= 1),
       ),
       qualityFlags = Set.unmodifiable(qualityFlags);

  final int validFrameCount;
  final int totalFrameCount;
  final int droppedSamples;
  final double? targetHitRate;
  final double? targetDeviationMedianCents;
  final StabilitySummary? pitchStability;
  final StabilitySummary? levelStability;
  final int? onsetDelaySamples;
  final Set<AnalysisQualityFlag> qualityFlags;

  double get validFrameRatio =>
      totalFrameCount == 0 ? 0 : validFrameCount / totalFrameCount;
}

/// Robust statistics calculated by Rust for one continuous segment.
///
/// Pitch values use cents; level values use dBFS.  The summary intentionally
/// carries measurements only, leaving any user-facing interpretation to the
/// deterministic Dart rule engine.
final class StabilitySummary {
  const StabilitySummary({
    required this.median,
    required this.medianAbsoluteDeviation,
    required this.slopePerSecond,
    required this.frameCount,
  }) : assert(frameCount >= 0);

  final double median;
  final double medianAbsoluteDeviation;
  final double slopePerSecond;
  final int frameCount;
}
