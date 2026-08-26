import '../core/domain/persistence/recording_sink.dart';
import '../core/domain/persistence/recording_store.dart';
import '../core/domain/persistence/recording_locator.dart';
import '../core/domain/persistence/persistence_storage_report.dart';
import '../core/domain/persistence/session_repository.dart';
import '../core/domain/persistence/voice_comparison_plan_store.dart';
import '../core/domain/persistence/verified_recording_resolver.dart';
import '../core/platform/platform_capabilities.dart';
import '../infrastructure/persistence/in_memory_recording_store.dart';
import '../infrastructure/persistence/in_memory_session_repository.dart';
import '../infrastructure/persistence/in_memory_voice_comparison_plan_store.dart';

final class DefaultPersistenceAdapters {
  const DefaultPersistenceAdapters({
    required this.recordingStore,
    required this.verifiedRecordingResolver,
    required this.recordingSink,
    required this.sessionRepository,
    required this.voiceComparisonPlanStore,
    required this.usesNativePersistence,
    required this.usesPersistentStorage,
  });

  final RecordingStore recordingStore;
  final VerifiedRecordingResolver verifiedRecordingResolver;
  final RecordingSink recordingSink;
  final SessionRepository sessionRepository;
  final VoiceComparisonPlanStore voiceComparisonPlanStore;
  final bool usesNativePersistence;
  final bool usesPersistentStorage;

  Future<PersistenceStorageReport> storageReport() async =>
      const PersistenceStorageReport(
        structuredDataKind: 'memory',
        recordingStorageKind: RecordingStorageKind.none,
        isPersistent: false,
      );

  Future<void> dispose() async {}
}

DefaultPersistenceAdapters createDefaultPersistenceAdapters(
  PlatformCapabilities capabilities,
) {
  final store = InMemoryRecordingStore();
  return DefaultPersistenceAdapters(
    recordingStore: store,
    verifiedRecordingResolver: const UnavailableVerifiedRecordingResolver(),
    recordingSink: InMemoryRecordingSink(store),
    sessionRepository: InMemorySessionRepository(recordingStore: store),
    voiceComparisonPlanStore: InMemoryVoiceComparisonPlanStore(),
    usesNativePersistence: false,
    usesPersistentStorage: false,
  );
}
