import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_quality_flag.dart';
import 'package:voice_trainer/core/domain/analysis/feature_series.dart';
import 'package:voice_trainer/core/domain/analysis/session_summary.dart';
import 'package:voice_trainer/core/domain/analysis/voice_comparison.dart';
import 'package:voice_trainer/core/domain/analysis/voice_production_profile.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/features/voice_comparison/application/voice_comparison_evidence.dart';
import 'package:voice_trainer/features/voice_comparison/application/active_voice_comparison_take.dart';

void main() {
  test('reports five descriptive B minus A dimensions without classifying', () {
    final plan = _plan();
    final evidence = buildVoiceComparisonEvidence(
      plan: plan,
      records: <PracticeSessionRecord>[
        _record('a', plan, VoiceComparisonSide.a, pitch: 5700, level: -20),
        _record('b', plan, VoiceComparisonSide.b, pitch: 5712, level: -17),
      ],
    );

    expect(evidence.status, VoiceComparisonEvidenceStatus.ready);
    expect(evidence.deltas.map((value) => value.metricId), <String>[
      'pitch_median',
      'level_median',
      'periodicity_median',
      'onset_delay',
      'relative_2_4khz',
    ]);
    expect(evidence.deltas.first.valueBMinusA, 12);
    expect(
      evidence.deltas
          .singleWhere((value) => value.metricId == 'onset_delay')
          .unit,
      VoiceMeasurementUnit.samples,
    );
    expect(evidence.confidence.conservativeScore, .5);
    expect(evidence.rejectedTakeCount, 0);
  });

  test('a rejected take does not poison later usable A/B evidence', () {
    final plan = _plan();
    final evidence = buildVoiceComparisonEvidence(
      plan: plan,
      records: <PracticeSessionRecord>[
        _record('a', plan, VoiceComparisonSide.a, pitch: 5700, level: -20),
        _record(
          'bad-a',
          plan,
          VoiceComparisonSide.a,
          pitch: 6200,
          level: -4,
          flags: const <AnalysisQualityFlag>{AnalysisQualityFlag.clipping},
        ),
        _record('b', plan, VoiceComparisonSide.b, pitch: 5712, level: -17),
      ],
    );

    expect(evidence.status, VoiceComparisonEvidenceStatus.ready);
    expect(evidence.rejectedTakeCount, 1);
    expect(evidence.takeCountA, 1);
    expect(evidence.qualityFlags, contains(AnalysisQualityFlag.clipping));
    expect(evidence.deltas.first.valueBMinusA, 12);
  });

  test('quality gate suppresses when one side has no usable take', () {
    final plan = _plan();
    final evidence = buildVoiceComparisonEvidence(
      plan: plan,
      records: <PracticeSessionRecord>[
        _record('a', plan, VoiceComparisonSide.a, pitch: 5700, level: -20),
        _record(
          'bad-b',
          plan,
          VoiceComparisonSide.b,
          pitch: 5712,
          level: -17,
          validFrameCount: 20,
        ),
      ],
    );

    expect(evidence.status, VoiceComparisonEvidenceStatus.suppressed);
    expect(evidence.rejectedTakeCount, 1);
    expect(evidence.deltas, isEmpty);
    expect(evidence.suppressedReason, contains('质量门槛'));
  });

  test('same id cannot bypass exact task matching', () {
    final plan = _plan();
    final mismatched = _plan(vowelIpa: 'i', id: plan.id);
    final evidence = buildVoiceComparisonEvidence(
      plan: plan,
      records: <PracticeSessionRecord>[
        _record('a', plan, VoiceComparisonSide.a, pitch: 5700, level: -20),
        _record(
          'b',
          mismatched,
          VoiceComparisonSide.b,
          pitch: 5712,
          level: -17,
        ),
      ],
    );

    expect(evidence.status, VoiceComparisonEvidenceStatus.suppressed);
    expect(evidence.suppressedReason, contains('不一致'));
    expect(evidence.deltas, isEmpty);
  });

  test('same scope but changed vocabulary snapshot suppresses integrity', () {
    final plan = _plan();
    final mismatched = _plan(id: plan.id, vocabularyVersion: '3');
    final evidence = buildVoiceComparisonEvidence(
      plan: plan,
      records: <PracticeSessionRecord>[
        _record('a', plan, VoiceComparisonSide.a, pitch: 5700, level: -20),
        _record(
          'b',
          mismatched,
          VoiceComparisonSide.b,
          pitch: 5712,
          level: -17,
        ),
      ],
    );

    expect(evidence.status, VoiceComparisonEvidenceStatus.suppressed);
    expect(evidence.confidence.taskMatch, 0);
    expect(evidence.suppressedReason, contains('词表来源'));
  });

  test('repeatability is computed within each side before taking minimum', () {
    final plan = _plan();
    final evidence = buildVoiceComparisonEvidence(
      plan: plan,
      records: <PracticeSessionRecord>[
        _record('a1', plan, VoiceComparisonSide.a, pitch: 5700, level: -25),
        _record('a2', plan, VoiceComparisonSide.a, pitch: 5700, level: -25),
        _record('b1', plan, VoiceComparisonSide.b, pitch: 6200, level: -10),
        _record('b2', plan, VoiceComparisonSide.b, pitch: 6200, level: -10),
      ],
    );

    expect(evidence.status, VoiceComparisonEvidenceStatus.ready);
    expect(evidence.confidence.repeatability, .75);
  });

  test('saved pitch condition becomes the actual live-practice target', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final plan = _plan(pitchContextKey: 'C4');
    container.read(activeVoiceComparisonTakeProvider.notifier).state =
        VoiceComparisonTakeContext(plan: plan, side: VoiceComparisonSide.a);

    final template = container.read(practiceTemplateProvider);
    expect(template.target.targetMidiNote, 60);
    expect(template.reviewStatus, ContentReviewStatus.draft);
  });
}

