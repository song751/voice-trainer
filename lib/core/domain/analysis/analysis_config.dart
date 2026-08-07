import '../audio/capture_format.dart';

final class AnalysisConfig {
  const AnalysisConfig({
    required this.inputFormat,
    this.minPitchHz = 60,
    this.maxPitchHz = 1200,
    this.bridgeBatchSamples = 1024,
  }) : assert(minPitchHz > 0),
       assert(maxPitchHz >= minPitchHz),
       assert(bridgeBatchSamples > 0);

  /// The format actually negotiated by [CaptureSession], not the requested
  /// format. Keeping channels and encoding here prevents a 44.1 kHz or stereo
  /// stream from being silently treated as canonical 48 kHz mono PCM16.
  final CaptureFormat inputFormat;

  int get inputFormatSampleRate => inputFormat.sampleRate;
  final double minPitchHz;
  final double maxPitchHz;
  final int bridgeBatchSamples;
}
