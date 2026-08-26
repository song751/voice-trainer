import '../analysis/analysis_frame.dart';
import '../analysis/analysis_quality_flag.dart';
import '../observation/evidence.dart';
import '../observation/observation.dart';
import '../observation/recommendation.dart';
import '../persistence/session_repository.dart';
import '../practice/practice_template.dart';
import 'song_reference.dart';

const referenceComparisonAlgorithmVersion = 'reference-comparison-v1';

final class PhraseRange {
  const PhraseRange({required this.startSeconds, required this.endSeconds})
    : assert(startSeconds >= 0),
      assert(endSeconds > startSeconds);

  final double startSeconds;
  final double endSeconds;

  double get durationSeconds => endSeconds - startSeconds;
}

final class ReferenceAnalysisSeries {
  const ReferenceAnalysisSeries({
    required this.sampleRate,
    required this.frameRateHz,
    required this.algorithmVersion,
    required this.frames,
  });

  final int sampleRate;
  final int frameRateHz;
  final String algorithmVersion;
  final List<AnalysisFrame> frames;
}

enum ReferenceAnalysisFailureReason {
  unavailable,
  inputMissing,
  unsupportedFormat,
  decodeFailed,
  resourceLimitExceeded,
  cancelled,
  insufficientAudio,
  processingFailed,
}

final class ReferenceAnalysisFailure implements Exception {
  const ReferenceAnalysisFailure(this.reason, {this.detail});

  final ReferenceAnalysisFailureReason reason;
  final String? detail;
}

abstract interface class ReferenceFeatureExtractor {
  bool get available;

  Future<ReferenceAnalysisSeries> analyze({
    required SongStemReference vocals,
    required void Function(double progress) onProgress,
  });

  Future<void> cancel();
}

enum AudioPreviewFailureReason {
  unavailable,
  sourceMissing,
  unsupportedLocator,
  playbackFailed,
}

final class AudioPreviewFailure implements Exception {
  const AudioPreviewFailure(this.reason, {this.detail});

  final AudioPreviewFailureReason reason;
  final String? detail;
}

abstract interface class AudioPreview {
  bool get available;

  Future<void> playFile({required String path, required PhraseRange range});

  Future<void> stop();

  Future<void> dispose();
}

final class UnavailableAudioPreview implements AudioPreview {
  const UnavailableAudioPreview();

  @override
  bool get available => false;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playFile({
    required String path,
    required PhraseRange range,
  }) async {
    throw const AudioPreviewFailure(AudioPreviewFailureReason.unavailable);
  }

  @override
  Future<void> stop() async {}
}

enum ReferenceComparisonQualityFlag {
  referenceIsSeparationEstimate,
  separationArtifactPossible,
  artifactReviewRequired,
  monophonicLeadReviewRequired,
  referenceVoicingInsufficient,
  userVoicingInsufficient,
  mutuallyVoicedCoverageInsufficient,
  referenceClipping,
  userCaptureQualityLimited,
  phraseTooShort,
  phraseTooLong,
}

final class ReferenceComparisonReview {
  const ReferenceComparisonReview({
    required this.artifactsAcceptable,
    required this.monophonicLeadConfirmed,
  });

  final bool artifactsAcceptable;
  final bool monophonicLeadConfirmed;
}

final class ReferenceComparisonAlignment {
  const ReferenceComparisonAlignment({
    required this.referenceOnsetSeconds,
    required this.userOnsetSeconds,
    required this.userOnsetDeltaSeconds,
    required this.tempoScale,
    required this.originalKeyDifferenceCents,
    required this.transpositionSemitones,
  });

  final double referenceOnsetSeconds;
  final double userOnsetSeconds;
  final double userOnsetDeltaSeconds;
  final double tempoScale;
  final double originalKeyDifferenceCents;
  final int transpositionSemitones;
}

