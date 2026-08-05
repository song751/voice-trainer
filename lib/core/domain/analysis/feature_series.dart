import 'analysis_frame.dart';

final class FeatureSeries {
  FeatureSeries({
    required this.frameRateHz,
    required List<AnalysisFrame> frames,
  }) : assert(frameRateHz > 0),
       frames = List.unmodifiable(frames);

  final int frameRateHz;
  final List<AnalysisFrame> frames;
}
