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

  /// Complete persisted identity used to prevent one plan id from grouping
  /// takes recorded under different human labels or matched conditions.
  bool hasSameSnapshotAs(VoiceComparisonPlan other) =>
      schemaVersion == other.schemaVersion &&
      id == other.id &&
      updatedAt.isAtSameMomentAs(other.updatedAt) &&
      _sameLabel(labelA, other.labelA) &&
      _sameLabel(labelB, other.labelB) &&
      scope.isComparableWith(other.scope);

  static bool _sameLabel(
    PedagogicalVoiceLabel left,
    PedagogicalVoiceLabel right,
  ) =>
      left.labelKey == right.labelKey &&
      left.vocabularyId == right.vocabularyId &&
      left.vocabularyVersion == right.vocabularyVersion &&
      left.source == right.source &&
      left.confidence == right.confidence &&
      left.referenceAnchorId == right.referenceAnchorId &&
      _sameStrings(left.limitations, right.limitations);

  static bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

/// Immutable snapshot attached to a take so later plan edits cannot rewrite it.
final class VoiceComparisonTakeContext {
  const VoiceComparisonTakeContext({required this.plan, required this.side});

  final VoiceComparisonPlan plan;
  final VoiceComparisonSide side;

  PedagogicalVoiceLabel get label => plan.labelFor(side);
}
