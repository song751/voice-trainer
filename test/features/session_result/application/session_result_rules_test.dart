import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_quality_flag.dart';
import 'package:voice_trainer/core/domain/analysis/session_summary.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/features/session_result/application/deterministic_observation_engine.dart';
import 'package:voice_trainer/features/session_result/application/session_result_calculator.dart';

void main() {
  const template = PracticeTemplate(
    id: 'target-a3',
    version: 1,
    kind: PracticeKind.targetNote,
    target: PracticeTarget(targetMidiNote: 57, toleranceCents: 25),
    reviewStatus: ContentReviewStatus.reviewed,
  );

  AnalysisFrame frame({
    required int sample,
    required double f0Hz,
    Set<AnalysisQualityFlag> flags = const {},
  }) => AnalysisFrame(
    sampleIndex: sample,
    rmsDbfs: -18,
    peakDbfs: -3,
    pitchClarity: .9,
    voiced: true,
    f0Hz: f0Hz,
    algorithmVersion: 'test-v1',
    qualityFlags: flags,
  );

  test('target hit rate only counts valid voiced frames within tolerance', () {
    final summary = withTargetHitRate(
      segmentSummary: SessionSummary(
        validFrameCount: 4,
        totalFrameCount: 5,
        qualityFlags: const {},
      ),
      target: template.target,
      frames: <AnalysisFrame>[
        frame(sample: 0, f0Hz: 220),
        frame(sample: 240, f0Hz: 220),
        frame(sample: 480, f0Hz: 220 * 1.02),
        frame(sample: 960, f0Hz: 220, flags: {AnalysisQualityFlag.clipping}),
        frame(sample: 1440, f0Hz: 220 * 0.5),
      ],
    );

    expect(summary.targetHitRate, closeTo(.5, .0001));
  });

  test(
    'quality gate suppresses interpretation and only gives recording help',
    () {
      final result = const DeterministicObservationEngine().evaluate(
        template: template,
        summary: SessionSummary(
          validFrameCount: 8,
          totalFrameCount: 20,
          targetHitRate: .95,
          qualityFlags: const {AnalysisQualityFlag.inputTooLow},
        ),
      );

      expect(result.observations.single.labelKey, 'recording_quality_limited');
      expect(result.observations.single.suppressedReasonKey, isNotNull);
      expect(
        result.recommendations.single.exerciseId,
        'improve-recording-input',
      );
    },
  );

  test('observation rules are deterministic for equivalent summaries', () {
    final summary = SessionSummary(
      validFrameCount: 90,
      totalFrameCount: 100,
      targetHitRate: .65,
      qualityFlags: const {},
    );
    const engine = DeterministicObservationEngine();

    final first = engine.evaluate(template: template, summary: summary);
    final second = engine.evaluate(template: template, summary: summary);

    expect(
      first.observations.single.labelKey,
      second.observations.single.labelKey,
    );
    expect(
      first.recommendations.single.exerciseId,
      second.recommendations.single.exerciseId,
    );
  });
}
