import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/analysis/feature_series.dart';
import 'package:voice_trainer/core/domain/analysis/session_summary.dart';
import 'package:voice_trainer/core/domain/persistence/recording_locator.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/core/domain/reference/reference_comparison.dart';
import 'package:voice_trainer/core/domain/reference/song_reference.dart';

void main() {
  const engine = ReferenceComparisonEngine();

  test('reports explicit time/key alignment and independent metrics', () {
    final referenceFrames = _frames(
      voicedStart: 0,
      voicedEnd: 200,
      pitchOffsetCents: 0,
      levelOffsetDb: 0,
      clarity: 0.92,
    );
    final userFrames = _frames(
      voicedStart: 20,
      voicedEnd: 220,
      pitchOffsetCents: 200,
      levelOffsetDb: -8,
      clarity: 0.84,
    );

    final report = engine.compare(
      reference: _reference(),
      referenceFeatures: ReferenceAnalysisSeries(
        sampleRate: 44100,
        frameRateHz: 100,
        algorithmVersion: 'reference-test-v1',
        frames: referenceFrames,
      ),
      session: _session(userFrames),
      referenceRange: const PhraseRange(startSeconds: 0, endSeconds: 3),
      userRange: const PhraseRange(startSeconds: 0, endSeconds: 3),
      review: const ReferenceComparisonReview(
        artifactsAcceptable: true,
        monophonicLeadConfirmed: true,
      ),
    );

    expect(report.suppressed, isFalse);
    expect(report.alignment!.userOnsetDeltaSeconds, closeTo(0.2, 1e-9));
    expect(report.alignment!.originalKeyDifferenceCents, closeTo(200, 0.1));
    expect(report.alignment!.transpositionSemitones, 2);
    expect(report.metrics!.pitchContourMedianAbsoluteCents, closeTo(0, 0.2));
    expect(report.metrics!.levelEnvelopeMedianAbsoluteDb, closeTo(0, 0.01));
    expect(report.metrics!.referencePeriodicityMedian, closeTo(0.92, 1e-9));
    expect(report.metrics!.userPeriodicityMedian, closeTo(0.84, 1e-9));
    expect(report.observations.single.ruleId, 'reference-phrase-comparison');
    expect(report.recommendations.single.exerciseId, 'REFERENCE-AB-01');
    expect(
      report.recommendations.single.limitations,
      contains('reference_is_model_separation_estimate'),
    );
  });

  test(
    'suppresses interpretation until artifact and monophony review pass',
    () {
      final frames = _frames(
        voicedStart: 0,
        voicedEnd: 200,
        pitchOffsetCents: 0,
        levelOffsetDb: 0,
        clarity: 0.9,
      );
      final report = engine.compare(
        reference: _reference(),
        referenceFeatures: ReferenceAnalysisSeries(
          sampleRate: 44100,
          frameRateHz: 100,
          algorithmVersion: 'reference-test-v1',
          frames: frames,
        ),
        session: _session(frames),
        referenceRange: const PhraseRange(startSeconds: 0, endSeconds: 2),
        userRange: const PhraseRange(startSeconds: 0, endSeconds: 2),
        review: const ReferenceComparisonReview(
          artifactsAcceptable: false,
          monophonicLeadConfirmed: false,
        ),
      );

      expect(report.suppressed, isTrue);
      expect(report.metrics, isNull);
      expect(
        report.qualityFlags,
        contains(ReferenceComparisonQualityFlag.artifactReviewRequired),
      );
      expect(
        report.qualityFlags,
        contains(ReferenceComparisonQualityFlag.monophonicLeadReviewRequired),
      );
      expect(report.observations.single.suppressedReasonKey, isNotNull);
    },
  );

  test('silence and low voiced coverage never produce comparison metrics', () {
    final voiced = _frames(
      voicedStart: 0,
      voicedEnd: 200,
      pitchOffsetCents: 0,
      levelOffsetDb: 0,
      clarity: 0.9,
    );
    final silent = _frames(
      voicedStart: 0,
      voicedEnd: 0,
      pitchOffsetCents: 0,
      levelOffsetDb: -90,
      clarity: 0,
    );
    final report = engine.compare(
      reference: _reference(),
      referenceFeatures: ReferenceAnalysisSeries(
        sampleRate: 44100,
        frameRateHz: 100,
        algorithmVersion: 'reference-test-v1',
        frames: silent,
      ),
      session: _session(voiced),
      referenceRange: const PhraseRange(startSeconds: 0, endSeconds: 2),
      userRange: const PhraseRange(startSeconds: 0, endSeconds: 2),
      review: const ReferenceComparisonReview(
        artifactsAcceptable: true,
        monophonicLeadConfirmed: true,
      ),
    );

    expect(report.suppressed, isTrue);
    expect(
      report.qualityFlags,
      contains(ReferenceComparisonQualityFlag.referenceVoicingInsufficient),
    );
    expect(report.metrics, isNull);
  });

  test('onset delta is relative to each selected phrase window', () {
    final referenceFrames = _frames(
      frameCount: 500,
      voicedStart: 110,
      voicedEnd: 310,
      pitchOffsetCents: 0,
      levelOffsetDb: 0,
      clarity: 0.9,
    );
    final userFrames = _frames(
      frameCount: 500,
      voicedStart: 220,
      voicedEnd: 420,
      pitchOffsetCents: 0,
      levelOffsetDb: 0,
      clarity: 0.9,
    );

    final report = engine.compare(
      reference: _reference(durationSamples: 44100 * 5),
      referenceFeatures: ReferenceAnalysisSeries(
        sampleRate: 44100,
        frameRateHz: 100,
        algorithmVersion: 'reference-test-v1',
        frames: referenceFrames,
      ),
      session: _session(userFrames),
      referenceRange: const PhraseRange(startSeconds: 1, endSeconds: 4),
      userRange: const PhraseRange(startSeconds: 2, endSeconds: 5),
      review: const ReferenceComparisonReview(
        artifactsAcceptable: true,
        monophonicLeadConfirmed: true,
      ),
    );

    expect(report.suppressed, isFalse);
    expect(report.alignment!.referenceOnsetSeconds, closeTo(1.1, 1e-9));
    expect(report.alignment!.userOnsetSeconds, closeTo(2.2, 1e-9));
    expect(report.alignment!.userOnsetDeltaSeconds, closeTo(0.1, 1e-9));
  });

  test('mutual coverage uses unique symmetric frame occupancy', () {
    const conservativeEngine = ReferenceComparisonEngine(
      minimumMutualCoverage: 0.75,
    );
    final referenceFrames = _frames(
      frameCount: 450,
      voicedStart: 0,
      voicedEnd: 150,
      pitchOffsetCents: 0,
      levelOffsetDb: 0,
      clarity: 0.9,
    );
    final userFrames = _frames(
      frameCount: 450,
      voicedStart: 0,
      voicedEnd: 300,
      pitchOffsetCents: 0,
      levelOffsetDb: 0,
      clarity: 0.9,
    );

    final report = conservativeEngine.compare(
      reference: _reference(),
      referenceFeatures: ReferenceAnalysisSeries(
        sampleRate: 44100,
        frameRateHz: 100,
        algorithmVersion: 'reference-test-v1',
        frames: referenceFrames,
      ),
      session: _session(userFrames),
      referenceRange: const PhraseRange(startSeconds: 0, endSeconds: 1.49),
      userRange: const PhraseRange(startSeconds: 0, endSeconds: 2.99),
      review: const ReferenceComparisonReview(
        artifactsAcceptable: true,
        monophonicLeadConfirmed: true,
      ),
    );

    expect(report.suppressed, isTrue);
    expect(
      report.qualityFlags,
      contains(
        ReferenceComparisonQualityFlag.mutuallyVoicedCoverageInsufficient,
      ),
    );
    final coverage = report.observations.single.evidence.singleWhere(
      (evidence) => evidence.metric == 'mutually_voiced_coverage',
    );
    expect(coverage.value, closeTo(0.5, 0.01));
    expect(coverage.value, inInclusiveRange(0.0, 1.0));

    final reversed = conservativeEngine.compare(
      reference: _reference(),
      referenceFeatures: ReferenceAnalysisSeries(
        sampleRate: 44100,
        frameRateHz: 100,
        algorithmVersion: 'reference-test-v1',
        frames: userFrames,
      ),
      session: _session(referenceFrames),
      referenceRange: const PhraseRange(startSeconds: 0, endSeconds: 2.99),
      userRange: const PhraseRange(startSeconds: 0, endSeconds: 1.49),
      review: const ReferenceComparisonReview(
        artifactsAcceptable: true,
        monophonicLeadConfirmed: true,
      ),
    );
    final reversedCoverage = reversed.observations.single.evidence.singleWhere(
      (evidence) => evidence.metric == 'mutually_voiced_coverage',
    );
    expect(reversedCoverage.value, closeTo(coverage.value, 1e-9));
  });
}

