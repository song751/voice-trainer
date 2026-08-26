import '../../core/domain/analysis/voice_comparison.dart';
import '../../core/domain/persistence/voice_comparison_plan_store.dart';

final class InMemoryVoiceComparisonPlanStore
    implements VoiceComparisonPlanStore {
  VoiceComparisonPlan? _latest;
  final Map<String, VoiceComparisonPlan> _plans =
      <String, VoiceComparisonPlan>{};

  @override
  Future<VoiceComparisonPlan?> loadLatestPlan() async => _latest;

  @override
  Future<void> savePlan(VoiceComparisonPlan plan) async {
    final existing = _plans[plan.id];
    if (existing != null) {
      if (!existing.hasSameSnapshotAs(plan)) {
        throw VoiceComparisonPlanConflict(plan.id);
      }
      return;
    }
    _plans[plan.id] = plan;
    _latest = plan;
  }
}
