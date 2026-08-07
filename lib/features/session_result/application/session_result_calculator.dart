import 'dart:math' as math;

import '../../../core/domain/analysis/analysis_frame.dart';
import '../../../core/domain/analysis/analysis_quality_flag.dart';
import '../../../core/domain/analysis/session_summary.dart';
import '../../../core/domain/practice/practice_target.dart';

/// Adds practice-specific measurements to the platform-neutral Rust summary.
/// Rust reports segment validity and stability; target hit rate belongs here
/// because it depends on the selected practice template.
SessionSummary withTargetHitRate({
  required SessionSummary segmentSummary,
  required List<AnalysisFrame> frames,
  required PracticeTarget target,
}) {
  final validFrames = frames.where(_isValidForTarget).toList(growable: false);
  final targetCents = target.targetMidiNote * 100.0;
  final hitCount = validFrames.where((frame) {
    final cents = frame.pitchCents ?? _centsFor(frame.f0Hz);
    return cents != null &&
        (cents - targetCents).abs() <= target.toleranceCents;
  }).length;
  return SessionSummary(
    validFrameCount: segmentSummary.validFrameCount,
    totalFrameCount: segmentSummary.totalFrameCount,
    droppedSamples: segmentSummary.droppedSamples,
    targetHitRate: validFrames.isEmpty ? null : hitCount / validFrames.length,
    pitchStability: segmentSummary.pitchStability,
    levelStability: segmentSummary.levelStability,
    onsetDelaySamples: segmentSummary.onsetDelaySamples,
    qualityFlags: segmentSummary.qualityFlags,
  );
}

bool _isValidForTarget(AnalysisFrame frame) =>
    frame.voiced &&
    frame.f0Hz != null &&
    !frame.qualityFlags.contains(AnalysisQualityFlag.clipping) &&
    !frame.qualityFlags.contains(AnalysisQualityFlag.inputTooLow) &&
    !frame.qualityFlags.contains(AnalysisQualityFlag.droppedSamples) &&
    !frame.qualityFlags.contains(AnalysisQualityFlag.discontinuity);

double? _centsFor(double? f0Hz) => f0Hz == null || f0Hz <= 0
    ? null
    : 6900 + 1200 * (math.log(f0Hz / 440) / math.ln2);
