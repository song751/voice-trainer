import 'package:drift/drift.dart';

part 'app_database.g.dart';

class PracticeSessions extends Table {
  TextColumn get id => text()();
  TextColumn get templateJson => text()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get validFrameCount => integer()();
  IntColumn get totalFrameCount => integer()();
  TextColumn get qualityFlagsJson => text()();
  TextColumn get summaryJson => text().withDefault(const Constant('{}'))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Recordings extends Table {
  TextColumn get sessionId => text().references(PracticeSessions, #id)();
  TextColumn get locator => text()();
  TextColumn get storageKind => text()();
  BoolColumn get pendingDelete =>
      boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>> get primaryKey => {sessionId};
}

class AnalysisRuns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text().references(PracticeSessions, #id)();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get algorithmVersion => text()();
}

class FeatureSeriesTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get runId => integer().references(AnalysisRuns, #id)();
  TextColumn get kind => text()();
  IntColumn get frameCount => integer()();
  IntColumn get codecVersion => integer()();
  BlobColumn get payload => blob()();
  TextColumn get sha256 => text()();

  @override
  String get tableName => 'feature_series';
}

/// Describes the shared sample timeline for all packed feature columns in an
/// analysis run. The values are stored separately from column payloads so a
/// reader never has to invent time from a list position.
class FeatureSeriesMetadata extends Table {
  IntColumn get runId => integer().references(AnalysisRuns, #id)();
  IntColumn get frameCount => integer()();
  IntColumn get startSampleIndex => integer()();
  IntColumn get samplePeriodSamples => integer()();
  TextColumn get algorithmVersion => text()();
  IntColumn get featureSchemaVersion =>
      integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {runId};
}

@DriftDatabase(
  tables: [
    PracticeSessions,
    Recordings,
    AnalysisRuns,
    FeatureSeriesTable,
    FeatureSeriesMetadata,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 1) {
        await migrator.createAll();
      }
      if (from < 2) {
        await migrator.createTable(featureSeriesMetadata);
      }
      if (from < 3 &&
          !await _columnExists(
            featureSeriesMetadata.actualTableName,
            featureSeriesMetadata.featureSchemaVersion.name,
          )) {
        await migrator.addColumn(
          featureSeriesMetadata,
          featureSeriesMetadata.featureSchemaVersion,
        );
      }
      if (from < 4) {
        await migrator.addColumn(
          practiceSessions,
          practiceSessions.summaryJson,
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<bool> _columnExists(String table, String column) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    return columns.any((row) => row.read<String>('name') == column);
  }

  Future<void> saveSessionWithFeature({
    required PracticeSessionsCompanion session,
    RecordingsCompanion? recording,
    required AnalysisRunsCompanion run,
    required FeatureSeriesTableCompanion feature,
  }) => transaction(() async {
    await into(
      practiceSessions,
    ).insert(session, mode: InsertMode.insertOrReplace);
    if (recording != null) await into(recordings).insert(recording);
    final runId = await into(analysisRuns).insert(run);
    await into(
      featureSeriesTable,
    ).insert(feature.copyWith(runId: Value(runId)));
  });

  Future<void> saveSessionWithFeatures({
    required PracticeSessionsCompanion session,
    RecordingsCompanion? recording,
    required AnalysisRunsCompanion run,
    required FeatureSeriesMetadataCompanion metadata,
    required List<FeatureSeriesTableCompanion> features,
  }) => transaction(() async {
    await into(
      practiceSessions,
    ).insert(session, mode: InsertMode.insertOrReplace);
    if (recording != null) await into(recordings).insert(recording);
    final runId = await into(analysisRuns).insert(run);
    await into(
      featureSeriesMetadata,
    ).insert(metadata.copyWith(runId: Value(runId)));
    for (final feature in features) {
      await into(
        featureSeriesTable,
      ).insert(feature.copyWith(runId: Value(runId)));
    }
  });

  Future<void> deleteRecordingWithTombstone(String sessionId) =>
      transaction(() async {
        await (update(recordings)
              ..where((row) => row.sessionId.equals(sessionId)))
            .write(const RecordingsCompanion(pendingDelete: Value(true)));
      });

  Future<void> finalizeRecordingDeletion(String sessionId) =>
      transaction(() async {
        await (delete(
          recordings,
        )..where((row) => row.sessionId.equals(sessionId))).go();
      });

  Future<List<FeatureSeriesTableData>> featureColumnsForSession(
    String sessionId,
  ) {
    final query = select(featureSeriesTable).join([
      innerJoin(
        analysisRuns,
        analysisRuns.id.equalsExp(featureSeriesTable.runId),
      ),
    ])..where(analysisRuns.sessionId.equals(sessionId));
    query.orderBy([OrderingTerm.asc(featureSeriesTable.kind)]);
    return query.map((row) => row.readTable(featureSeriesTable)).get();
  }

  Future<FeatureSeriesMetadataData?> featureMetadataForSession(
    String sessionId,
  ) {
    final query = select(featureSeriesMetadata).join([
      innerJoin(
        analysisRuns,
        analysisRuns.id.equalsExp(featureSeriesMetadata.runId),
      ),
    ])..where(analysisRuns.sessionId.equals(sessionId));
    return query
        .map((row) => row.readTable(featureSeriesMetadata))
        .getSingleOrNull();
  }

  Future<List<Recording>> pendingRecordings() => (select(
    recordings,
  )..where((row) => row.pendingDelete.equals(true))).get();

  Future<Recording?> recordingForSession(String sessionId) => (select(
    recordings,
  )..where((row) => row.sessionId.equals(sessionId))).getSingleOrNull();

  Future<List<PracticeSession>> recentSessions({required int limit}) =>
      (select(practiceSessions)
            ..orderBy([(row) => OrderingTerm.desc(row.startedAt)])
            ..limit(limit))
          .get();

  Future<void> deleteSessionData(String sessionId) => transaction(() async {
    final runs = await (select(
      analysisRuns,
    )..where((row) => row.sessionId.equals(sessionId))).get();
    for (final run in runs) {
      await (delete(
        featureSeriesTable,
      )..where((row) => row.runId.equals(run.id))).go();
      await (delete(
        featureSeriesMetadata,
      )..where((row) => row.runId.equals(run.id))).go();
    }
    await (delete(
      analysisRuns,
    )..where((row) => row.sessionId.equals(sessionId))).go();
    await (delete(
      recordings,
    )..where((row) => row.sessionId.equals(sessionId))).go();
    await (delete(
      practiceSessions,
    )..where((row) => row.id.equals(sessionId))).go();
  });
}
