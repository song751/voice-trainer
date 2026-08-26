import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/domain/analysis/voice_comparison.dart';
import '../../../core/domain/analysis/voice_production_profile.dart';
import 'voice_comparison_evidence.dart';
import 'active_voice_comparison_take.dart';

final voiceComparisonControllerProvider =
    AsyncNotifierProvider<VoiceComparisonController, VoiceComparisonPlan?>(
      VoiceComparisonController.new,
    );

final voiceComparisonEvidenceProvider = FutureProvider.autoDispose
    .family<VoiceComparisonEvidence, VoiceComparisonPlan>((ref, plan) async {
      final records = await ref
          .watch(sessionRepositoryProvider)
          .listRecent(limit: 100);
      return buildVoiceComparisonEvidence(plan: plan, records: records);
    });

final class VoiceComparisonDraft {
  const VoiceComparisonDraft({
    required this.labelA,
    required this.labelB,
    required this.vocabularyId,
    required this.vocabularyVersion,
    required this.source,
    required this.protocolId,
    required this.pitchContextKey,
    required this.vowelIpa,
    required this.loudnessConditionKey,
    required this.styleContextKey,
    required this.captureProfileKey,
  });

  final VoiceIntentKey labelA;
  final VoiceIntentKey labelB;
  final String vocabularyId;
  final String vocabularyVersion;
  final PedagogicalLabelSource source;
  final String protocolId;
  final String pitchContextKey;
  final String vowelIpa;
  final String loudnessConditionKey;
  final String styleContextKey;
  final String captureProfileKey;
}

final class VoiceComparisonController
    extends AsyncNotifier<VoiceComparisonPlan?> {
  @override
  Future<VoiceComparisonPlan?> build() =>
      ref.watch(voiceComparisonPlanStoreProvider).loadLatestPlan();

  Future<VoiceComparisonPlan> save(VoiceComparisonDraft draft) async {
    final vocabularyId = draft.vocabularyId.trim();
    final vocabularyVersion = draft.vocabularyVersion.trim();
    if (vocabularyId.isEmpty || vocabularyVersion.isEmpty) {
      throw ArgumentError('Vocabulary id and version are required.');
    }
    final now = DateTime.now().toUtc();
    final plan = VoiceComparisonPlan(
      id: 'voice-comparison-${now.microsecondsSinceEpoch}',
      labelA: _label(
        draft.labelA,
        vocabularyId,
        vocabularyVersion,
        draft.source,
      ),
      labelB: _label(
        draft.labelB,
        vocabularyId,
        vocabularyVersion,
        draft.source,
      ),
      scope: VoiceProductionScope(
        protocolId: draft.protocolId,
        taskKind: VoiceProductionTaskKind.matchedPitchContrast,
        pitchContextKey: draft.pitchContextKey,
        vowelIpa: draft.vowelIpa,
        loudnessConditionKey: draft.loudnessConditionKey,
        styleContextKey: draft.styleContextKey,
        captureProfileKey: draft.captureProfileKey,
        algorithmVersion: 'realtime-analysis-v1',
      ),
      updatedAt: now,
    );
    await ref.read(voiceComparisonPlanStoreProvider).savePlan(plan);
    ref.read(activeVoiceComparisonTakeProvider.notifier).state = null;
    state = AsyncData(plan);
    return plan;
  }

  void prepareTake(VoiceComparisonSide side) {
    final plan = state.valueOrNull;
    if (plan == null) {
      throw StateError('Save a comparison plan before recording.');
    }
    ref.read(activeVoiceComparisonTakeProvider.notifier).state =
        VoiceComparisonTakeContext(plan: plan, side: side);
  }

  PedagogicalVoiceLabel _label(
    VoiceIntentKey intent,
    String vocabularyId,
    String vocabularyVersion,
    PedagogicalLabelSource source,
  ) => PedagogicalVoiceLabel(
    labelKey: intent.name,
    vocabularyId: vocabularyId,
    vocabularyVersion: vocabularyVersion,
    source: source,
    limitations: const <String>[
      'human_intent_not_algorithm_classification',
      'consumer_microphone_acoustic_output_only',
    ],
  );
}
