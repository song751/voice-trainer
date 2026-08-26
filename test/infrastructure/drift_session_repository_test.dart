import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_quality_flag.dart';
import 'package:voice_trainer/core/domain/analysis/feature_series.dart';
import 'package:voice_trainer/core/domain/analysis/session_summary.dart';
import 'package:voice_trainer/core/domain/persistence/recording_locator.dart';
import 'package:voice_trainer/core/domain/persistence/recording_store.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/infrastructure/persistence/database/app_database.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_recording_store.dart';
import 'package:voice_trainer/infrastructure/persistence/recordings/recording_recovery_service.dart';
import 'package:voice_trainer/infrastructure/persistence/repositories/drift_session_repository.dart';

void main() {
  test(
    'Drift repository preserves feature columns and sample timeline',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSessionRepository(
        database,
        recordingStore: InMemoryRecordingStore(),
      );
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

  test(
    'failed blob deletion leaves a tombstone for startup recovery',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.practiceSessions)
          .insert(
            PracticeSessionsCompanion.insert(
              id: 'delete-retry',
              templateJson: '{}',
              startedAt: DateTime.utc(2026, 8, 6),
              validFrameCount: 0,
              totalFrameCount: 0,
              qualityFlagsJson: '[]',
            ),
          );
      await database
          .into(database.recordings)
          .insert(
            RecordingsCompanion.insert(
              sessionId: 'delete-retry',
              locator: 'file:///voice-trainer/delete-retry.wav',
              storageKind: 'file',
            ),
          );
      final repository = DriftSessionRepository(
        database,
        recordingStore: const _FailingRecordingStore(),
      );

      await expectLater(
        repository.deleteRecording('delete-retry'),
        throwsStateError,
      );
      expect(
        (await database.recordingForSession('delete-retry'))!.pendingDelete,
        isTrue,
      );

      await RecordingRecoveryService(
        database: database,
        store: InMemoryRecordingStore(),
      ).recover();
      expect(await database.recordingForSession('delete-retry'), isNull);
    },
  );

  test('Drift repository rejects a feature BLOB with a bad checksum', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSessionRepository(
      database,
      recordingStore: InMemoryRecordingStore(),
    );
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

  test(
    'P2 bands, history lookup, and durable recording deletion round-trip',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = InMemoryRecordingStore();
      final repository = DriftSessionRepository(
        database,
        recordingStore: store,
      );
      const recording = RecordingLocator(
        value: 'file:///voice-trainer/p2-bands.wav',
        storageKind: RecordingStorageKind.file,
      );
      store.add(recording);
      final record = PracticeSessionRecord(
        id: 'p2-bands',
        template: const PracticeTemplate(
          id: 'target-note',
          version: 2,
          kind: PracticeKind.targetNote,
          target: PracticeTarget(targetMidiNote: 57),
          reviewStatus: ContentReviewStatus.reviewed,
        ),
        startedAt: DateTime.utc(2026, 8, 6),
        summary: SessionSummary(
          validFrameCount: 1,
          totalFrameCount: 1,
          droppedSamples: 480,
          targetHitRate: .75,
          targetDeviationMedianCents: -12.5,
          pitchStability: const StabilitySummary(
            median: 0,
            medianAbsoluteDeviation: 12.5,
            slopePerSecond: 1.2,
            frameCount: 1,
          ),
          qualityFlags: const {},
        ),
        recording: recording,
        features: FeatureSeries(
          frameRateHz: 100,
          frames: <AnalysisFrame>[
            AnalysisFrame(
              sampleIndex: 0,
              rmsDbfs: -18,
              peakDbfs: -4,
              pitchClarity: 0.92,
              voiced: true,
              f0Hz: 220,
              pitchCents: 5700,
              bandPowersDb: const <double>[
                -30,
                -31,
                -32,
                -33,
                -34,
                -35,
                -36,
                -37,
              ],
              algorithmVersion: 'p2-yin-v1',
            ),
          ],
        ),
      );

      await repository.save(record);
      expect((await repository.listRecent()).single.id, record.id);
      final restoredSummary = (await repository.findById(record.id))!.summary;
      expect(restoredSummary.targetHitRate, .75);
      expect(restoredSummary.targetDeviationMedianCents, -12.5);
      expect(restoredSummary.droppedSamples, 480);
      expect(restoredSummary.pitchStability!.medianAbsoluteDeviation, 12.5);
      expect(
        (await repository.findById(
          record.id,
        ))!.features.frames.single.bandPowersDb,
        record.features.frames.single.bandPowersDb,
      );

      await repository.deleteRecording(record.id);
      expect(await store.exists(recording), isFalse);
      expect((await repository.findById(record.id))!.recording, isNull);

      await repository.delete(record.id);
      expect(await repository.findById(record.id), isNull);
      expect(await database.select(database.analysisRuns).get(), isEmpty);
      expect(await database.select(database.featureSeriesTable).get(), isEmpty);
    },
  );
}

final class _FailingRecordingStore implements RecordingStore {
  const _FailingRecordingStore();

  @override
  Future<void> delete(RecordingLocator locator) =>
      Future<void>.error(StateError('Injected blob deletion failure.'));

  @override
  Future<bool> exists(RecordingLocator locator) async => false;
}
