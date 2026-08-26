import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:voice_trainer/app/default_persistence.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/analysis/feature_series.dart';
import 'package:voice_trainer/core/domain/analysis/session_summary.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/domain/persistence/recording_locator.dart';
import 'package:voice_trainer/core/domain/persistence/recording_sink.dart';
import 'package:voice_trainer/core/domain/persistence/recording_store.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';
import 'package:voice_trainer/infrastructure/persistence/database/app_database.dart';
import 'package:voice_trainer/infrastructure/persistence/recordings/native_recording_sink.dart';
import 'package:voice_trainer/infrastructure/persistence/recordings/recording_recovery_service.dart';
import 'package:voice_trainer/infrastructure/persistence/repositories/drift_session_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Android native adapters append, finalize, save, read, list, and delete',
    () async {
      const sessionId = 'p4-04-android-round-trip';
      final adapters = createDefaultPersistenceAdapters(
        PlatformCapabilities.android,
      );
      addTearDown(adapters.dispose);

      expect(adapters.usesNativePersistence, isTrue);
      await adapters.sessionRepository.delete(sessionId);
      await adapters.recordingSink.open(
        RecordingMetadata(
          sessionId: sessionId,
          startedAt: DateTime.utc(2026, 8, 26),
        ),
      );
      await adapters.recordingSink.append(_chunk());
      final locator = await adapters.recordingSink.finalize();
      expect(locator.storageKind, RecordingStorageKind.file);
      expect(await adapters.recordingStore.exists(locator), isTrue);

      await adapters.sessionRepository.save(
        _record(sessionId, recording: locator),
      );
      final restored = await adapters.sessionRepository.findById(sessionId);
      expect(restored, isNotNull);
      expect(restored!.features.frames.single.bandPowersDb, hasLength(8));
      expect(
        (await adapters.sessionRepository.listRecent()).map(
          (record) => record.id,
        ),
        contains(sessionId),
      );

      await adapters.sessionRepository.deleteRecording(sessionId);
      expect(await adapters.recordingStore.exists(locator), isFalse);
      expect(
        (await adapters.sessionRepository.findById(sessionId))!.recording,
        isNull,
      );
      await adapters.sessionRepository.delete(sessionId);
      expect(await adapters.sessionRepository.findById(sessionId), isNull);
    },
  );

  test('Android data survives closing and reopening native adapters', () async {
    const sessionId = 'p4-04-android-reopen';
    final first = createDefaultPersistenceAdapters(
      PlatformCapabilities.android,
    );
    await first.sessionRepository.delete(sessionId);
    await first.sessionRepository.save(_record(sessionId));
    await first.dispose();

    final reopened = createDefaultPersistenceAdapters(
      PlatformCapabilities.android,
    );
    addTearDown(reopened.dispose);
    expect(await reopened.sessionRepository.findById(sessionId), isNotNull);
    await reopened.sessionRepository.delete(sessionId);
  });

  test(
    'Android file-backed DB failure rolls back and tombstone recovers',
    () async {
      final root = await _freshTestRoot('failure-recovery');
      addTearDown(() => root.delete(recursive: true));
      final recordings = Directory(
        '${root.path}${Platform.pathSeparator}recordings',
      );
      await recordings.create(recursive: true);
      final recording = File(
        '${recordings.path}${Platform.pathSeparator}saved.wav',
      );
      await recording.writeAsBytes(<int>[1, 2, 3, 4], flush: true);
      final orphan = File(
        '${recordings.path}${Platform.pathSeparator}orphan.partial',
      );
      await orphan.writeAsBytes(<int>[1, 2], flush: true);
      final databaseFile = File(
        '${root.path}${Platform.pathSeparator}voice_trainer.sqlite',
      );
      final database = AppDatabase(NativeDatabase(databaseFile));

      await expectLater(
        database.saveSessionWithFeatures(
          session: PracticeSessionsCompanion.insert(
            id: 'p4-04-rollback',
            templateJson: '{}',
            startedAt: DateTime.utc(2026, 8, 26),
            validFrameCount: 0,
            totalFrameCount: 0,
            qualityFlagsJson: '[]',
          ),
          recording: RecordingsCompanion.insert(
            sessionId: 'missing-parent',
            locator: 'invalid-locator',
            storageKind: RecordingStorageKind.file.name,
          ),
          run: AnalysisRunsCompanion.insert(
            sessionId: 'p4-04-rollback',
            createdAt: DateTime.utc(2026, 8, 26),
            algorithmVersion: 'p4-04-test',
          ),
          metadata: FeatureSeriesMetadataCompanion.insert(
            runId: const Value(0),
            frameCount: 0,
            startSampleIndex: 0,
            samplePeriodSamples: 1,
            algorithmVersion: 'p4-04-test',
          ),
          features: const <FeatureSeriesTableCompanion>[],
        ),
        throwsA(isA<Exception>()),
      );
      expect(await database.select(database.practiceSessions).get(), isEmpty);

      await database
          .into(database.practiceSessions)
          .insert(
            PracticeSessionsCompanion.insert(
              id: 'p4-04-delete-retry',
              templateJson: '{}',
              startedAt: DateTime.utc(2026, 8, 26),
              validFrameCount: 0,
              totalFrameCount: 0,
              qualityFlagsJson: '[]',
            ),
          );
      await database
          .into(database.recordings)
          .insert(
            RecordingsCompanion.insert(
              sessionId: 'p4-04-delete-retry',
              locator: recording.path,
              storageKind: RecordingStorageKind.file.name,
            ),
          );
      final failingRepository = DriftSessionRepository(
        database,
        recordingStore: const _FailingRecordingStore(),
      );
      await expectLater(
        failingRepository.deleteRecording('p4-04-delete-retry'),
        throwsStateError,
      );
      expect(
        (await database.recordingForSession(
          'p4-04-delete-retry',
        ))!.pendingDelete,
        isTrue,
      );
      await database.close();

      final reopened = AppDatabase(NativeDatabase(databaseFile));
      addTearDown(reopened.close);
      await RecordingRecoveryService(
        database: reopened,
        store: NativeRecordingStore(recordings),
      ).recover();
      expect(await orphan.exists(), isFalse);
      expect(await recording.exists(), isFalse);
      expect(await reopened.recordingForSession('p4-04-delete-retry'), isNull);
    },
  );

  test('Android opens and upgrades a v1 file-backed schema fixture', () async {
    final root = await _freshTestRoot('v1-migration');
    addTearDown(() => root.delete(recursive: true));
    final databaseFile = File(
      '${root.path}${Platform.pathSeparator}legacy.sqlite',
    );
    _writeV1Fixture(databaseFile);

    final database = AppDatabase(NativeDatabase(databaseFile));
    addTearDown(database.close);
    final columns = await database
        .customSelect('PRAGMA table_info(practice_sessions)')
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      contains('summary_json'),
    );
    final metadataColumns = await database
        .customSelect('PRAGMA table_info(feature_series_metadata)')
        .get();
    expect(
      metadataColumns.map((row) => row.read<String>('name')),
      contains('feature_schema_version'),
    );

    final repository = DriftSessionRepository(
      database,
      recordingStore: NativeRecordingStore(
        Directory('${root.path}${Platform.pathSeparator}recordings'),
      ),
    );
    await repository.save(_record('p4-04-after-migration'));
    expect(await repository.findById('p4-04-after-migration'), isNotNull);
  });
}

