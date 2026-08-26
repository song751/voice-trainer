import '../../core/domain/persistence/session_repository.dart';
import '../../core/domain/persistence/recording_store.dart';

final class InMemorySessionRepository implements SessionRepository {
  InMemorySessionRepository({this.recordingStore});

  final Map<String, PracticeSessionRecord> _records =
      <String, PracticeSessionRecord>{};
  final RecordingStore? recordingStore;

  List<PracticeSessionRecord> get records =>
      List<PracticeSessionRecord>.unmodifiable(_records.values);

  @override
  Future<PracticeSessionRecord?> findById(String id) async => _records[id];

  @override
  Future<List<PracticeSessionRecord>> listRecent({int limit = 20}) async {
    if (limit <= 0) return const <PracticeSessionRecord>[];
    final records = _records.values.toList()
      ..sort((left, right) => right.startedAt.compareTo(left.startedAt));
    return List<PracticeSessionRecord>.unmodifiable(records.take(limit));
  }

  @override
  Future<void> save(PracticeSessionRecord record) async {
    _records[record.id] = record;
  }

  @override
  Future<void> delete(String id) async {
    await deleteRecording(id);
    _records.remove(id);
  }

  @override
  Future<void> deleteRecording(String id) async {
    final record = _records[id];
    final locator = record?.recording;
    if (record == null || locator == null) return;
    final store = recordingStore;
    if (store != null) await store.delete(locator);
    _records[id] = PracticeSessionRecord(
      id: record.id,
      template: record.template,
      startedAt: record.startedAt,
      checkIn: record.checkIn,
      summary: record.summary,
      features: record.features,
      voiceComparison: record.voiceComparison,
    );
  }
}
