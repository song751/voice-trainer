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
  final VoiceProductionConfidence confidence;
  final List<VoiceComparisonDelta> deltas;
  final Set<AnalysisQualityFlag> qualityFlags;
  final String? suppressedReason;
}

VoiceComparisonEvidence buildVoiceComparisonEvidence({
  required VoiceComparisonPlan plan,
  required List<PracticeSessionRecord> records,
}) {
  final takes = records
      .where((record) {
        final context = record.voiceComparison;
        return context != null && context.plan.id == plan.id;
      })
      .toList(growable: false);
  final a = takes
      .where((record) => record.voiceComparison!.side == VoiceComparisonSide.a)
      .toList(growable: false);
  final b = takes
      .where((record) => record.voiceComparison!.side == VoiceComparisonSide.b)
      .toList(growable: false);
  final flags = takes.expand((record) => record.summary.qualityFlags).toSet();
  final signalQuality = takes.isEmpty
      ? 0.0
      : takes
            .map((record) => record.summary.validFrameRatio.clamp(0.0, 1.0))
            .reduce(math.min);
  final scopesMatch = takes.every(
    (record) => record.voiceComparison!.plan.scope.isComparableWith(plan.scope),
  );
  final confidence = VoiceProductionConfidence(
    signalQuality: signalQuality,
    taskMatch: scopesMatch ? 1 : 0,
    repeatability: _repeatability(a, b),
    labelAgreement: _labelAgreement(plan),
  );
  if (a.isEmpty || b.isEmpty) {
    return VoiceComparisonEvidence(
      status: VoiceComparisonEvidenceStatus.waitingForTakes,
      plan: plan,
      takeCountA: a.length,
      takeCountB: b.length,
      confidence: confidence,
      deltas: const <VoiceComparisonDelta>[],
      qualityFlags: flags,
    );
  }
  if (!scopesMatch || flags.isNotEmpty || signalQuality < .3) {
    return VoiceComparisonEvidence(
      status: VoiceComparisonEvidenceStatus.suppressed,
      plan: plan,
      takeCountA: a.length,
      takeCountB: b.length,
      confidence: confidence,
      deltas: const <VoiceComparisonDelta>[],
      qualityFlags: flags,
      suppressedReason: !scopesMatch
          ? 'pitch/vowel/loudness/style/capture/protocol 条件不一致'
          : '至少一个样本未通过录音质量门槛',
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
    confidence: confidence,
    deltas: deltas,
    qualityFlags: flags,
    suppressedReason: deltas.isEmpty ? '可比测量不足' : null,
  );
}

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
  final pitchValues = <double>[
    ...a.map(_pitchMedian).whereType<double>(),
    ...b.map(_pitchMedian).whereType<double>(),
  ];
  final levelValues = <double>[
    ...a.map(_levelMedian).whereType<double>(),
    ...b.map(_levelMedian).whereType<double>(),
  ];
  final pitchScore = pitchValues.length < 2
      ? 1.0
      : (1 - _mad(pitchValues) / 100).clamp(0.0, 1.0);
  final levelScore = levelValues.length < 2
      ? 1.0
      : (1 - _mad(levelValues) / 6).clamp(0.0, 1.0);
  return <double>[countScore, pitchScore, levelScore].reduce(math.min);
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
