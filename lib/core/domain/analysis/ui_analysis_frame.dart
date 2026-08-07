import 'analysis_quality_flag.dart';

/// A presentation-safe snapshot derived from a raw analysis frame.
///
/// It intentionally carries a bounded pitch history and is emitted at a UI
/// cadence. Summary and persistence continue to consume raw analysis frames.
final class UiAnalysisFrame {
  UiAnalysisFrame({
    required this.sampleIndex,
    required this.targetMidiNote,
    required this.targetCents,
    required this.toleranceCents,
    required this.rmsDbfs,
    required this.peakDbfs,
    required this.pitchClarity,
    required this.voiced,
    required Set<AnalysisQualityFlag> qualityFlags,
    required List<UiPitchPoint> pitchHistory,
    this.f0Hz,
    this.pitchCents,
    this.centsFromTarget,
  }) : assert(sampleIndex >= 0),
       assert(targetMidiNote >= 0 && targetMidiNote <= 127),
       assert(toleranceCents > 0),
       qualityFlags = Set.unmodifiable(qualityFlags),
       pitchHistory = List.unmodifiable(pitchHistory);

  final int sampleIndex;
  final int targetMidiNote;
  final double targetCents;
  final double toleranceCents;
  final double rmsDbfs;
  final double peakDbfs;
  final double pitchClarity;
  final bool voiced;
  final double? f0Hz;
  final double? pitchCents;
  final double? centsFromTarget;
  final Set<AnalysisQualityFlag> qualityFlags;
  final List<UiPitchPoint> pitchHistory;

  bool get isWithinTarget =>
      centsFromTarget != null && centsFromTarget!.abs() <= toleranceCents;
}

/// A single bounded-history pitch sample. A null value represents an unvoiced
/// raw frame rather than an invented pitch.
final class UiPitchPoint {
  const UiPitchPoint({
    required this.sampleIndex,
    required this.pitchCents,
    required this.discontinuityBefore,
  }) : assert(sampleIndex >= 0);

  final int sampleIndex;
  final double? pitchCents;
  final bool discontinuityBefore;
}
