import 'dart:math' as math;

import '../../../core/domain/analysis/analysis_frame.dart';
import '../../../core/domain/analysis/analysis_quality_flag.dart';
import '../../../core/domain/analysis/voice_comparison.dart';
import '../../../core/domain/analysis/voice_production_profile.dart';
import '../../../core/domain/persistence/session_repository.dart';

enum VoiceComparisonEvidenceStatus { waitingForTakes, suppressed, ready }

final class VoiceComparisonDelta {
  const VoiceComparisonDelta({
    required this.metricId,
    required this.valueBMinusA,
    required this.unit,
  });

  final String metricId;
  final double valueBMinusA;
  final VoiceMeasurementUnit unit;
}

final class VoiceComparisonEvidence {
  VoiceComparisonEvidence({
    required this.status,
    required this.plan,
    required this.takeCountA,
    required this.takeCountB,
    required this.rejectedTakeCount,
    required this.confidence,
    required List<VoiceComparisonDelta> deltas,
    required Set<AnalysisQualityFlag> qualityFlags,
    this.suppressedReason,
  }) : deltas = List.unmodifiable(deltas),
       qualityFlags = Set.unmodifiable(qualityFlags);

  final VoiceComparisonEvidenceStatus status;
  final VoiceComparisonPlan plan;
  final int takeCountA;
  final int takeCountB;
  final int rejectedTakeCount;
  final VoiceProductionConfidence confidence;
  final List<VoiceComparisonDelta> deltas;
  final Set<AnalysisQualityFlag> qualityFlags;
  final String? suppressedReason;
}

VoiceComparisonEvidence buildVoiceComparisonEvidence({
  required VoiceComparisonPlan plan,
  required List<PracticeSessionRecord> records,
}) {
  final candidates = records
      .where((record) {
        final context = record.voiceComparison;
        return context != null && context.plan.id == plan.id;
      })
      .toList(growable: false);
  final candidateA = candidates
      .where((record) => record.voiceComparison!.side == VoiceComparisonSide.a)
      .toList(growable: false);
  final candidateB = candidates
      .where((record) => record.voiceComparison!.side == VoiceComparisonSide.b)
      .toList(growable: false);
  final snapshotsMatch = candidates.every(
    (record) => record.voiceComparison!.plan.hasSameSnapshotAs(plan),
  );
  if (!snapshotsMatch) {
    return VoiceComparisonEvidence(
      status: VoiceComparisonEvidenceStatus.suppressed,
      plan: plan,
      takeCountA: candidateA.length,
      takeCountB: candidateB.length,
      rejectedTakeCount: 0,
      confidence: VoiceProductionConfidence(
        signalQuality: 0,
        taskMatch: 0,
        repeatability: 0,
        labelAgreement: _labelAgreement(plan),
      ),
      deltas: const <VoiceComparisonDelta>[],
      qualityFlags: const <AnalysisQualityFlag>{},
      suppressedReason: '同一计划 ID 下存在不一致的标签、词表来源或匹配条件快照',
    );
  }

  final rejected = candidates
      .where((record) => !_passesTakeQuality(record))
      .toList(growable: false);
  final usable = candidates.where(_passesTakeQuality).toList(growable: false);
  final a = usable
      .where((record) => record.voiceComparison!.side == VoiceComparisonSide.a)
      .toList(growable: false);
  final b = usable
      .where((record) => record.voiceComparison!.side == VoiceComparisonSide.b)
      .toList(growable: false);
  final flags = <AnalysisQualityFlag>{
    ...rejected.expand((record) => record.summary.qualityFlags),
    if (rejected.any((record) => record.summary.validFrameRatio < .3))
      AnalysisQualityFlag.insufficientValidFrames,
  };
  final signalQuality = usable.isEmpty
      ? 0.0
      : usable
            .map((record) => record.summary.validFrameRatio.clamp(0.0, 1.0))
            .reduce(math.min);
  final confidence = VoiceProductionConfidence(
    signalQuality: signalQuality,
    taskMatch: 1,
    repeatability: _repeatability(a, b),
    labelAgreement: _labelAgreement(plan),
  );
  if (candidateA.isEmpty || candidateB.isEmpty) {
    return VoiceComparisonEvidence(
      status: VoiceComparisonEvidenceStatus.waitingForTakes,
      plan: plan,
      takeCountA: a.length,
      takeCountB: b.length,
      rejectedTakeCount: rejected.length,
      confidence: confidence,
      deltas: const <VoiceComparisonDelta>[],
      qualityFlags: flags,
    );
  }
  if (a.isEmpty || b.isEmpty) {
    return VoiceComparisonEvidence(
      status: VoiceComparisonEvidenceStatus.suppressed,
      plan: plan,
      takeCountA: a.length,
      takeCountB: b.length,
      rejectedTakeCount: rejected.length,
      confidence: confidence,
      deltas: const <VoiceComparisonDelta>[],
      qualityFlags: flags,
      suppressedReason: 'A/B 至少一侧没有通过录音质量门槛的样本',
    );
  }
  final deltas = <VoiceComparisonDelta>[
    if (_difference(a, b, _pitchMedian) case final value?)
      VoiceComparisonDelta(
        metricId: 'pitch_median',
        valueBMinusA: value,
        unit: VoiceMeasurementUnit.cents,
      ),
    if (_difference(a, b, _levelMedian) case final value?)
      VoiceComparisonDelta(
        metricId: 'level_median',
        valueBMinusA: value,
        unit: VoiceMeasurementUnit.dbfs,
      ),
    if (_difference(a, b, _periodicityMedian) case final value?)
      VoiceComparisonDelta(
        metricId: 'periodicity_median',
        valueBMinusA: value,
        unit: VoiceMeasurementUnit.normalizedScore,
      ),
    if (_difference(a, b, _onsetSamples) case final value?)
      VoiceComparisonDelta(
        metricId: 'onset_delay',
        valueBMinusA: value,
        unit: VoiceMeasurementUnit.samples,
      ),
    if (_difference(a, b, _relativeTwoToFourKhz) case final value?)
      VoiceComparisonDelta(
        metricId: 'relative_2_4khz',
        valueBMinusA: value,
        unit: VoiceMeasurementUnit.decibels,
      ),
  ];
  return VoiceComparisonEvidence(
    status: deltas.isEmpty
        ? VoiceComparisonEvidenceStatus.suppressed
        : VoiceComparisonEvidenceStatus.ready,
    plan: plan,
    takeCountA: a.length,
    takeCountB: b.length,
    rejectedTakeCount: rejected.length,
    confidence: confidence,
    deltas: deltas,
    qualityFlags: flags,
    suppressedReason: deltas.isEmpty ? '可比测量不足' : null,
  );
}