Future<Directory> _freshTestRoot(String name) async {
  final support = await getApplicationSupportDirectory();
  final root = Directory(
    '${support.path}${Platform.pathSeparator}voice_trainer_p4_04_tests'
    '${Platform.pathSeparator}$name',
  );
  if (await root.exists()) await root.delete(recursive: true);
  await root.create(recursive: true);
  return root;
}

PcmChunk _chunk() => PcmChunk(
  sequenceNumber: 0,
  firstSampleIndex: 0,
  format: const CaptureFormat(sampleRate: 48000, channels: 1),
  bytes: Uint8List(960),
  captureMonotonicTime: Duration.zero,
);

PracticeSessionRecord _record(String id, {RecordingLocator? recording}) =>
    PracticeSessionRecord(
      id: id,
      template: const PracticeTemplate(
        id: 'p4-04-target-note',
        version: 1,
        kind: PracticeKind.targetNote,
        target: PracticeTarget(targetMidiNote: 57),
        reviewStatus: ContentReviewStatus.reviewed,
      ),
      startedAt: DateTime.utc(2026, 8, 26),
      summary: SessionSummary(
        validFrameCount: 1,
        totalFrameCount: 1,
        targetHitRate: 1,
        qualityFlags: const {},
      ),
      features: FeatureSeries(
        frameRateHz: 100,
        frames: <AnalysisFrame>[
          AnalysisFrame(
            sampleIndex: 0,
            rmsDbfs: -18,
            peakDbfs: -4,
            pitchClarity: .95,
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
            algorithmVersion: 'p4-04-test',
          ),
        ],
      ),
      recording: recording,
    );

void _writeV1Fixture(File file) {
  final database = sqlite.sqlite3.open(file.path);
  try {
    database.execute('''
      CREATE TABLE practice_sessions (
        id TEXT NOT NULL PRIMARY KEY,
        template_json TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        valid_frame_count INTEGER NOT NULL,
        total_frame_count INTEGER NOT NULL,
        quality_flags_json TEXT NOT NULL
      );
      CREATE TABLE recordings (
        session_id TEXT NOT NULL PRIMARY KEY REFERENCES practice_sessions(id),
        locator TEXT NOT NULL,
        storage_kind TEXT NOT NULL,
        pending_delete INTEGER NOT NULL DEFAULT 0
          CHECK (pending_delete IN (0, 1))
      );
      CREATE TABLE analysis_runs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL REFERENCES practice_sessions(id),
        created_at INTEGER NOT NULL,
        algorithm_version TEXT NOT NULL
      );
      CREATE TABLE feature_series (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        run_id INTEGER NOT NULL REFERENCES analysis_runs(id),
        kind TEXT NOT NULL,
        frame_count INTEGER NOT NULL,
        codec_version INTEGER NOT NULL,
        payload BLOB NOT NULL,
        sha256 TEXT NOT NULL
      );
      PRAGMA user_version = 1;
    ''');
  } finally {
    database.close();
  }
}

final class _FailingRecordingStore implements RecordingStore {
  const _FailingRecordingStore();

  @override
  Future<void> delete(RecordingLocator locator) =>
      Future<void>.error(StateError('Injected deletion failure.'));

  @override
  Future<bool> exists(RecordingLocator locator) async => true;
}
