import '../analysis/analysis_quality_flag.dart';
import '../practice/practice_template.dart';
import 'evidence.dart';
import 'observation.dart';

enum RecommendationEvidenceGrade {
  guideline,
  systematicReview,
  controlledTrial,
  measurementStudy,
  pedagogyConsensus,
  unvalidated,
}

final class Recommendation {
  Recommendation({
    required this.exerciseId,
    required this.contentVersion,
    required this.reviewStatus,
    required this.reasonKey,
    required this.priority,
    required this.confidence,
    required this.scope,
    required this.evidenceGrade,
    required List<Evidence> evidence,
    required Set<AnalysisQualityFlag> qualityFlags,
    required List<String> sourceIds,
    required List<String> limitations,
  }) : assert(exerciseId != ''),
       assert(contentVersion > 0),
       assert(priority >= 0),
       assert(confidence >= 0 && confidence <= 1),
       assert(sourceIds.isNotEmpty),
       evidence = List.unmodifiable(evidence),
       qualityFlags = Set.unmodifiable(qualityFlags),
       sourceIds = List.unmodifiable(sourceIds),
       limitations = List.unmodifiable(limitations);

  final String exerciseId;
  final int contentVersion;
  final ContentReviewStatus reviewStatus;
  final String reasonKey;
  final int priority;
  final double confidence;
  final ObservationScope scope;
  final RecommendationEvidenceGrade evidenceGrade;
  final List<Evidence> evidence;
  final Set<AnalysisQualityFlag> qualityFlags;
  final List<String> sourceIds;
  final List<String> limitations;
}
