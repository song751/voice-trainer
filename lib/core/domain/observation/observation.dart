import '../analysis/analysis_quality_flag.dart';
import 'evidence.dart';

enum ObservationScope { frame, segment, session, trend }

final class Observation {
  Observation({
    required this.ruleId,
    required this.ruleVersion,
    required this.scope,
    required this.labelKey,
    required List<Evidence> evidence,
    required this.confidence,
    required Set<AnalysisQualityFlag> qualityFlags,
    required this.basis,
    List<String> recommendationIds = const <String>[],
    this.suppressedReasonKey,
  }) : assert(ruleId != ''),
       assert(ruleVersion > 0),
       assert(confidence >= 0 && confidence <= 1),
       evidence = List.unmodifiable(evidence),
       qualityFlags = Set.unmodifiable(qualityFlags),
       recommendationIds = List.unmodifiable(recommendationIds);

  final String ruleId;
  final int ruleVersion;
  final ObservationScope scope;
  final String labelKey;
  final List<Evidence> evidence;
  final double confidence;
  final Set<AnalysisQualityFlag> qualityFlags;
  final EvidenceBasis basis;
  final List<String> recommendationIds;
  final String? suppressedReasonKey;
}
