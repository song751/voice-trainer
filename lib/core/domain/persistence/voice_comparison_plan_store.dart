import '../analysis/voice_comparison.dart';

final class VoiceComparisonPlanConflict implements Exception {
  const VoiceComparisonPlanConflict(this.planId);

  final String planId;
}

abstract interface class VoiceComparisonPlanStore {
  Future<void> savePlan(VoiceComparisonPlan plan);

  Future<VoiceComparisonPlan?> loadLatestPlan();
}
