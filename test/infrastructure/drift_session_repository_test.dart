import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_quality_flag.dart';
import 'package:voice_trainer/core/domain/analysis/feature_series.dart';
import 'package:voice_trainer/core/domain/analysis/session_summary.dart';
import 'package:voice_trainer/core/domain/persistence/recording_locator.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/infrastructure/persistence/database/app_database.dart';
import 'package:voice_trainer/infrastructure/persistence/repositories/drift_session_repository.dart';

void main() {
  test(
    'Drift repository preserves feature columns and sample timeline',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSessionRepository(database);
      final record = PracticeSessionRecord(
        id: 'session-round-trip',
        template: const PracticeTemplate(
          id: 'target-note',
          version: 3,
          kind: PracticeKind.sustainedNote,
          target: PracticeTarget(targetMidiNote: 57, toleranceCents: 18),
          reviewStatus: ContentReviewStatus.reviewed,
        ),
        startedAt: DateTime.utc(2026, 8, 5),
        summary: SessionSummary(
          validFrameCount: 1,
          totalFrameCount: 2,
          qualityFlags: {AnalysisQualityFlag.discontinuity},
        ),
        recording: const RecordingLocator(
          value: 'file:///voice-trainer/session-round-trip.wav',
          storageKind: RecordingStorageKind.file,
        ),
        features: FeatureSeries(
          frameRateHz: 100,
          frames: <AnalysisFrame>[
            AnalysisFrame(
              sampleIndex: 960,
              rmsDbfs: -24.5,
              peakDbfs: -5.25,
              pitchClarity: 0.875,
              voiced: true,
              f0Hz: 220.5,
              pitchCents: 5701.25,
              qualityFlags: const {AnalysisQualityFlag.processingAdjusted},
              algorithmVersion: 'phase0-autocorrelation-v1',
            ),
            AnalysisFrame(
              sampleIndex: 1440,
              rmsDbfs: -31.75,
              peakDbfs: -8.5,
              pitchClarity: 0.125,
              voiced: false,
              qualityFlags: const {AnalysisQualityFlag.inputTooLow},
              algorithmVersion: 'phase0-autocorrelation-v1',
            ),
          ],
        ),
      );

      await repository.save(record);
      final restored = await repository.findById(record.id);

      expect(restored, isNotNull);
      final frames = restored!.features.frames;
      expect(restored.features.frameRateHz, 100);
      expect(frames.map((frame) => frame.sampleIndex), <int>[960, 1440]);
      expect(frames.map((frame) => frame.rmsDbfs), <double>[-24.5, -31.75]);
      expect(frames.map((frame) => frame.peakDbfs), <double>[-5.25, -8.5]);
      expect(frames.map((frame) => frame.pitchClarity), <double>[0.875, 0.125]);
      expect(frames.first.f0Hz, 220.5);
      expect(frames.first.pitchCents, 5701.25);
      expect(frames.last.f0Hz, isNull);
      expect(frames.last.pitchCents, isNull);
      expect(frames.first.qualityFlags, {
        AnalysisQualityFlag.processingAdjusted,
      });
      expect(frames.last.qualityFlags, {AnalysisQualityFlag.inputTooLow});
    },
  );

  test('Drift repository rejects a feature BLOB with a bad checksum', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSessionRepository(database);
    final record = PracticeSessionRecord(
      id: 'checksum-session',
      template: const PracticeTemplate(
        id: 'target-note',
        version: 1,
        kind: PracticeKind.sustainedNote,
        target: PracticeTarget(targetMidiNote: 57),
        reviewStatus: ContentReviewStatus.reviewed,
      ),
      startedAt: DateTime.utc(2026),
      summary: SessionSummary(
        validFrameCount: 1,
        totalFrameCount: 1,
        qualityFlags: const {},
      ),
      features: FeatureSeries(
        frameRateHz: 100,
        frames: <AnalysisFrame>[
          AnalysisFrame(
            sampleIndex: 0,
            rmsDbfs: -10,
            peakDbfs: -2,
            pitchClarity: 1,
            voiced: true,
            f0Hz: 220,
            algorithmVersion: 'test',
          ),
        ],
      ),
    );
    await repository.save(record);
    await (database.update(database.featureSeriesTable)
          ..where((row) => row.kind.equals('rms_dbfs')))
        .write(const FeatureSeriesTableCompanion(sha256: Value('corrupt')));

    await expectLater(repository.findById(record.id), throwsStateError);
  });
}
