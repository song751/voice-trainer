import 'voice_production_profile.dart';

const voiceComparisonSchemaVersion = 1;

enum VoiceIntentKey {
  neutral,
  chestVoice,
  headVoice,
  falsetto,
  weakMix,
  strongMix,
  metallic,
}

enum VoiceComparisonSide { a, b }

/// A saved exercise cell. Labels are human intentions, never algorithm output.
final class VoiceComparisonPlan {
  VoiceComparisonPlan({
    required this.id,
    required this.labelA,
    required this.labelB,
    required this.scope,
    required this.updatedAt,
    this.schemaVersion = voiceComparisonSchemaVersion,
  }) : assert(id.isNotEmpty),
       assert(schemaVersion == voiceComparisonSchemaVersion) {
    if (scope.targetLabelKey != null) {
      throw ArgumentError(
        'The matched acoustic cell must not contain an inferred target label.',
      );
    }
  }

  final int schemaVersion;
  final String id;
  final PedagogicalVoiceLabel labelA;
  final PedagogicalVoiceLabel labelB;
  final VoiceProductionScope scope;
  final DateTime updatedAt;

  PedagogicalVoiceLabel labelFor(VoiceComparisonSide side) =>
      side == VoiceComparisonSide.a ? labelA : labelB;
}

/// Immutable snapshot attached to a take so later plan edits cannot rewrite it.
final class VoiceComparisonTakeContext {
  const VoiceComparisonTakeContext({required this.plan, required this.side});

  final VoiceComparisonPlan plan;
  final VoiceComparisonSide side;

  PedagogicalVoiceLabel get label => plan.labelFor(side);
}
