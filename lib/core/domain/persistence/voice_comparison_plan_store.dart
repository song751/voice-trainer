import '../analysis/voice_comparison.dart';

abstract interface class VoiceComparisonPlanStore {
  Future<void> savePlan(VoiceComparisonPlan plan);

  Future<VoiceComparisonPlan?> loadLatestPlan();
}
