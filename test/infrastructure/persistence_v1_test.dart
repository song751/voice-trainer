import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/infrastructure/persistence/codecs/feature_blob_codec.dart';
import 'package:voice_trainer/infrastructure/persistence/database/app_database.dart';

void main() {
  test(
    'v1 schema stores one packed feature BLOB and no audio column',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      const codec = FeatureBlobCodec();
      final payload = codec.encode(
        values: Float32List.fromList(<double>[220, 221]),
        validity: <bool>[true, true],
        samplePeriodMicros: 50000,
      );

      await database.saveSessionWithFeature(
        session: PracticeSessionsCompanion.insert(
          id: 'session-1',
          templateJson: '{"id":"target-note"}',
          startedAt: DateTime.utc(2026, 8, 4),
          validFrameCount: 2,
          totalFrameCount: 2,
          qualityFlagsJson: '[]',
        ),
        recording: RecordingsCompanion.insert(
          sessionId: 'session-1',
          locator: 'file://recording.wav',
          storageKind: 'file',
        ),
        run: AnalysisRunsCompanion.insert(
          sessionId: 'session-1',
          createdAt: DateTime.utc(2026, 8, 4),
          algorithmVersion: 'phase0-autocorrelation-v1',
        ),
        feature: FeatureSeriesTableCompanion.insert(
          runId: 0,
          kind: 'pitch_hz',
          frameCount: 2,
          codecVersion: 1,
          payload: payload,
          sha256: 'test-checksum',
        ),
      );

      final features = await database.featureColumnsForSession('session-1');
      expect(features, hasLength(1));
      expect(features.single.payload, payload);
      final columns = await database
          .customSelect('PRAGMA table_info(feature_series_table)')
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        isNot(contains('audio')),
      );
      expect(
        columns.map((row) => row.read<String>('name')),
        isNot(contains('pcm')),
      );
    },
  );

  test(
    'recording deletion is recoverable through a pending tombstone',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.practiceSessions)
          .insert(
            PracticeSessionsCompanion.insert(
              id: 'session-2',
              templateJson: '{}',
              startedAt: DateTime.utc(2026, 8, 4),
              validFrameCount: 0,
              totalFrameCount: 0,
              qualityFlagsJson: '[]',
            ),
          );
      await database
          .into(database.recordings)
          .insert(
            RecordingsCompanion.insert(
              sessionId: 'session-2',
              locator: 'opfs://recording.wav',
              storageKind: 'opfs',
            ),
          );

      await database.deleteRecordingWithTombstone('session-2');
      expect(
        (await database.select(database.recordings).getSingle()).pendingDelete,
        isTrue,
      );

      await database.finalizeRecordingDeletion('session-2');
      expect(await database.select(database.recordings).get(), isEmpty);
    },
  );

  test(
    'failed persistence transaction leaves no session or analysis rows',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await expectLater(
        database.saveSessionWithFeatures(
          session: PracticeSessionsCompanion.insert(
            id: 'session-rollback',
            templateJson: '{}',
            startedAt: DateTime.utc(2026, 8, 5),
            validFrameCount: 0,
            totalFrameCount: 0,
            qualityFlagsJson: '[]',
          ),
          recording: RecordingsCompanion.insert(
            sessionId: 'missing-parent',
            locator: 'file://missing.wav',
            storageKind: 'file',
          ),
          run: AnalysisRunsCompanion.insert(
            sessionId: 'session-rollback',
            createdAt: DateTime.utc(2026, 8, 5),
            algorithmVersion: 'test',
          ),
          metadata: FeatureSeriesMetadataCompanion.insert(
            runId: const Value(0),
            frameCount: 0,
            startSampleIndex: 0,
            samplePeriodSamples: 1,
            algorithmVersion: 'test',
          ),
          features: const <FeatureSeriesTableCompanion>[],
        ),
        throwsA(isA<Exception>()),
      );

      expect(await database.select(database.practiceSessions).get(), isEmpty);
      expect(await database.select(database.analysisRuns).get(), isEmpty);
      expect(
        await database.select(database.featureSeriesMetadata).get(),
        isEmpty,
      );
    },
  );
}
