import 'package:drift/drift.dart';

part 'phase0_database.g.dart';

@DataClassName('AnalysisRunRow')
class AnalysisRuns extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get sampleRate => integer()();
  IntColumn get frameRateMilliHz => integer()();
}

@DataClassName('FeatureSeriesRow')
class FeatureSeries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get runId => integer().references(AnalysisRuns, #id)();
  TextColumn get kind => text()();
  IntColumn get frameCount => integer()();
  IntColumn get codecVersion => integer()();
  BlobColumn get payload => blob()();
  TextColumn get sha256 => text()();
}

@DriftDatabase(tables: [AnalysisRuns, FeatureSeries])
class Phase0Database extends _$Phase0Database {
  Phase0Database(super.executor);

  @override
  int get schemaVersion => 1;

  Future<FeatureSeriesRow> replaceSpikeBlob({
    required int frameCount,
    required Uint8List payload,
    required String checksum,
  }) {
    return transaction(() async {
      await delete(featureSeries).go();
      await delete(analysisRuns).go();
      final runId = await into(analysisRuns).insert(
        AnalysisRunsCompanion.insert(
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          sampleRate: 48000,
          frameRateMilliHz: 20000,
        ),
      );
      final seriesId = await into(featureSeries).insert(
        FeatureSeriesCompanion.insert(
          runId: runId,
          kind: 'pitch_hz',
          frameCount: frameCount,
          codecVersion: 1,
          payload: payload,
          sha256: checksum,
        ),
      );
      return (select(
        featureSeries,
      )..where((row) => row.id.equals(seriesId))).getSingle();
    });
  }
}
