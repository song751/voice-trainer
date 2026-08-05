import 'package:drift/drift.dart';

part 'app_database.g.dart';

class PracticeSessions extends Table {
  TextColumn get id => text()();
  TextColumn get templateJson => text()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get validFrameCount => integer()();
  IntColumn get totalFrameCount => integer()();
  TextColumn get qualityFlagsJson => text()();
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

@DriftDatabase(
  tables: [PracticeSessions, Recordings, AnalysisRuns, FeatureSeriesTable],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 1) await migrator.createAll();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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
    return query.map((row) => row.readTable(featureSeriesTable)).get();
  }
}
