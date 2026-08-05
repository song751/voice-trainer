import '../../core/domain/persistence/session_repository.dart';

final class InMemorySessionRepository implements SessionRepository {
  final Map<String, PracticeSessionRecord> _records =
      <String, PracticeSessionRecord>{};

  List<PracticeSessionRecord> get records =>
      List<PracticeSessionRecord>.unmodifiable(_records.values);

  @override
  Future<PracticeSessionRecord?> findById(String id) async => _records[id];

  @override
  Future<void> save(PracticeSessionRecord record) async {
    _records[record.id] = record;
  }
}
