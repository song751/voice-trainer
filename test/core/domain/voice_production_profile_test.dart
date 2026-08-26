import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_quality_flag.dart';
import 'package:voice_trainer/core/domain/analysis/voice_production_profile.dart';

void main() {
  group('VoiceProductionMeasurement', () {
    test('accepts acoustic output from a consumer microphone', () {
      final measurement = VoiceProductionMeasurement(
        metricId: 'spectral_centroid_hz',
        value: 1850,
        unit: VoiceMeasurementUnit.hertz,
        domain: VoiceMeasurementDomain.acousticOutput,
        modalities: const {VoiceMeasurementModality.consumerMicrophone},
        confidence: .72,
        windowStartSample: 48000,
        windowEndSample: 96000,
      );

      expect(measurement.isConsumerMicrophoneOnly, isTrue);
      expect(measurement.isPhysiologicalDomain, isFalse);
    });

    test('rejects contact evidence from a consumer microphone alone', () {
      expect(
        () => VoiceProductionMeasurement(
          metricId: 'contact_quotient',
          value: .5,
          unit: VoiceMeasurementUnit.ratio,
          domain: VoiceMeasurementDomain.vocalFoldContact,
          modalities: const {VoiceMeasurementModality.consumerMicrophone},
          confidence: .9,
          windowStartSample: 0,
          windowEndSample: 48000,
        ),
        throwsArgumentError,
      );
    });

    test('requires the matching lab modality for physiology', () {
      final contact = VoiceProductionMeasurement(
        metricId: 'egg_contact_quotient',
        value: .52,
        unit: VoiceMeasurementUnit.ratio,
        domain: VoiceMeasurementDomain.vocalFoldContact,
        modalities: const {VoiceMeasurementModality.electroglottography},
        confidence: .8,
        windowStartSample: 0,
        windowEndSample: 48000,
      );
      final muscle = VoiceProductionMeasurement(
        metricId: 'ta_activation_normalized',
        value: .61,
        unit: VoiceMeasurementUnit.normalizedScore,
        domain: VoiceMeasurementDomain.muscleActivity,
        modalities: const {VoiceMeasurementModality.electromyography},
        confidence: .7,
        windowStartSample: 0,
        windowEndSample: 48000,
      );

      expect(contact.isPhysiologicalDomain, isTrue);
      expect(muscle.isPhysiologicalDomain, isTrue);
    });
  });

  group('VoiceProductionProfile', () {
    test('keeps pedagogical labels as human annotations', () {
      final profile = VoiceProductionProfile(
        scope: _scope(),
        labels: [
          PedagogicalVoiceLabel(
            labelKey: 'strong_mix',
            vocabularyId: 'teacher-a-mix',
            vocabularyVersion: '1',
            source: PedagogicalLabelSource.singerIntent,
          ),
          PedagogicalVoiceLabel(
            labelKey: 'metallic',
            vocabularyId: 'cvt',
            vocabularyVersion: '2026-study',
            source: PedagogicalLabelSource.blindedListenerConsensus,
            confidence: .65,
            referenceAnchorId: 'metal-anchor-01',
            limitations: const ['loudness_not_calibrated'],
          ),
        ],
        measurements: [_acousticMeasurement()],
        confidence: const VoiceProductionConfidence(
          signalQuality: .9,
          taskMatch: .8,
          repeatability: .7,
          labelAgreement: .6,
        ),
        qualityFlags: const {},
      );

      expect(profile.labels.first.source, PedagogicalLabelSource.singerIntent);
      expect(profile.confidence.conservativeScore, .6);
      expect(
        PedagogicalLabelSource.values.map((source) => source.name),
        isNot(contains('algorithm')),
      );
    });

    test(
      'comparison scope includes task, vowel, loudness, style, and capture',
      () {
        final baseline = _scope();

        expect(baseline.isComparableWith(_scope()), isTrue);
        expect(baseline.isComparableWith(_scope(vowelIpa: 'i')), isFalse);
        expect(
          baseline.isComparableWith(
            _scope(loudnessConditionKey: 'comfortable_loud'),
          ),
          isFalse,
        );
        expect(
          baseline.isComparableWith(_scope(captureProfileKey: 'phone_near')),
          isFalse,
        );
        expect(
          baseline.isComparableWith(
            _scope(
              targetVocabularyId: 'teacher-b-mix',
              targetVocabularyVersion: '1',
              targetLabelKey: 'strong_mix',
            ),
          ),
          isFalse,
        );
        expect(() => _scope(targetLabelKey: 'strong_mix'), throwsArgumentError);
      },
    );

    test('collections are immutable and confidence validates components', () {
      final profile = VoiceProductionProfile(
        scope: _scope(),
        labels: const [],
        measurements: [_acousticMeasurement()],
        confidence: const VoiceProductionConfidence(
          signalQuality: .9,
          taskMatch: .8,
          repeatability: .7,
        ),
        qualityFlags: const {AnalysisQualityFlag.processingAdjusted},
      );

      expect(
        () => profile.measurements.add(_acousticMeasurement()),
        throwsUnsupportedError,
      );
      expect(profile.confidence.conservativeScore, .7);
      expect(
        () => VoiceProductionConfidence(
          signalQuality: 1.1,
          taskMatch: .8,
          repeatability: .7,
        ),
        throwsAssertionError,
      );
    });
  });
}

VoiceProductionScope _scope({
  String vowelIpa = 'a',
  String loudnessConditionKey = 'comfortable_medium',
  String captureProfileKey = 'same_device_same_distance',
  String? targetVocabularyId,
  String? targetVocabularyVersion,
  String? targetLabelKey,
}) => VoiceProductionScope(
  protocolId: 'register-contrast-v1',
  taskKind: VoiceProductionTaskKind.matchedPitchContrast,
  pitchContextKey: 'midi_64',
  vowelIpa: vowelIpa,
  loudnessConditionKey: loudnessConditionKey,
  styleContextKey: 'contemporary-neutral',
  captureProfileKey: captureProfileKey,
  algorithmVersion: 'research-v1',
  targetVocabularyId: targetVocabularyId,
  targetVocabularyVersion: targetVocabularyVersion,
  targetLabelKey: targetLabelKey,
);

VoiceProductionMeasurement _acousticMeasurement() => VoiceProductionMeasurement(
  metricId: 'relative_alpha_ratio_db',
  value: -8,
  unit: VoiceMeasurementUnit.decibels,
  domain: VoiceMeasurementDomain.acousticOutput,
  modalities: const {VoiceMeasurementModality.consumerMicrophone},
  confidence: .75,
  windowStartSample: 0,
  windowEndSample: 48000,
);