final class ReferenceComparisonMetrics {
  const ReferenceComparisonMetrics({
    required this.pitchContourMedianAbsoluteCents,
    required this.pitchContourP90AbsoluteCents,
    required this.referenceVoicedCoverage,
    required this.userVoicedCoverage,
    required this.mutuallyVoicedCoverage,
    required this.referenceVoicedSpanSeconds,
    required this.userVoicedSpanSeconds,
    required this.levelEnvelopeMedianAbsoluteDb,
    required this.referenceLevelMadDb,
    required this.userLevelMadDb,
    required this.referencePeriodicityMedian,
    required this.userPeriodicityMedian,
    required this.matchedFrameCount,
  });

  final double pitchContourMedianAbsoluteCents;
  final double pitchContourP90AbsoluteCents;
  final double referenceVoicedCoverage;
  final double userVoicedCoverage;
  final double mutuallyVoicedCoverage;
  final double referenceVoicedSpanSeconds;
  final double userVoicedSpanSeconds;
  final double levelEnvelopeMedianAbsoluteDb;
  final double referenceLevelMadDb;
  final double userLevelMadDb;
  final double referencePeriodicityMedian;
  final double userPeriodicityMedian;
  final int matchedFrameCount;
}

final class ReferenceComparisonReport {
  ReferenceComparisonReport({
    required this.algorithmVersion,
    required this.referenceAnalysisVersion,
    required this.userAnalysisVersion,
    required this.separationAlgorithmVersion,
    required this.referenceName,
    required this.sessionId,
    required this.referenceRange,
    required this.userRange,
    required this.confidence,
    required Set<ReferenceComparisonQualityFlag> qualityFlags,
    required this.scopeLabel,
    required this.referenceProvenanceLabel,
    required List<Observation> observations,
    required List<Recommendation> recommendations,
    this.alignment,
    this.metrics,
    this.suppressedReason,
  }) : qualityFlags = Set.unmodifiable(qualityFlags),
       observations = List.unmodifiable(observations),
       recommendations = List.unmodifiable(recommendations);

  final String referenceName;
  final String algorithmVersion;
  final String referenceAnalysisVersion;
  final String userAnalysisVersion;
  final String separationAlgorithmVersion;
  final String sessionId;
  final PhraseRange referenceRange;
  final PhraseRange userRange;
  final double confidence;
  final Set<ReferenceComparisonQualityFlag> qualityFlags;
  final String scopeLabel;
  final String referenceProvenanceLabel;
  final ReferenceComparisonAlignment? alignment;
  final ReferenceComparisonMetrics? metrics;
  final List<Observation> observations;
  final List<Recommendation> recommendations;
  final String? suppressedReason;

  bool get suppressed => suppressedReason != null;
}

/// Deterministic phrase comparison. It compares only mutually voiced frames,
/// reports every alignment parameter, and never produces a composite score or
/// a vocal-production label.
final class ReferenceComparisonEngine {
  const ReferenceComparisonEngine({
    this.minimumPhraseSeconds = 1,
    this.maximumPhraseSeconds = 30,
    this.minimumVoicedCoverage = 0.45,
    this.minimumMutualCoverage = 0.35,
    this.minimumMatchedFrames = 30,
  });

  final double minimumPhraseSeconds;
  final double maximumPhraseSeconds;
  final double minimumVoicedCoverage;
  final double minimumMutualCoverage;
  final int minimumMatchedFrames;

