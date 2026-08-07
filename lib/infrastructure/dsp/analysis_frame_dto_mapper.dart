import 'dart:math' as math;

import '../../core/domain/analysis/analysis_frame.dart';
import '../../core/domain/analysis/analysis_quality_flag.dart';

const _bandPowerCount = 8;
const _knownQualityMask = 0x1f;

/// Maps the deliberately bounded Rust/worker DTO into the app domain model.
///
/// The wire format carries no analyzer state and deliberately omits the
/// 128-bin UI spectrum. Its compact `qualityFlags` bitset is decoded here so
/// the domain layer never depends on Rust's representation.
AnalysisFrame mapAnalysisFrameDto({
  required int startSample,
  required double rmsDbfs,
  required double peakDbfs,
  required double pitchClarity,
  required bool voiced,
  required List<double> bandPowersDb,
  required int qualityFlags,
  double? f0Hz,
}) {
  if (bandPowersDb.length != _bandPowerCount) {
    throw ArgumentError.value(
      bandPowersDb.length,
      'bandPowersDb.length',
      'Bridge DTO must contain exactly $_bandPowerCount band powers.',
    );
  }
  if (qualityFlags & ~_knownQualityMask != 0) {
    throw ArgumentError.value(
      qualityFlags,
      'qualityFlags',
      'Bridge DTO contains unknown quality flag bits.',
    );
  }
  if (voiced != (f0Hz != null)) {
    throw ArgumentError.value(
      f0Hz,
      'f0Hz',
      'Voiced state must agree with the optional pitch value.',
    );
  }
  return AnalysisFrame(
    sampleIndex: startSample,
    rmsDbfs: rmsDbfs,
    peakDbfs: peakDbfs,
    pitchClarity: pitchClarity,
    voiced: voiced,
    algorithmVersion: 'phase2-yin-spectrum-v1',
    f0Hz: f0Hz,
    pitchCents: _midiCents(f0Hz),
    bandPowersDb: bandPowersDb,
    qualityFlags: _qualityFlags(qualityFlags),
  );
}

double? _midiCents(double? frequencyHz) =>
    frequencyHz == null || frequencyHz <= 0
    ? null
    : 6900 + 1200 * (math.log(frequencyHz / 440) / math.ln2);

Set<AnalysisQualityFlag> _qualityFlags(int mask) => <AnalysisQualityFlag>{
  if (mask & 0x01 != 0) AnalysisQualityFlag.clipping,
  if (mask & 0x02 != 0) AnalysisQualityFlag.inputTooLow,
  if (mask & 0x04 != 0) AnalysisQualityFlag.droppedSamples,
  if (mask & 0x08 != 0) AnalysisQualityFlag.discontinuity,
  if (mask & 0x10 != 0) AnalysisQualityFlag.insufficientValidFrames,
};
