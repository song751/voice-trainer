import '../../../core/domain/analysis/voice_comparison.dart';
import '../../../core/domain/persistence/voice_comparison_plan_store.dart';
import '../codecs/voice_comparison_json_codec.dart';
import '../database/app_database.dart';

final class DriftVoiceComparisonPlanStore implements VoiceComparisonPlanStore {
  const DriftVoiceComparisonPlanStore(
    this.database, {
    this.codec = const VoiceComparisonJsonCodec(),
  });

  final AppDatabase database;
  final VoiceComparisonJsonCodec codec;

  @override
  Future<VoiceComparisonPlan?> loadLatestPlan() async {
    final row = await database.latestVoiceComparisonPlan();
    if (row == null) return null;
    if (row.schemaVersion != voiceComparisonSchemaVersion) {
      throw StateError(
        'Unsupported saved voice-comparison schema: ${row.schemaVersion}.',
      );
    }
    return codec.decodePlan(row.payloadJson);
  }

  @override
  Future<void> savePlan(VoiceComparisonPlan plan) => database
      .into(database.savedVoiceComparisonPlans)
      .insertOnConflictUpdate(
        SavedVoiceComparisonPlansCompanion.insert(
          id: plan.id,
          schemaVersion: plan.schemaVersion,
          payloadJson: codec.encodePlan(plan),
          updatedAt: plan.updatedAt,
        ),
      );
}