  ReferenceComparisonReport compare({
    required SeparatedSongReference reference,
    required ReferenceAnalysisSeries referenceFeatures,
    required PracticeSessionRecord session,
    required PhraseRange referenceRange,
    required PhraseRange userRange,
    required ReferenceComparisonReview review,
  }) {
    final flags = <ReferenceComparisonQualityFlag>{
      ReferenceComparisonQualityFlag.referenceIsSeparationEstimate,
      if (reference.artifactWarning)
        ReferenceComparisonQualityFlag.separationArtifactPossible,
    };
    if (!review.artifactsAcceptable) {
      flags.add(ReferenceComparisonQualityFlag.artifactReviewRequired);
    }
    if (!review.monophonicLeadConfirmed) {
      flags.add(ReferenceComparisonQualityFlag.monophonicLeadReviewRequired);
    }
    if (referenceRange.durationSeconds < minimumPhraseSeconds ||
        userRange.durationSeconds < minimumPhraseSeconds) {
      flags.add(ReferenceComparisonQualityFlag.phraseTooShort);
    }
    if (referenceRange.durationSeconds > maximumPhraseSeconds ||
        userRange.durationSeconds > maximumPhraseSeconds) {
      flags.add(ReferenceComparisonQualityFlag.phraseTooLong);
    }
    if (session.summary.qualityFlags.isNotEmpty) {
      flags.add(ReferenceComparisonQualityFlag.userCaptureQualityLimited);
    }

    final referenceWindow = _window(
      referenceFeatures.frames,
      referenceFeatures.frameRateHz,
      referenceRange,
    );
    final userWindow = _window(
      session.features.frames,
      session.features.frameRateHz,
      userRange,
    );
    if (referenceWindow.any(
      (frame) =>
          frame.frame.qualityFlags.contains(AnalysisQualityFlag.clipping),
    )) {
      flags.add(ReferenceComparisonQualityFlag.referenceClipping);
    }

    final referenceVoiced = referenceWindow.where(_isValidVoiced).toList();
    final userVoiced = userWindow.where(_isValidVoiced).toList();
    final referenceCoverage = _coverage(referenceVoiced, referenceWindow);
    final userCoverage = _coverage(userVoiced, userWindow);
    if (referenceCoverage < minimumVoicedCoverage) {
      flags.add(ReferenceComparisonQualityFlag.referenceVoicingInsufficient);
    }
    if (userCoverage < minimumVoicedCoverage) {
      flags.add(ReferenceComparisonQualityFlag.userVoicingInsufficient);
    }

    final preAlignmentBlockers = <ReferenceComparisonQualityFlag>{
      ReferenceComparisonQualityFlag.artifactReviewRequired,
      ReferenceComparisonQualityFlag.monophonicLeadReviewRequired,
      ReferenceComparisonQualityFlag.referenceVoicingInsufficient,
      ReferenceComparisonQualityFlag.userVoicingInsufficient,
      ReferenceComparisonQualityFlag.referenceClipping,
      ReferenceComparisonQualityFlag.userCaptureQualityLimited,
      ReferenceComparisonQualityFlag.phraseTooShort,
      ReferenceComparisonQualityFlag.phraseTooLong,
    };
    if (flags.any(preAlignmentBlockers.contains)) {
      return _suppressed(
        reference: reference,
        session: session,
        referenceRange: referenceRange,
        userRange: userRange,
        flags: flags,
        referenceAnalysisVersion: referenceFeatures.algorithmVersion,
        referenceCoverage: referenceCoverage,
        userCoverage: userCoverage,
        reason: 'quality_or_human_reference_review_insufficient',
      );
    }

    final referenceOnset = referenceVoiced.first.timeSeconds;
    final userOnset = userVoiced.first.timeSeconds;
    final referenceSpan = (referenceVoiced.last.timeSeconds - referenceOnset)
        .clamp(0.01, double.infinity);
    final userSpan = (userVoiced.last.timeSeconds - userOnset).clamp(
      0.01,
      double.infinity,
    );
    final tempoScale = userSpan / referenceSpan;
    final matches = _match(
      referenceVoiced,
      userVoiced,
      referenceOnset,
      userOnset,
      tempoScale,
    );
    final mutualCoverage =
        matches.length / referenceWindow.length.clamp(1, 1 << 30);
    if (matches.length < minimumMatchedFrames ||
        mutualCoverage < minimumMutualCoverage) {
      flags.add(
        ReferenceComparisonQualityFlag.mutuallyVoicedCoverageInsufficient,
      );
      return _suppressed(
        reference: reference,
        session: session,
        referenceRange: referenceRange,
        userRange: userRange,
        flags: flags,
        referenceAnalysisVersion: referenceFeatures.algorithmVersion,
        referenceCoverage: referenceCoverage,
        userCoverage: userCoverage,
        mutualCoverage: mutualCoverage,
        reason: 'mutually_voiced_coverage_insufficient',
      );
    }

    final rawPitchDifferences = matches
        .map(
          (match) =>
              match.user.frame.pitchCents! - match.reference.frame.pitchCents!,
        )
        .toList();
    final keyDifference = _median(rawPitchDifferences);
    final transpositionSemitones = (keyDifference / 100).round();
    final transpositionCents = transpositionSemitones * 100.0;
    final alignedPitchErrors = rawPitchDifferences
        .map((difference) => difference - transpositionCents)
        .toList();
    final referenceLevels = matches
        .map((match) => match.reference.frame.rmsDbfs)
        .toList();
    final userLevels = matches
        .map((match) => match.user.frame.rmsDbfs)
        .toList();
    final referenceLevelMedian = _median(referenceLevels);
    final userLevelMedian = _median(userLevels);
    final envelopeDifferences = List<double>.generate(
      matches.length,
      (index) =>
          ((userLevels[index] - userLevelMedian) -
                  (referenceLevels[index] - referenceLevelMedian))
              .abs(),
    );
    final metrics = ReferenceComparisonMetrics(
      pitchContourMedianAbsoluteCents: _median(
        alignedPitchErrors.map((value) => value.abs()).toList(),
      ),
      pitchContourP90AbsoluteCents: _percentile(
        alignedPitchErrors.map((value) => value.abs()).toList(),
        0.9,
      ),
      referenceVoicedCoverage: referenceCoverage,
      userVoicedCoverage: userCoverage,
      mutuallyVoicedCoverage: mutualCoverage,
      referenceVoicedSpanSeconds: referenceSpan,
      userVoicedSpanSeconds: userSpan,
      levelEnvelopeMedianAbsoluteDb: _median(envelopeDifferences),
      referenceLevelMadDb: _mad(referenceLevels),
      userLevelMadDb: _mad(userLevels),
      referencePeriodicityMedian: _median(
        matches.map((match) => match.reference.frame.pitchClarity).toList(),
      ),
      userPeriodicityMedian: _median(
        matches.map((match) => match.user.frame.pitchClarity).toList(),
      ),
      matchedFrameCount: matches.length,
    );
    final confidence = <double>[
      referenceCoverage,
      userCoverage,
      mutualCoverage,
      metrics.referencePeriodicityMedian,
      metrics.userPeriodicityMedian,
    ].reduce((left, right) => left < right ? left : right).clamp(0.0, 1.0);
    final alignment = ReferenceComparisonAlignment(
      referenceOnsetSeconds: referenceOnset,
      userOnsetSeconds: userOnset,
      userOnsetDeltaSeconds: userOnset - referenceOnset,
      tempoScale: tempoScale,
      originalKeyDifferenceCents: keyDifference,
      transpositionSemitones: transpositionSemitones,
    );
    final evidence = <Evidence>[
      Evidence(
        metric: 'pitch_contour_median_absolute_cents',
        value: metrics.pitchContourMedianAbsoluteCents,
        basis: EvidenceBasis.compatibleHistory,
      ),
      Evidence(
        metric: 'user_onset_delta_seconds',
        value: alignment.userOnsetDeltaSeconds,
        basis: EvidenceBasis.compatibleHistory,
      ),
      Evidence(
        metric: 'level_envelope_median_absolute_db',
        value: metrics.levelEnvelopeMedianAbsoluteDb,
        basis: EvidenceBasis.compatibleHistory,
      ),
      Evidence(
        metric: 'periodicity_median_difference',
        value:
            metrics.userPeriodicityMedian - metrics.referencePeriodicityMedian,
        basis: EvidenceBasis.compatibleHistory,
      ),
      Evidence(
        metric: 'mutually_voiced_coverage',
        value: mutualCoverage,
        basis: EvidenceBasis.absoluteThreshold,
      ),
    ];
    final observation = Observation(
      ruleId: 'reference-phrase-comparison',
      ruleVersion: 1,
      scope: ObservationScope.segment,
      labelKey: 'reference_phrase_relative_differences_observed',
      evidence: evidence,
      confidence: confidence,
      qualityFlags: session.summary.qualityFlags,
      basis: EvidenceBasis.compatibleHistory,
      recommendationIds: const <String>['REFERENCE-AB-01'],
    );
    final recommendation = Recommendation(
      exerciseId: 'REFERENCE-AB-01',
      contentVersion: 1,
      reviewStatus: ContentReviewStatus.draft,
      reasonKey: 'repeat_one_phrase_with_one_relative_target',
      priority: 0,
      confidence: confidence,
      scope: ObservationScope.segment,
      evidenceGrade: RecommendationEvidenceGrade.unvalidated,
      evidence: evidence,
      qualityFlags: session.summary.qualityFlags,
      sourceIds: const <String>['NATS_CURRICULUM'],
      limitations: const <String>[
        'reference_is_model_separation_estimate',
        'separation_artifacts_may_affect_measurement',
        'artistic_reference_is_not_a_unique_correct_answer',
        'content_pending_professional_review',
      ],
    );
    return ReferenceComparisonReport(
      algorithmVersion: referenceComparisonAlgorithmVersion,
      referenceAnalysisVersion: referenceFeatures.algorithmVersion,
      userAnalysisVersion: session.features.frames.isEmpty
          ? 'unknown'
          : session.features.frames.first.algorithmVersion,
      separationAlgorithmVersion: reference.algorithmVersion,
      referenceName: reference.displayName,
      sessionId: session.id,
      referenceRange: referenceRange,
      userRange: userRange,
      confidence: confidence,
      qualityFlags: flags,
      scopeLabel: _scope(referenceRange, userRange),
      referenceProvenanceLabel: '歌曲分离估计（无人声逐句真人标签）',
      alignment: alignment,
      metrics: metrics,
      observations: <Observation>[observation],
      recommendations: <Recommendation>[recommendation],
    );
  }

