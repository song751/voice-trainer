import 'analysis_quality_flag.dart';

final class AnalysisFrame {
  AnalysisFrame({
    required this.sampleIndex,
    required this.rmsDbfs,
    required this.peakDbfs,
    required this.pitchClarity,
    required this.voiced,
    required this.algorithmVersion,
    this.f0Hz,
    this.pitchCents,
    List<double> bandPowersDb = const <double>[],
    List<double> spectrumBinsDb = const <double>[],
    Set<AnalysisQualityFlag> qualityFlags = const <AnalysisQualityFlag>{},
  }) : assert(sampleIndex >= 0),
       bandPowersDb = List.unmodifiable(bandPowersDb),
       spectrumBinsDb = List.unmodifiable(spectrumBinsDb),
       qualityFlags = Set.unmodifiable(qualityFlags);

  final int sampleIndex;
  final double rmsDbfs;
  final double peakDbfs;
  final double pitchClarity;
  final bool voiced;
  final String algorithmVersion;
  final double? f0Hz;
  final double? pitchCents;
  final List<double> bandPowersDb;
  final List<double> spectrumBinsDb;
  final Set<AnalysisQualityFlag> qualityFlags;
}

final class AnalysisBatch {
  AnalysisBatch(List<AnalysisFrame> frames)
    : frames = List.unmodifiable(frames);

  final List<AnalysisFrame> frames;
}
