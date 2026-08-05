final class AnalysisConfig {
  const AnalysisConfig({
    required this.inputFormatSampleRate,
    this.minPitchHz = 60,
    this.maxPitchHz = 1200,
    this.bridgeBatchSamples = 1024,
  }) : assert(inputFormatSampleRate > 0),
       assert(minPitchHz > 0),
       assert(maxPitchHz >= minPitchHz),
       assert(bridgeBatchSamples > 0);

  final int inputFormatSampleRate;
  final double minPitchHz;
  final double maxPitchHz;
  final int bridgeBatchSamples;
}
