import 'analysis_quality_flag.dart';

/// A task protocol, not a claim about the singer's laryngeal mechanism.
enum VoiceProductionTaskKind {
  matchedPitchContrast,
  ascendingGlide,
  descendingGlide,
  matchedPhrase,
  perceptualContrast,
}

/// Human provenance for pedagogical or perceptual vocabulary.
///
/// There is deliberately no algorithmic-classification value. Terms such as
/// head voice, falsetto, strong/weak mix, and metallic are annotations whose
/// meaning depends on the singer, teacher, listening panel, task, and style.
enum PedagogicalLabelSource {
  singerIntent,
  teacherPrompt,
  blindedListenerConsensus,
}

final class PedagogicalVoiceLabel {
  PedagogicalVoiceLabel({
    required this.labelKey,
    required this.vocabularyId,
    required this.vocabularyVersion,
    required this.source,
    this.confidence,
    this.referenceAnchorId,
    List<String> limitations = const [],
  }) : assert(labelKey != ''),
       assert(vocabularyId != ''),
       assert(vocabularyVersion != ''),
       assert(confidence == null || (confidence >= 0 && confidence <= 1)),
       limitations = List.unmodifiable(limitations);

  final String labelKey;
  final String vocabularyId;
  final String vocabularyVersion;
  final PedagogicalLabelSource source;

  /// Agreement or annotation confidence, not classifier probability.
  final double? confidence;
  final String? referenceAnchorId;
  final List<String> limitations;
}

enum VoiceMeasurementDomain {
  acousticOutput,
  perceptualRating,
  selfReport,
  vocalFoldContact,
  vocalFoldKinematics,
  muscleActivity,
  aerodynamics,
}

enum VoiceMeasurementModality {
  consumerMicrophone,
  calibratedMicrophone,
  listenerPanel,
  selfReport,
  electroglottography,
  highSpeedVideoendoscopy,
  electromyography,
  airflow,
  subglottalPressure,
}

enum VoiceMeasurementUnit {
  hertz,
  cents,
  dbfs,
  decibels,
  ratio,
  percent,
  milliseconds,
  normalizedScore,
  unitless,
}

/// One measured value with enough provenance to prevent acoustic output from
/// masquerading as vocal-fold contact, muscle activity, or aerodynamics.
final class VoiceProductionMeasurement {
  VoiceProductionMeasurement({
    required this.metricId,
    required this.value,
    required this.unit,
    required this.domain,
    required Set<VoiceMeasurementModality> modalities,
    required this.confidence,
    required this.windowStartSample,
    required this.windowEndSample,
  }) : assert(metricId != ''),
       assert(confidence >= 0 && confidence <= 1),
       assert(windowStartSample >= 0),
       assert(windowEndSample > windowStartSample),
       modalities = Set.unmodifiable(modalities) {
    if (!_hasRequiredModality(domain, modalities)) {
      throw ArgumentError.value(
        modalities,
        'modalities',
        'Measurement modality cannot support the declared domain.',
      );
    }
  }

  final String metricId;
  final double value;
  final VoiceMeasurementUnit unit;
  final VoiceMeasurementDomain domain;
  final Set<VoiceMeasurementModality> modalities;

  /// Measurement confidence after signal/task gates, not diagnostic accuracy.
  final double confidence;
  final int windowStartSample;
  final int windowEndSample;

  bool get isConsumerMicrophoneOnly =>
      modalities.length == 1 &&
      modalities.contains(VoiceMeasurementModality.consumerMicrophone);

  bool get isPhysiologicalDomain => switch (domain) {
    VoiceMeasurementDomain.vocalFoldContact ||
    VoiceMeasurementDomain.vocalFoldKinematics ||
    VoiceMeasurementDomain.muscleActivity ||
    VoiceMeasurementDomain.aerodynamics => true,
    VoiceMeasurementDomain.acousticOutput ||
    VoiceMeasurementDomain.perceptualRating ||
    VoiceMeasurementDomain.selfReport => false,
  };

  static bool _hasRequiredModality(
    VoiceMeasurementDomain domain,
    Set<VoiceMeasurementModality> modalities,
  ) => switch (domain) {
    VoiceMeasurementDomain.acousticOutput =>
      modalities.contains(VoiceMeasurementModality.consumerMicrophone) ||
          modalities.contains(VoiceMeasurementModality.calibratedMicrophone),
    VoiceMeasurementDomain.perceptualRating => modalities.contains(
      VoiceMeasurementModality.listenerPanel,
    ),
    VoiceMeasurementDomain.selfReport => modalities.contains(
      VoiceMeasurementModality.selfReport,
    ),
    VoiceMeasurementDomain.vocalFoldContact =>
      modalities.contains(VoiceMeasurementModality.electroglottography) ||
          modalities.contains(VoiceMeasurementModality.highSpeedVideoendoscopy),
    VoiceMeasurementDomain.vocalFoldKinematics => modalities.contains(
      VoiceMeasurementModality.highSpeedVideoendoscopy,
    ),
    VoiceMeasurementDomain.muscleActivity => modalities.contains(
      VoiceMeasurementModality.electromyography,
    ),
    VoiceMeasurementDomain.aerodynamics =>
      modalities.contains(VoiceMeasurementModality.airflow) ||
          modalities.contains(VoiceMeasurementModality.subglottalPressure),
  };
}

