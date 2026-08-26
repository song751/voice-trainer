import 'analysis_frame.dart';
import '../persistence/audio_content_identity.dart';

final class FeatureSeries {
  FeatureSeries({
    required this.frameRateHz,
    required List<AnalysisFrame> frames,
    this.sourceAudioIdentity,
  }) : assert(frameRateHz > 0),
       frames = List.unmodifiable(frames);

  final int frameRateHz;
  final List<AnalysisFrame> frames;
  final AudioContentIdentity? sourceAudioIdentity;

  FeatureSeries withSourceAudioIdentity(AudioContentIdentity? identity) =>
      FeatureSeries(
        frameRateHz: frameRateHz,
        frames: frames,
        sourceAudioIdentity: identity,
      );
}
