import 'capture_format.dart';

enum CaptureHealthFlag { discontinuity, droppedSamples, processingAdjusted }

final class CaptureHealth {
  CaptureHealth({
    required this.effectiveFormat,
    this.droppedSamples = 0,
    Set<CaptureHealthFlag> flags = const <CaptureHealthFlag>{},
  }) : assert(droppedSamples >= 0),
       flags = Set.unmodifiable(flags);

  final CaptureFormat effectiveFormat;
  final int droppedSamples;
  final Set<CaptureHealthFlag> flags;

  bool get hasDiscontinuity => flags.contains(CaptureHealthFlag.discontinuity);
}
