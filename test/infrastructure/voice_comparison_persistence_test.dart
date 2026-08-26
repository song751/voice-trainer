import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/analysis/feature_series.dart';
import 'package:voice_trainer/core/domain/analysis/session_summary.dart';
import 'package:voice_trainer/core/domain/analysis/voice_comparison.dart';
import 'package:voice_trainer/core/domain/analysis/voice_production_profile.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/domain/persistence/voice_comparison_plan_store.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/infrastructure/persistence/database/app_database.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_recording_store.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_voice_comparison_plan_store.dart';
import 'package:voice_trainer/infrastructure/persistence/repositories/drift_session_repository.dart';
import 'package:voice_trainer/infrastructure/persistence/repositories/drift_voice_comparison_plan_store.dart';

void main() {
  test('plan and take context round-trip with schema version 1', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final plan = _plan();
    final planStore = DriftVoiceComparisonPlanStore(database);
    final sessionStore = DriftSessionRepository(
      database,
      recordingStore: InMemoryRecordingStore(),
    );

    await planStore.savePlan(plan);
    await sessionStore.save(_record(plan));

    final restoredPlan = await planStore.loadLatestPlan();
    final restored = await sessionStore.findById('take-a');
    expect(restoredPlan!.schemaVersion, voiceComparisonSchemaVersion);
    expect(restoredPlan.labelA.labelKey, VoiceIntentKey.chestVoice.name);
    expect(restored!.voiceComparison!.side, VoiceComparisonSide.a);
    expect(restored.voiceComparison!.plan.scope.vowelIpa, 'a');
    expect(
      restored.voiceComparison!.label.source,
      PedagogicalLabelSource.singerIntent,
    );
  });

  test('legacy session without comparison metadata remains readable', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSessionRepository(
      database,
      recordingStore: InMemoryRecordingStore(),
    );
    final record = _record(null);
    await repository.save(record);

    expect((await repository.findById(record.id))!.voiceComparison, isNull);
  });

  test(
    'Drift plan store is idempotent but rejects a conflicting snapshot',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = DriftVoiceComparisonPlanStore(database);
      final original = _plan();

      await store.savePlan(original);
      await store.savePlan(original);
      await expectLater(
        store.savePlan(_plan(labelB: VoiceIntentKey.falsetto)),
        throwsA(isA<VoiceComparisonPlanConflict>()),
      );

      expect(
        (await store.loadLatestPlan())!.labelB.labelKey,
        VoiceIntentKey.headVoice.name,
      );
    },
  );

  test(
    'in-memory plan store preserves the original conflicting snapshot',
    () async {
      final store = InMemoryVoiceComparisonPlanStore();
      final original = _plan();

      await store.savePlan(original);
      await store.savePlan(_plan(id: 'plan-2'));
      await expectLater(
        store.savePlan(_plan(labelB: VoiceIntentKey.strongMix)),
        throwsA(isA<VoiceComparisonPlanConflict>()),
      );

      expect(
        (await store.loadLatestPlan())!.labelB.labelKey,
        VoiceIntentKey.headVoice.name,
      );
      expect((await store.loadLatestPlan())!.id, 'plan-2');
    },
  );

  test('schema v4 migrates without rewriting an existing session', () async {
    final directory = await Directory.systemTemp.createTemp(
      'voice-comparison-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}legacy.db');
    final legacy = sqlite.sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE practice_sessions (
        id TEXT NOT NULL PRIMARY KEY
      );
      CREATE TABLE recordings (
        session_id TEXT NOT NULL PRIMARY KEY,
        locator TEXT NOT NULL,
        storage_kind TEXT NOT NULL,
        pending_delete INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE feature_series_metadata (
        run_id INTEGER NOT NULL PRIMARY KEY,
        frame_count INTEGER NOT NULL,
        start_sample_index INTEGER NOT NULL,
        sample_period_samples INTEGER NOT NULL,
        algorithm_version TEXT NOT NULL,
        feature_schema_version INTEGER NOT NULL DEFAULT 1
      );
      INSERT INTO practice_sessions (id) VALUES ('legacy-session');
      INSERT INTO recordings (
        session_id, locator, storage_kind, pending_delete
      ) VALUES ('legacy-session', 'legacy.wav', 'file', 0);
      INSERT INTO feature_series_metadata (
        run_id, frame_count, start_sample_index, sample_period_samples,
        algorithm_version, feature_schema_version
      ) VALUES (1, 0, 0, 480, 'legacy-v4', 1);
      PRAGMA user_version = 4;
    ''');
    legacy.close();

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);
    final migrated = await database
        .customSelect('SELECT id, voice_comparison_json FROM practice_sessions')
        .getSingle();
    final planTable = await database
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table' AND name = 'saved_voice_comparison_plans'",
        )
        .getSingleOrNull();
    final legacyRecording = await database
        .customSelect(
          'SELECT content_sha256, content_byte_length FROM recordings',
        )
        .getSingle();
    final legacyFeatures = await database
        .customSelect(
          'SELECT source_audio_sha256, source_audio_byte_length '
          'FROM feature_series_metadata',
        )
        .getSingle();

    expect(migrated.read<String>('id'), 'legacy-session');
    expect(migrated.data['voice_comparison_json'], isNull);
    expect(planTable?.read<String>('name'), 'saved_voice_comparison_plans');
    expect(legacyRecording.data['content_sha256'], isNull);
    expect(legacyRecording.data['content_byte_length'], isNull);
    expect(legacyFeatures.data['source_audio_sha256'], isNull);
    expect(legacyFeatures.data['source_audio_byte_length'], isNull);
  });

  test(
    'real schema v5 migrates legacy identity to NULL and keeps v3 timelines',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'content-identity-v5-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}legacy.db');
      final legacy = sqlite.sqlite3.open(file.path);
      legacy.execute('''
        CREATE TABLE practice_sessions (
          id TEXT NOT NULL PRIMARY KEY,
          template_json TEXT NOT NULL,
          started_at INTEGER NOT NULL,
          valid_frame_count INTEGER NOT NULL,
          total_frame_count INTEGER NOT NULL,
          quality_flags_json TEXT NOT NULL,
          summary_json TEXT NOT NULL DEFAULT '{}',
          voice_comparison_json TEXT NULL
        );
        CREATE TABLE recordings (
          session_id TEXT NOT NULL PRIMARY KEY REFERENCES practice_sessions(id),
          locator TEXT NOT NULL,
          storage_kind TEXT NOT NULL,
          pending_delete INTEGER NOT NULL DEFAULT 0 CHECK (pending_delete IN (0, 1))
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
        CREATE TABLE feature_series_metadata (
          run_id INTEGER NOT NULL PRIMARY KEY REFERENCES analysis_runs(id),
          frame_count INTEGER NOT NULL,
          start_sample_index INTEGER NOT NULL,
          sample_period_samples INTEGER NOT NULL,
          algorithm_version TEXT NOT NULL,
          feature_schema_version INTEGER NOT NULL DEFAULT 1
        );
        CREATE TABLE saved_voice_comparison_plans (
          id TEXT NOT NULL PRIMARY KEY,
          schema_version INTEGER NOT NULL,
          payload_json TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        );
        INSERT INTO practice_sessions VALUES (
          'legacy-v5', '{}', 0, 0, 0, '[]', '{}', NULL
        );
        INSERT INTO recordings VALUES ('legacy-v5', 'legacy.wav', 'file', 0);
        INSERT INTO analysis_runs (
          id, session_id, created_at, algorithm_version
        ) VALUES (1, 'legacy-v5', 0, 'p3-stream-v1');
        INSERT INTO feature_series_metadata VALUES (
          1, 0, 0, 480, 'p3-stream-v1', 3
        );
        PRAGMA user_version = 5;
      ''');
      legacy.close();

      final database = AppDatabase(NativeDatabase(file));
      addTearDown(database.close);
      final legacyRecording = await database
          .customSelect(
            'SELECT content_sha256, content_byte_length FROM recordings '
            "WHERE session_id = 'legacy-v5'",
          )
          .getSingle();
      final legacyFeatures = await database
          .customSelect(
            'SELECT source_audio_sha256, source_audio_byte_length '
            'FROM feature_series_metadata WHERE run_id = 1',
          )
          .getSingle();
      expect(legacyRecording.data['content_sha256'], isNull);
      expect(legacyRecording.data['content_byte_length'], isNull);
      expect(legacyFeatures.data['source_audio_sha256'], isNull);
      expect(legacyFeatures.data['source_audio_byte_length'], isNull);

      final repository = DriftSessionRepository(
        database,
        recordingStore: InMemoryRecordingStore(),
      );
      const indices = <int>[48000000123, 48000000603, 48000003003];
      final migratedRecord = _record(null).copyWithForMigrationTest(indices);
      await repository.save(migratedRecord);
      final metadata = await database.featureMetadataForSession(
        migratedRecord.id,
      );
      final columns = await database.featureColumnsForSession(
        migratedRecord.id,
      );
      final restored = await repository.findById(migratedRecord.id);
      expect(metadata!.featureSchemaVersion, 3);
      expect(
        columns.where((column) => column.kind == 'sample_index_u64'),
        hasLength(1),
      );
      expect(
        restored!.features.frames.map((frame) => frame.sampleIndex),
        indices,
      );
    },
  );
}

VoiceComparisonPlan _plan({
  String id = 'plan-1',
  VoiceIntentKey labelB = VoiceIntentKey.headVoice,
}) => VoiceComparisonPlan(
  id: id,
  labelA: PedagogicalVoiceLabel(
    labelKey: VoiceIntentKey.chestVoice.name,
    vocabularyId: 'personal',
    vocabularyVersion: '1',
    source: PedagogicalLabelSource.singerIntent,
  ),
  labelB: PedagogicalVoiceLabel(
    labelKey: labelB.name,
    vocabularyId: 'personal',
    vocabularyVersion: '1',
    source: PedagogicalLabelSource.singerIntent,
  ),
  scope: VoiceProductionScope(
    protocolId: 'VP-REG-01@1',
    taskKind: VoiceProductionTaskKind.matchedPitchContrast,
    pitchContextKey: 'A3',
    vowelIpa: 'a',
    loudnessConditionKey: 'medium',
    styleContextKey: 'neutral',
    captureProfileKey: 'same-device-15cm',
    algorithmVersion: 'realtime-analysis-v1',
  ),
  updatedAt: DateTime.utc(2026, 8, 27),
);

PracticeSessionRecord _record(VoiceComparisonPlan? plan) =>
    PracticeSessionRecord(
      id: plan == null ? 'legacy-take' : 'take-a',
      template: const PracticeTemplate(
        id: 'target-a3',
        version: 1,
        kind: PracticeKind.targetNote,
        target: PracticeTarget(targetMidiNote: 57),
        reviewStatus: ContentReviewStatus.draft,
      ),
      startedAt: DateTime.utc(2026, 8, 27),
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
            rmsDbfs: -20,
            peakDbfs: -4,
            pitchClarity: .9,
            voiced: true,
            f0Hz: 220,
            pitchCents: 5700,
            bandPowersDb: const <double>[
              -30,
              -31,
              -32,
              -33,
              -24,
              -35,
              -36,
              -37,
            ],
            algorithmVersion: 'realtime-analysis-v1',
          ),
        ],
      ),
      voiceComparison: plan == null
          ? null
          : VoiceComparisonTakeContext(plan: plan, side: VoiceComparisonSide.a),
    );

extension on PracticeSessionRecord {
  PracticeSessionRecord copyWithForMigrationTest(List<int> sampleIndices) =>
      PracticeSessionRecord(
        id: 'post-v5-irregular',
        template: template,
        startedAt: startedAt,
        summary: SessionSummary(
          validFrameCount: sampleIndices.length,
          totalFrameCount: sampleIndices.length,
          qualityFlags: const {},
        ),
        features: FeatureSeries(
          frameRateHz: 100,
          frames: List<AnalysisFrame>.generate(
            sampleIndices.length,
            (index) => AnalysisFrame(
              sampleIndex: sampleIndices[index],
              rmsDbfs: -20,
              peakDbfs: -4,
              pitchClarity: .9,
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
              algorithmVersion: 'p3-stream-v1',
            ),
          ),
        ),
      );
}
