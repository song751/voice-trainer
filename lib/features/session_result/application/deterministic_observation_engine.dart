import '../../../core/domain/analysis/session_summary.dart';
import '../../../core/domain/observation/evidence.dart';
import '../../../core/domain/observation/observation.dart';
import '../../../core/domain/observation/observation_engine.dart';
import '../../../core/domain/observation/recommendation.dart';
import '../../../core/domain/practice/practice_template.dart';

/// Versioned, input-only rules for descriptive session feedback.
///
/// The engine deliberately contains no medical or vocal-mechanism labels. A
/// quality-limited session yields only recording guidance, never a claim about
/// the user's voice or technique.
final class DeterministicObservationEngine implements ObservationEngine {
  const DeterministicObservationEngine({this.minimumValidFrames = 30});

  final int minimumValidFrames;

  @override
  ObservationResult evaluate({
    required PracticeTemplate template,
    required SessionSummary summary,
  }) {
    final qualityLimited =
        summary.validFrameCount < minimumValidFrames ||
        summary.qualityFlags.isNotEmpty ||
        summary.targetHitRate == null;
    if (qualityLimited) {
      return ObservationResult(
        observations: <Observation>[
          Observation(
            ruleId: 'recording-quality-limited',
            ruleVersion: 1,
            scope: ObservationScope.session,
            labelKey: 'recording_quality_limited',
            evidence: <Evidence>[
              Evidence(
                metric: 'valid_frame_count',
                value: summary.validFrameCount.toDouble(),
                basis: EvidenceBasis.absoluteThreshold,
              ),
              Evidence(
                metric: 'valid_frame_ratio',
                value: summary.validFrameRatio,
                basis: EvidenceBasis.absoluteThreshold,
              ),
            ],
            confidence: 1,
            qualityFlags: summary.qualityFlags,
            basis: EvidenceBasis.absoluteThreshold,
            recommendationIds: const <String>['improve-recording-input'],
            suppressedReasonKey: 'quality_or_valid_frames_insufficient',
          ),
        ],
        recommendations: const <Recommendation>[
          Recommendation(
            exerciseId: 'improve-recording-input',
            reasonKey: 'improve_recording_input',
            priority: 0,
          ),
        ],
      );
    }

    final hitRate = summary.targetHitRate!;
    final isConsistentlyOnTarget = hitRate >= 0.8;
    return ObservationResult(
      observations: <Observation>[
        Observation(
          ruleId: 'target-hit-rate',
          ruleVersion: 1,
          scope: ObservationScope.session,
          labelKey: isConsistentlyOnTarget
              ? 'target_alignment_consistent'
              : 'target_alignment_practice_needed',
          evidence: <Evidence>[
            Evidence(
              metric: 'target_hit_rate',
              value: hitRate,
              basis: EvidenceBasis.absoluteThreshold,
            ),
            Evidence(
              metric: 'target_tolerance_cents',
              value: template.target.toleranceCents,
              basis: EvidenceBasis.absoluteThreshold,
            ),
          ],
          confidence: _confidence(summary),
          qualityFlags: summary.qualityFlags,
          basis: EvidenceBasis.absoluteThreshold,
          recommendationIds: isConsistentlyOnTarget
              ? const <String>[]
              : const <String>['repeat-target-note'],
        ),
      ],
      recommendations: isConsistentlyOnTarget
          ? const <Recommendation>[]
          : const <Recommendation>[
              Recommendation(
                exerciseId: 'repeat-target-note',
                reasonKey: 'repeat_target_note',
                priority: 0,
              ),
            ],
    );
  }

  double _confidence(SessionSummary summary) =>
      summary.validFrameRatio.clamp(0.0, 1.0).toDouble();
}