VoiceComparisonPlan _plan({
  String id = 'comparison-1',
  String vowelIpa = 'a',
  String pitchContextKey = 'A3',
  String vocabularyVersion = '2',
}) => VoiceComparisonPlan(
  id: id,
  labelA: PedagogicalVoiceLabel(
    labelKey: VoiceIntentKey.weakMix.name,
    vocabularyId: 'teacher-li',
    vocabularyVersion: vocabularyVersion,
    source: PedagogicalLabelSource.teacherPrompt,
  ),
  labelB: PedagogicalVoiceLabel(
    labelKey: VoiceIntentKey.strongMix.name,
    vocabularyId: 'teacher-li',
    vocabularyVersion: vocabularyVersion,
    source: PedagogicalLabelSource.teacherPrompt,
  ),
  scope: VoiceProductionScope(
    protocolId: 'VP-MIX-01@1',
    taskKind: VoiceProductionTaskKind.matchedPitchContrast,
    pitchContextKey: pitchContextKey,
    vowelIpa: vowelIpa,
    loudnessConditionKey: 'medium',
    styleContextKey: 'pop',
    captureProfileKey: 'same-device-15cm',
    algorithmVersion: 'realtime-analysis-v1',
  ),
  updatedAt: DateTime.utc(2026, 8, 27),
);

PracticeSessionRecord _record(
  String id,
  VoiceComparisonPlan plan,
  VoiceComparisonSide side, {
  required double pitch,
  required double level,
  Set<AnalysisQualityFlag> flags = const <AnalysisQualityFlag>{},
  int validFrameCount = 90,
}) => PracticeSessionRecord(
  id: id,
  template: const PracticeTemplate(
    id: 'comparison-take',
    version: 1,
    kind: PracticeKind.targetNote,
    target: PracticeTarget(targetMidiNote: 57),
    reviewStatus: ContentReviewStatus.draft,
  ),
  startedAt: DateTime.utc(2026, 8, 27),
  summary: SessionSummary(
    validFrameCount: validFrameCount,
    totalFrameCount: 100,
    qualityFlags: flags,
    pitchStability: StabilitySummary(
      // Stability summaries are detrended residual statistics, not absolute
      // pitch/level medians. Comparison must read the packed feature frames.
      median: 0,
      medianAbsoluteDeviation: 5,
      slopePerSecond: 0,
      frameCount: 90,
    ),
    levelStability: StabilitySummary(
      median: 0,
      medianAbsoluteDeviation: 1,
      slopePerSecond: 0,
      frameCount: 90,
    ),
    onsetDelaySamples: side == VoiceComparisonSide.a ? 3000 : 3500,
  ),
  features: FeatureSeries(
    frameRateHz: 100,
    frames: <AnalysisFrame>[
      AnalysisFrame(
        sampleIndex: 0,
        rmsDbfs: level,
        peakDbfs: -4,
        pitchClarity: side == VoiceComparisonSide.a ? .8 : .9,
        voiced: true,
        pitchCents: pitch,
        f0Hz: 220,
        bandPowersDb: <double>[
          -30,
          -31,
          -32,
          -33,
          side == VoiceComparisonSide.a ? -24 : -20,
          -35,
          -36,
          -37,
        ],
        algorithmVersion: 'realtime-analysis-v1',
      ),
    ],
  ),
  voiceComparison: VoiceComparisonTakeContext(plan: plan, side: side),
);