  ReferenceComparisonReport _suppressed({
    required SeparatedSongReference reference,
    required PracticeSessionRecord session,
    required PhraseRange referenceRange,
    required PhraseRange userRange,
    required Set<ReferenceComparisonQualityFlag> flags,
    required String referenceAnalysisVersion,
    required double referenceCoverage,
    required double userCoverage,
    required String reason,
    double mutualCoverage = 0,
  }) {
    final evidence = <Evidence>[
      Evidence(
        metric: 'reference_voiced_coverage',
        value: referenceCoverage,
        basis: EvidenceBasis.absoluteThreshold,
      ),
      Evidence(
        metric: 'user_voiced_coverage',
        value: userCoverage,
        basis: EvidenceBasis.absoluteThreshold,
      ),
      Evidence(
        metric: 'mutually_voiced_coverage',
        value: mutualCoverage,
        basis: EvidenceBasis.absoluteThreshold,
      ),
    ];
    return ReferenceComparisonReport(
      algorithmVersion: referenceComparisonAlgorithmVersion,
      referenceAnalysisVersion: referenceAnalysisVersion,
      userAnalysisVersion: session.features.frames.isEmpty
          ? 'unknown'
          : session.features.frames.first.algorithmVersion,
      separationAlgorithmVersion: reference.algorithmVersion,
      referenceName: reference.displayName,
      sessionId: session.id,
      referenceRange: referenceRange,
      userRange: userRange,
      confidence: 0,
      qualityFlags: flags,
      scopeLabel: _scope(referenceRange, userRange),
      referenceProvenanceLabel: '歌曲分离估计（无人声逐句真人标签）',
      observations: <Observation>[
        Observation(
          ruleId: 'reference-comparison-suppressed',
          ruleVersion: 1,
          scope: ObservationScope.segment,
          labelKey: 'reference_comparison_suppressed',
          evidence: evidence,
          confidence: 1,
          qualityFlags: session.summary.qualityFlags,
          basis: EvidenceBasis.absoluteThreshold,
          recommendationIds: const <String>['REC-QUALITY-01'],
          suppressedReasonKey: reason,
        ),
      ],
      recommendations: <Recommendation>[
        Recommendation(
          exerciseId: 'REC-QUALITY-01',
          contentVersion: 1,
          reviewStatus: ContentReviewStatus.draft,
          reasonKey: 'improve_reference_or_practice_recording',
          priority: 0,
          confidence: 1,
          scope: ObservationScope.segment,
          evidenceGrade: RecommendationEvidenceGrade.guideline,
          evidence: evidence,
          qualityFlags: session.summary.qualityFlags,
          sourceIds: const <String>['ASHA_MEASURE_2018'],
          limitations: const <String>[
            'consumer_microphone_not_clinical_measurement',
            'reference_is_model_separation_estimate',
          ],
        ),
      ],
      suppressedReason: reason,
    );
  }

