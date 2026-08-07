import '../core/domain/persistence/recording_sink.dart';
import '../core/domain/persistence/recording_store.dart';
import '../core/domain/persistence/session_repository.dart';
import '../infrastructure/persistence/in_memory_recording_store.dart';
import '../infrastructure/persistence/in_memory_session_repository.dart';

final class DefaultPersistenceAdapters {
  const DefaultPersistenceAdapters({
    required this.recordingStore,
    required this.recordingSink,
    required this.sessionRepository,
    required this.usesNativePersistence,
  });

  final RecordingStore recordingStore;
  final RecordingSink recordingSink;
  final SessionRepository sessionRepository;
  final bool usesNativePersistence;

  Future<void> dispose() async {}
}

DefaultPersistenceAdapters createDefaultPersistenceAdapters() {
  final store = InMemoryRecordingStore();
  return DefaultPersistenceAdapters(
    recordingStore: store,
    recordingSink: InMemoryRecordingSink(store),
    sessionRepository: InMemorySessionRepository(recordingStore: store),
    usesNativePersistence: false,
  );
}
