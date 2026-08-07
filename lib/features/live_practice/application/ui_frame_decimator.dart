import '../../../core/domain/analysis/analysis_frame.dart';
import '../../../core/domain/analysis/analysis_quality_flag.dart';
import '../../../core/domain/analysis/ui_analysis_frame.dart';
import '../../../core/domain/practice/practice_target.dart';

/// Converts 100 Hz DSP frames into sample-index paced UI snapshots.
///
/// This deliberately has no Flutter or Riverpod dependency. It preserves a
/// fixed raw-pitch ring for drawing while emitting at most [uiFrameRateHz].
final class UiFrameDecimator {
  UiFrameDecimator({
    required this.target,
    this.sampleRate = 48000,
    this.uiFrameRateHz = 25,
    this.pitchRingCapacity = 600,
  }) : assert(sampleRate > 0),
       assert(uiFrameRateHz >= 20 && uiFrameRateHz <= 30),
       assert(pitchRingCapacity > 0);

  final PracticeTarget target;
  final int sampleRate;
  final int uiFrameRateHz;
  final int pitchRingCapacity;
  final List<UiPitchPoint> _pitchRing = <UiPitchPoint>[];
  int? _lastEmittedSampleIndex;

  int get _minimumIntervalSamples => sampleRate ~/ uiFrameRateHz;

  UiAnalysisFrame? add(AnalysisFrame frame) {
    final isDiscontinuous = frame.qualityFlags.contains(
      AnalysisQualityFlag.discontinuity,
    );
    _pitchRing.add(
      UiPitchPoint(
        sampleIndex: frame.sampleIndex,
        pitchCents: frame.voiced ? frame.pitchCents : null,
        discontinuityBefore: isDiscontinuous,
      ),
    );
    if (_pitchRing.length > pitchRingCapacity) {
      _pitchRing.removeAt(0);
    }

    final last = _lastEmittedSampleIndex;
    if (last != null && frame.sampleIndex - last < _minimumIntervalSamples) {
      return null;
    }
    _lastEmittedSampleIndex = frame.sampleIndex;
    final pitchCents = frame.voiced ? frame.pitchCents : null;
    final targetCents = target.targetMidiNote * 100.0;
    return UiAnalysisFrame(
      sampleIndex: frame.sampleIndex,
      targetMidiNote: target.targetMidiNote,
      targetCents: targetCents,
      toleranceCents: target.toleranceCents,
      rmsDbfs: frame.rmsDbfs,
      peakDbfs: frame.peakDbfs,
      pitchClarity: frame.pitchClarity,
      voiced: frame.voiced,
      f0Hz: frame.voiced ? frame.f0Hz : null,
      pitchCents: pitchCents,
      centsFromTarget: pitchCents == null ? null : pitchCents - targetCents,
      qualityFlags: frame.qualityFlags,
      pitchHistory: _pitchRing,
    );
  }
}

Stream<UiAnalysisFrame> decimateUiAnalysisFrames(
  Stream<AnalysisFrame> rawFrames, {
  required PracticeTarget target,
  int sampleRate = 48000,
  int uiFrameRateHz = 25,
  int pitchRingCapacity = 600,
}) async* {
  final decimator = UiFrameDecimator(
    target: target,
    sampleRate: sampleRate,
    uiFrameRateHz: uiFrameRateHz,
    pitchRingCapacity: pitchRingCapacity,
  );
  await for (final frame in rawFrames) {
    final uiFrame = decimator.add(frame);
    if (uiFrame != null) {
      yield uiFrame;
    }
  }
}