List<AnalysisFrame> _frames({
  int frameCount = 300,
  required int voicedStart,
  required int voicedEnd,
  required double pitchOffsetCents,
  required double levelOffsetDb,
  required double clarity,
}) => List<AnalysisFrame>.generate(frameCount, (index) {
  final voiced = index >= voicedStart && index < voicedEnd;
  final phase = voiced ? (index - voicedStart) / (voicedEnd - voicedStart) : 0;
  return AnalysisFrame(
    sampleIndex: index * 480,
    rmsDbfs: voiced
        ? -24 + levelOffsetDb + 2 * math.sin(phase * math.pi * 2)
        : -90,
    peakDbfs: voiced ? -18 + levelOffsetDb : -80,
    pitchClarity: voiced ? clarity : 0,
    voiced: voiced,
    algorithmVersion: 'test-v1',
    pitchCents: voiced
        ? 5700 + pitchOffsetCents + 30 * math.sin(phase * math.pi * 2)
        : null,
  );
});

SeparatedSongReference _reference({int durationSamples = 44100 * 3}) =>
    SeparatedSongReference(
      displayName: 'licensed-song.wav',
      generatedByModel: true,
      modelId: 'umxhq-vocals',
      algorithmVersion: 'srd04-umxhq-waveform-v1',
      sampleRate: 44100,
      channels: 2,
      durationSamples: durationSamples,
      artifactWarning: true,
      vocals: SongStemReference(
        locator: r'C:\test\vocals.wav',
        sha256: 'abc',
        byteLength: 100,
      ),
    );

PracticeSessionRecord _session(List<AnalysisFrame> frames) =>
    PracticeSessionRecord(
      id: 'session-1',
      template: const PracticeTemplate(
        id: 'phrase',
        version: 1,
        kind: PracticeKind.sustainedNote,
        target: PracticeTarget(targetMidiNote: 57),
        reviewStatus: ContentReviewStatus.draft,
      ),
      startedAt: DateTime.utc(2026, 8, 27),
      summary: SessionSummary(
        validFrameCount: 200,
        totalFrameCount: 300,
        targetHitRate: 0.8,
        qualityFlags: {},
      ),
      features: FeatureSeries(frameRateHz: 100, frames: frames),
      recording: const RecordingLocator(
        value: r'C:\test\practice.wav',
        storageKind: RecordingStorageKind.file,
      ),
    );
