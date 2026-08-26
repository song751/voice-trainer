import '../../core/domain/analysis/analysis_quality_flag.dart';
import '../../core/domain/analysis/session_summary.dart';
import '../../src/rust/api/realtime.dart';

/// Converts the bounded Rust finalization DTO into the domain summary.
SessionSummary mapSegmentSummaryDto(SegmentSummaryDto summary) =>
    SessionSummary(
      validFrameCount: summary.validFrameCount,
      totalFrameCount: summary.frameCount,
      droppedSamples: summary.droppedSamples.toInt(),
      pitchStability: _mapStability(summary.pitchStability),
      levelStability: _mapStability(summary.levelStability),
      onsetDelaySamples: summary.onsetDelaySamples?.toInt(),
      qualityFlags: _qualityFlags(summary.qualityFlags),
    );

SessionSummary mapWebSegmentSummary(Map<String, dynamic> summary) =>
    SessionSummary(
      validFrameCount: (summary['validFrameCount'] as num).toInt(),
      totalFrameCount: (summary['frameCount'] as num).toInt(),
      droppedSamples: (summary['droppedSamples'] as num).toInt(),
      pitchStability: _mapWebStability(summary['pitchStability']),
      levelStability: _mapWebStability(summary['levelStability']),
      onsetDelaySamples: (summary['onsetDelaySamples'] as num?)?.toInt(),
      qualityFlags: _qualityFlags((summary['qualityFlags'] as num).toInt()),
    );

StabilitySummary? _mapStability(RobustStabilityDto? stability) =>
    stability == null
    ? null
    : StabilitySummary(
        median: stability.median,
        medianAbsoluteDeviation: stability.medianAbsoluteDeviation,
        slopePerSecond: stability.slopePerSecond,
        frameCount: stability.frameCount,
      );

StabilitySummary? _mapWebStability(Object? raw) {
  if (raw == null) return null;
  final stability = raw as Map<String, dynamic>;
  return StabilitySummary(
    median: (stability['median'] as num).toDouble(),
    medianAbsoluteDeviation: (stability['medianAbsoluteDeviation'] as num)
        .toDouble(),
    slopePerSecond: (stability['slopePerSecond'] as num).toDouble(),
    frameCount: (stability['frameCount'] as num).toInt(),
  );
}

Set<AnalysisQualityFlag> _qualityFlags(int mask) {
  if (mask & ~0x1f != 0) {
    throw ArgumentError.value(
      mask,
      'qualityFlags',
      'Bridge summary contains unknown quality flag bits.',
    );
  }
  return <AnalysisQualityFlag>{
    if (mask & 0x01 != 0) AnalysisQualityFlag.clipping,
    if (mask & 0x02 != 0) AnalysisQualityFlag.inputTooLow,
    if (mask & 0x04 != 0) AnalysisQualityFlag.droppedSamples,
    if (mask & 0x08 != 0) AnalysisQualityFlag.discontinuity,
    if (mask & 0x10 != 0) AnalysisQualityFlag.insufficientValidFrames,
  };
}
