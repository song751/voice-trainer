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
  const DeterministicObservationEngine({
    this.minimumValidFrames = 30,
    this.pitchVariationThresholdCents = 15,
    this.pitchDriftThresholdCentsPerSecond = 8,
    this.levelVariationThresholdDb = 2,
    this.levelDriftThresholdDbPerSecond = 1,
    this.onsetDelayThresholdSamples = 24000,
  }) : assert(minimumValidFrames > 0),
       assert(pitchVariationThresholdCents > 0),
       assert(pitchDriftThresholdCentsPerSecond > 0),
       assert(levelVariationThresholdDb > 0),
       assert(levelDriftThresholdDbPerSecond > 0),
       assert(onsetDelayThresholdSamples >= 0);

  final int minimumValidFrames;
  final double pitchVariationThresholdCents;
  final double pitchDriftThresholdCentsPerSecond;
  final double levelVariationThresholdDb;
  final double levelDriftThresholdDbPerSecond;
  final int onsetDelayThresholdSamples;

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
            recommendationIds: const <String>['REC-QUALITY-01'],
            suppressedReasonKey: 'quality_or_valid_frames_insufficient',
          ),
        ],
        recommendations: <Recommendation>[
          Recommendation(
            exerciseId: 'REC-QUALITY-01',
            contentVersion: 1,
            reviewStatus: ContentReviewStatus.draft,
            reasonKey: 'improve_recording_input',
            priority: 0,
            confidence: 1,
            scope: ObservationScope.session,
            evidenceGrade: RecommendationEvidenceGrade.guideline,
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
            qualityFlags: summary.qualityFlags,
            sourceIds: const <String>['ASHA_MEASURE_2018'],
            limitations: const <String>[
              'consumer_microphone_not_clinical_measurement',
            ],
          ),
        ],
      );
    }

    final hitRate = summary.targetHitRate!;
    final isConsistentlyOnTarget = hitRate >= 0.8;
    final confidence = _confidence(summary);
    final observations = <Observation>[
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
        confidence: confidence,
        qualityFlags: summary.qualityFlags,
        basis: EvidenceBasis.absoluteThreshold,
        recommendationIds: isConsistentlyOnTarget
            ? const <String>[]
            : const <String>['PITCH-MATCH-01'],
      ),
    ];

    final targetDeviation = summary.targetDeviationMedianCents;
    if (targetDeviation != null &&
        targetDeviation.abs() > template.target.toleranceCents) {
      observations.add(
        _measurementObservation(
          ruleId: 'target-pitch-direction',
          labelKey: targetDeviation > 0
              ? 'target_pitch_consistently_high'
              : 'target_pitch_consistently_low',
          metric: 'target_deviation_median_cents',
          value: targetDeviation,
          thresholdMetric: 'target_tolerance_cents',
          threshold: template.target.toleranceCents,
          confidence: confidence,
          recommendationIds: const <String>['PITCH-MATCH-01'],
        ),
      );
    }

    final pitchStability = summary.pitchStability;
    if (pitchStability != null) {
      if (pitchStability.medianAbsoluteDeviation >=
          pitchVariationThresholdCents) {
        observations.add(
          _measurementObservation(
            ruleId: 'pitch-variation',
            labelKey: 'pitch_variation_observed',
            metric: 'pitch_mad_cents',
            value: pitchStability.medianAbsoluteDeviation,
            thresholdMetric: 'pitch_variation_threshold_cents',
            threshold: pitchVariationThresholdCents,
            confidence: confidence,
          ),
        );
      }
      if (pitchStability.slopePerSecond.abs() >=
          pitchDriftThresholdCentsPerSecond) {
        observations.add(
          _measurementObservation(
            ruleId: 'pitch-drift',
            labelKey: pitchStability.slopePerSecond > 0
                ? 'pitch_drift_upward'
                : 'pitch_drift_downward',
            metric: 'pitch_slope_cents_per_second',
            value: pitchStability.slopePerSecond,
            thresholdMetric: 'pitch_drift_threshold_cents_per_second',
            threshold: pitchDriftThresholdCentsPerSecond,
            confidence: confidence,
          ),
        );
      }
    }

    final levelStability = summary.levelStability;
    if (levelStability != null) {
      if (levelStability.medianAbsoluteDeviation >= levelVariationThresholdDb) {
        observations.add(
          _measurementObservation(
            ruleId: 'level-variation',
            labelKey: 'level_variation_observed',
            metric: 'level_mad_db',
            value: levelStability.medianAbsoluteDeviation,
            thresholdMetric: 'level_variation_threshold_db',
            threshold: levelVariationThresholdDb,
            confidence: confidence,
          ),
        );
      }
      if (levelStability.slopePerSecond.abs() >=
          levelDriftThresholdDbPerSecond) {
        observations.add(
          _measurementObservation(
            ruleId: 'level-drift',
            labelKey: levelStability.slopePerSecond > 0
                ? 'level_drift_upward'
                : 'level_drift_downward',
            metric: 'level_slope_db_per_second',
            value: levelStability.slopePerSecond,
            thresholdMetric: 'level_drift_threshold_db_per_second',
            threshold: levelDriftThresholdDbPerSecond,
            confidence: confidence,
          ),
        );
      }
    }

    final onsetDelay = summary.onsetDelaySamples;
    if (onsetDelay != null && onsetDelay >= onsetDelayThresholdSamples) {
      observations.add(
        _measurementObservation(
          ruleId: 'stable-onset-delay',
          labelKey: 'stable_pitch_onset_delayed',
          metric: 'onset_delay_samples',
          value: onsetDelay.toDouble(),
          thresholdMetric: 'onset_delay_threshold_samples',
          threshold: onsetDelayThresholdSamples.toDouble(),
          confidence: confidence,
        ),
      );
    }

    return ObservationResult(
      observations: observations,
      recommendations: isConsistentlyOnTarget
          ? <Recommendation>[]
          : <Recommendation>[
              Recommendation(
                exerciseId: 'PITCH-MATCH-01',
                contentVersion: 1,
                reviewStatus: ContentReviewStatus.draft,
                reasonKey: 'repeat_target_note',
                priority: 0,
                confidence: confidence,
                scope: ObservationScope.session,
                evidenceGrade: RecommendationEvidenceGrade.controlledTrial,
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
                qualityFlags: summary.qualityFlags,
                sourceIds: const <String>['BERGLIN_2022'],
                limitations: const <String>[
                  'short_training_trial',
                  'individual_response_varies',
                ],
              ),
            ],
    );
  }

  double _confidence(SessionSummary summary) =>
      summary.validFrameRatio.clamp(0.0, 1.0).toDouble();

  Observation _measurementObservation({
    required String ruleId,
    required String labelKey,
    required String metric,
    required double value,
    required String thresholdMetric,
    required double threshold,
    required double confidence,
    List<String> recommendationIds = const <String>[],
  }) => Observation(
    ruleId: ruleId,
    ruleVersion: 1,
    scope: ObservationScope.session,
    labelKey: labelKey,
    evidence: <Evidence>[
      Evidence(
        metric: metric,
        value: value,
        basis: EvidenceBasis.absoluteThreshold,
      ),
      Evidence(
        metric: thresholdMetric,
        value: threshold,
        basis: EvidenceBasis.absoluteThreshold,
      ),
    ],
    confidence: confidence,
    qualityFlags: const {},
    basis: EvidenceBasis.absoluteThreshold,
    recommendationIds: recommendationIds,
  );
}