/// Exact comparison cell for a voice-production profile.
///
/// Population thresholds and pitch-only register boundaries are intentionally
/// absent. A personal baseline is comparable only when every confound encoded
/// here matches.
final class VoiceProductionScope {
  VoiceProductionScope({
    required this.protocolId,
    required this.taskKind,
    required this.pitchContextKey,
    required this.vowelIpa,
    required this.loudnessConditionKey,
    required this.styleContextKey,
    required this.captureProfileKey,
    required this.algorithmVersion,
    this.targetVocabularyId,
    this.targetVocabularyVersion,
    this.targetLabelKey,
  }) {
    if (<String>[
      protocolId,
      pitchContextKey,
      vowelIpa,
      loudnessConditionKey,
      styleContextKey,
      captureProfileKey,
      algorithmVersion,
    ].any((value) => value.isEmpty)) {
      throw ArgumentError('Voice-production scope keys must not be empty.');
    }
    final targetFields = <String?>[
      targetVocabularyId,
      targetVocabularyVersion,
      targetLabelKey,
    ];
    if (targetFields.any((value) => value == '') ||
        (targetFields.any((value) => value != null) &&
            targetFields.any((value) => value == null))) {
      throw ArgumentError(
        'Target vocabulary id, version, and label must be all set or all null.',
      );
    }
  }

  final String protocolId;
  final VoiceProductionTaskKind taskKind;
  final String pitchContextKey;
  final String vowelIpa;
  final String loudnessConditionKey;
  final String styleContextKey;
  final String captureProfileKey;
  final String algorithmVersion;
  final String? targetVocabularyId;
  final String? targetVocabularyVersion;
  final String? targetLabelKey;

  bool isComparableWith(VoiceProductionScope other) =>
      protocolId == other.protocolId &&
      taskKind == other.taskKind &&
      pitchContextKey == other.pitchContextKey &&
      vowelIpa == other.vowelIpa &&
      loudnessConditionKey == other.loudnessConditionKey &&
      styleContextKey == other.styleContextKey &&
      captureProfileKey == other.captureProfileKey &&
      algorithmVersion == other.algorithmVersion &&
      targetVocabularyId == other.targetVocabularyId &&
      targetVocabularyVersion == other.targetVocabularyVersion &&
      targetLabelKey == other.targetLabelKey;
}

/// Transparent confidence components for one profile.
///
/// The conservative score is the weakest available component. It is a data
/// quality summary, never the probability that a pedagogical label is true.
final class VoiceProductionConfidence {
  const VoiceProductionConfidence({
    required this.signalQuality,
    required this.taskMatch,
    required this.repeatability,
    this.labelAgreement,
  }) : assert(signalQuality >= 0 && signalQuality <= 1),
       assert(taskMatch >= 0 && taskMatch <= 1),
       assert(repeatability >= 0 && repeatability <= 1),
       assert(
         labelAgreement == null || (labelAgreement >= 0 && labelAgreement <= 1),
       );

  final double signalQuality;
  final double taskMatch;
  final double repeatability;
  final double? labelAgreement;

  double get conservativeScore {
    var result = signalQuality;
    if (taskMatch < result) result = taskMatch;
    if (repeatability < result) result = repeatability;
    final agreement = labelAgreement;
    if (agreement != null && agreement < result) result = agreement;
    return result;
  }
}

/// Multidimensional evidence collected under one explicit task scope.
///
/// Labels and measurements remain separate by construction. This model has no
/// field for an automatically inferred register, mix type, or metallic mode.
final class VoiceProductionProfile {
  VoiceProductionProfile({
    required this.scope,
    required List<PedagogicalVoiceLabel> labels,
    required List<VoiceProductionMeasurement> measurements,
    required this.confidence,
    required Set<AnalysisQualityFlag> qualityFlags,
  }) : labels = List.unmodifiable(labels),
       measurements = List.unmodifiable(measurements),
       qualityFlags = Set.unmodifiable(qualityFlags) {
    if (measurements.isEmpty) {
      throw ArgumentError.value(
        measurements,
        'measurements',
        'A voice-production profile requires measured evidence.',
      );
    }
  }

  final VoiceProductionScope scope;
  final List<PedagogicalVoiceLabel> labels;
  final List<VoiceProductionMeasurement> measurements;
  final VoiceProductionConfidence confidence;
  final Set<AnalysisQualityFlag> qualityFlags;
}
