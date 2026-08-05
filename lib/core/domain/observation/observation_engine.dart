import '../analysis/session_summary.dart';
import '../practice/practice_template.dart';
import 'observation.dart';
import 'recommendation.dart';

final class ObservationResult {
  ObservationResult({
    required List<Observation> observations,
    required List<Recommendation> recommendations,
  }) : observations = List.unmodifiable(observations),
       recommendations = List.unmodifiable(recommendations);

  final List<Observation> observations;
  final List<Recommendation> recommendations;
}

abstract interface class ObservationEngine {
  ObservationResult evaluate({
    required PracticeTemplate template,
    required SessionSummary summary,
  });
}
