import '../../core/domain/reference/reference_comparison.dart';

ReferenceFeatureExtractor createDefaultReferenceFeatureExtractor() =>
    const _UnavailableReferenceFeatureExtractor();

AudioPreview createDefaultAudioPreview() => const UnavailableAudioPreview();

final class _UnavailableReferenceFeatureExtractor
    implements ReferenceFeatureExtractor {
  const _UnavailableReferenceFeatureExtractor();

  @override
  bool get available => false;

  @override
  Future<ReferenceAnalysisSeries> analyze({
    required vocals,
    required void Function(double progress) onProgress,
  }) async {
    throw const ReferenceAnalysisFailure(
      ReferenceAnalysisFailureReason.unavailable,
    );
  }

  @override
  Future<void> cancel() async {}
}
