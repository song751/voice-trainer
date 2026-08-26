import 'dart:convert';

import '../../../core/domain/analysis/voice_comparison.dart';
import '../../../core/domain/analysis/voice_production_profile.dart';

final class VoiceComparisonJsonCodec {
  const VoiceComparisonJsonCodec();

  String encodePlan(VoiceComparisonPlan plan) => jsonEncode(_planMap(plan));

  VoiceComparisonPlan decodePlan(String encoded) {
    final data = jsonDecode(encoded) as Map<String, dynamic>;
    final version = (data['schemaVersion'] as num?)?.toInt();
    if (version != voiceComparisonSchemaVersion) {
      throw StateError('Unsupported voice-comparison schema: $version.');
    }
    final scope = data['scope'] as Map<String, dynamic>;
    return VoiceComparisonPlan(
      schemaVersion: version!,
      id: data['id'] as String,
      labelA: _decodeLabel(data['labelA'] as Map<String, dynamic>),
      labelB: _decodeLabel(data['labelB'] as Map<String, dynamic>),
      scope: VoiceProductionScope(
        protocolId: scope['protocolId'] as String,
        taskKind: VoiceProductionTaskKind.values.byName(
          scope['taskKind'] as String,
        ),
        pitchContextKey: scope['pitchContextKey'] as String,
        vowelIpa: scope['vowelIpa'] as String,
        loudnessConditionKey: scope['loudnessConditionKey'] as String,
        styleContextKey: scope['styleContextKey'] as String,
        captureProfileKey: scope['captureProfileKey'] as String,
        algorithmVersion: scope['algorithmVersion'] as String,
      ),
      updatedAt: DateTime.parse(data['updatedAt'] as String).toUtc(),
    );
  }

  String encodeTake(VoiceComparisonTakeContext context) => jsonEncode({
    'schemaVersion': voiceComparisonSchemaVersion,
    'side': context.side.name,
    'plan': _planMap(context.plan),
  });

  VoiceComparisonTakeContext decodeTake(String encoded) {
    final data = jsonDecode(encoded) as Map<String, dynamic>;
    if ((data['schemaVersion'] as num?)?.toInt() !=
        voiceComparisonSchemaVersion) {
      throw StateError('Unsupported voice-comparison take schema.');
    }
    return VoiceComparisonTakeContext(
      plan: decodePlan(jsonEncode(data['plan'])),
      side: VoiceComparisonSide.values.byName(data['side'] as String),
    );
  }

  Map<String, Object?> _planMap(VoiceComparisonPlan plan) => <String, Object?>{
    'schemaVersion': plan.schemaVersion,
    'id': plan.id,
    'labelA': _labelMap(plan.labelA),
    'labelB': _labelMap(plan.labelB),
    'scope': <String, Object?>{
      'protocolId': plan.scope.protocolId,
      'taskKind': plan.scope.taskKind.name,
      'pitchContextKey': plan.scope.pitchContextKey,
      'vowelIpa': plan.scope.vowelIpa,
      'loudnessConditionKey': plan.scope.loudnessConditionKey,
      'styleContextKey': plan.scope.styleContextKey,
      'captureProfileKey': plan.scope.captureProfileKey,
      'algorithmVersion': plan.scope.algorithmVersion,
    },
    'updatedAt': plan.updatedAt.toUtc().toIso8601String(),
  };

  Map<String, Object?> _labelMap(PedagogicalVoiceLabel label) =>
      <String, Object?>{
        'labelKey': label.labelKey,
        'vocabularyId': label.vocabularyId,
        'vocabularyVersion': label.vocabularyVersion,
        'source': label.source.name,
        'confidence': label.confidence,
        'referenceAnchorId': label.referenceAnchorId,
        'limitations': label.limitations,
      };

  PedagogicalVoiceLabel _decodeLabel(Map<String, dynamic> data) =>
      PedagogicalVoiceLabel(
        labelKey: data['labelKey'] as String,
        vocabularyId: data['vocabularyId'] as String,
        vocabularyVersion: data['vocabularyVersion'] as String,
        source: PedagogicalLabelSource.values.byName(data['source'] as String),
        confidence: (data['confidence'] as num?)?.toDouble(),
        referenceAnchorId: data['referenceAnchorId'] as String?,
        limitations: (data['limitations'] as List<dynamic>? ?? const [])
            .cast<String>(),
      );
}