bool _passesTakeQuality(PracticeSessionRecord record) =>
    record.summary.qualityFlags.isEmpty && record.summary.validFrameRatio >= .3;

double? _difference(
  List<PracticeSessionRecord> a,
  List<PracticeSessionRecord> b,
  double? Function(PracticeSessionRecord) read,
) {
  final aValues = a.map(read).whereType<double>().toList(growable: false);
  final bValues = b.map(read).whereType<double>().toList(growable: false);
  if (aValues.isEmpty || bValues.isEmpty) return null;
  return _median(bValues) - _median(aValues);
}

double? _pitchMedian(PracticeSessionRecord record) {
  final values = record.features.frames
      .where(_validFrame)
      .map((frame) => frame.pitchCents)
      .whereType<double>()
      .toList(growable: false);
  return values.isEmpty ? null : _median(values);
}

double? _levelMedian(PracticeSessionRecord record) {
  final values = record.features.frames
      .where((frame) => frame.qualityFlags.isEmpty)
      .map((frame) => frame.rmsDbfs)
      .toList(growable: false);
  return values.isEmpty ? null : _median(values);
}

double? _onsetSamples(PracticeSessionRecord record) =>
    record.summary.onsetDelaySamples?.toDouble();

double? _periodicityMedian(PracticeSessionRecord record) {
  final values = record.features.frames
      .where(_validFrame)
      .map((frame) => frame.pitchClarity)
      .toList(growable: false);
  return values.isEmpty ? null : _median(values);
}

double? _relativeTwoToFourKhz(PracticeSessionRecord record) {
  final values = record.features.frames
      .where(_validFrame)
      .where((frame) => frame.bandPowersDb.length == 8)
      .map((frame) {
        final totalPower = frame.bandPowersDb
            .map((db) => math.pow(10, db / 10).toDouble())
            .fold(0.0, (sum, value) => sum + value);
        return totalPower <= 0
            ? null
            : frame.bandPowersDb[4] - 10 * math.log(totalPower) / math.ln10;
      })
      .whereType<double>()
      .toList(growable: false);
  return values.isEmpty ? null : _median(values);
}

bool _validFrame(AnalysisFrame frame) =>
    frame.voiced && frame.qualityFlags.isEmpty;

double _repeatability(
  List<PracticeSessionRecord> a,
  List<PracticeSessionRecord> b,
) {
  if (a.isEmpty || b.isEmpty) return 0;
  final minimumCount = math.min(a.length, b.length);
  final countScore = switch (minimumCount) {
    1 => .5,
    2 => .75,
    _ => 1.0,
  };
  if (a.length == 1 || b.length == 1) return math.min(.5, countScore);
  final pitchScore = math.min(
    _withinSideScore(a, _pitchMedian, 100),
    _withinSideScore(b, _pitchMedian, 100),
  );
  final levelScore = math.min(
    _withinSideScore(a, _levelMedian, 6),
    _withinSideScore(b, _levelMedian, 6),
  );
  return <double>[countScore, pitchScore, levelScore].reduce(math.min);
}

double _withinSideScore(
  List<PracticeSessionRecord> records,
  double? Function(PracticeSessionRecord) read,
  double scale,
) {
  final values = records.map(read).whereType<double>().toList(growable: false);
  return values.length < 2 ? 1 : (1 - _mad(values) / scale).clamp(0.0, 1.0);
}

double? _labelAgreement(VoiceComparisonPlan plan) {
  final values = <double>[?plan.labelA.confidence, ?plan.labelB.confidence];
  return values.isEmpty ? null : values.reduce(math.min);
}

double _median(List<double> values) {
  final sorted = values.toList(growable: false)..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

double _mad(List<double> values) {
  final median = _median(values);
  return _median(values.map((value) => (value - median).abs()).toList());
}
