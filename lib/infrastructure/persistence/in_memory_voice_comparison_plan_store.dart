import '../../core/domain/analysis/voice_comparison.dart';
import '../../core/domain/persistence/voice_comparison_plan_store.dart';

final class InMemoryVoiceComparisonPlanStore
    implements VoiceComparisonPlanStore {
  VoiceComparisonPlan? _latest;

  @override
  Future<VoiceComparisonPlan?> loadLatestPlan() async => _latest;

  @override
  Future<void> savePlan(VoiceComparisonPlan plan) async {
    _latest = plan;
  }
}