  List<_TimedFrame> _window(
    List<AnalysisFrame> frames,
    int frameRateHz,
    PhraseRange range,
  ) {
    if (frames.isEmpty) return const <_TimedFrame>[];
    return List<_TimedFrame>.generate(frames.length, (index) {
      return _TimedFrame(index / frameRateHz, frames[index]);
    }).where((item) {
      return item.timeSeconds >= range.startSeconds &&
          item.timeSeconds <= range.endSeconds;
    }).toList();
  }

  bool _isValidVoiced(_TimedFrame timed) {
    final frame = timed.frame;
    return frame.voiced &&
        frame.pitchCents != null &&
        frame.pitchClarity >= 0.60 &&
        frame.qualityFlags.isEmpty;
  }

  double _coverage(List<_TimedFrame> voiced, List<_TimedFrame> all) =>
      voiced.length / all.length.clamp(1, 1 << 30);

  List<_FrameMatch> _match(
    List<_TimedFrame> reference,
    List<_TimedFrame> user,
    double referenceOnset,
    double userOnset,
    double tempoScale,
  ) {
    final matches = <_FrameMatch>[];
    var referenceIndex = 0;
    for (final userFrame in user) {
      final targetReferenceTime =
          referenceOnset + (userFrame.timeSeconds - userOnset) / tempoScale;
      while (referenceIndex + 1 < reference.length &&
          (reference[referenceIndex + 1].timeSeconds - targetReferenceTime)
                  .abs() <
              (reference[referenceIndex].timeSeconds - targetReferenceTime)
                  .abs()) {
        referenceIndex++;
      }
      if ((reference[referenceIndex].timeSeconds - targetReferenceTime).abs() <=
          0.025) {
        matches.add(_FrameMatch(reference[referenceIndex], userFrame));
      }
    }
    return matches;
  }

  double _median(List<double> values) => _percentile(values, 0.5);

  double _percentile(List<double> values, double percentile) {
    assert(values.isNotEmpty);
    final sorted = List<double>.of(values)..sort();
    final position = (sorted.length - 1) * percentile;
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower];
    final fraction = position - lower;
    return sorted[lower] * (1 - fraction) + sorted[upper] * fraction;
  }

  double _mad(List<double> values) {
    final median = _median(values);
    return _median(values.map((value) => (value - median).abs()).toList());
  }

  String _scope(PhraseRange reference, PhraseRange user) =>
      'reference ${reference.startSeconds.toStringAsFixed(2)}–'
      '${reference.endSeconds.toStringAsFixed(2)} s; user '
      '${user.startSeconds.toStringAsFixed(2)}–'
      '${user.endSeconds.toStringAsFixed(2)} s';
}

final class _TimedFrame {
  const _TimedFrame(this.timeSeconds, this.frame);

  final double timeSeconds;
  final AnalysisFrame frame;
}

final class _FrameMatch {
  const _FrameMatch(this.reference, this.user);

  final _TimedFrame reference;
  final _TimedFrame user;
}
