import '../core/domain/persistence/persistence_storage_report.dart';
import '../core/domain/persistence/recording_locator.dart';
import '../core/domain/persistence/recording_sink.dart';
import '../core/domain/persistence/recording_store.dart';
import '../core/domain/persistence/session_repository.dart';
import '../core/domain/persistence/voice_comparison_plan_store.dart';
import '../core/domain/analysis/voice_comparison.dart';
import '../core/errors/failure.dart';
import '../core/platform/platform_capabilities.dart';
import '../infrastructure/persistence/database/app_database.dart';
import '../infrastructure/persistence/database/connection/open_database.dart';
import '../infrastructure/persistence/in_memory_recording_store.dart';
import '../infrastructure/persistence/in_memory_session_repository.dart';
import '../infrastructure/persistence/in_memory_voice_comparison_plan_store.dart';
import '../infrastructure/persistence/recordings/recording_recovery_service.dart';
import '../infrastructure/persistence/recordings/web_recording_sink.dart';
import '../infrastructure/persistence/recordings/web_storage_result.dart';
import '../infrastructure/persistence/repositories/drift_session_repository.dart';
import '../infrastructure/persistence/repositories/drift_voice_comparison_plan_store.dart';

final class DefaultPersistenceAdapters {
  DefaultPersistenceAdapters._({
    required this.recordingStore,
    required this.recordingSink,
    required this.sessionRepository,
    required this.voiceComparisonPlanStore,
    required this.usesNativePersistence,
    required this.usesPersistentStorage,
    this._web,
  });

  final RecordingStore recordingStore;
  final RecordingSink recordingSink;
  final SessionRepository sessionRepository;
  final VoiceComparisonPlanStore voiceComparisonPlanStore;
  final bool usesNativePersistence;
  final bool usesPersistentStorage;
  final _WebPersistenceHost? _web;

  Future<PersistenceStorageReport> storageReport() async {
    final web = _web;
    if (web == null) {
      return const PersistenceStorageReport(
        structuredDataKind: 'memory',
        recordingStorageKind: RecordingStorageKind.none,
        isPersistent: false,
      );
    }
    return (await web.open()).report;
  }

  Future<void> dispose() async {
    final opened = await _web?.openedOrNull();
    await opened?.database.close();
  }
}

DefaultPersistenceAdapters createDefaultPersistenceAdapters(
  PlatformCapabilities capabilities,
) {
  if (capabilities.target != PlatformTarget.web ||
      capabilities.persistence != PlatformAdapterMode.production) {
    final store = InMemoryRecordingStore();
    return DefaultPersistenceAdapters._(
      recordingStore: store,
      recordingSink: InMemoryRecordingSink(store),
      sessionRepository: InMemorySessionRepository(recordingStore: store),
      voiceComparisonPlanStore: InMemoryVoiceComparisonPlanStore(),
      usesNativePersistence: false,
      usesPersistentStorage: false,
    );
  }
  final web = _WebPersistenceHost();
  return DefaultPersistenceAdapters._(
    recordingStore: _DeferredWebRecordingStore(web),
    recordingSink: _DeferredWebRecordingSink(
      web,
      maximumDuration:
          capabilities.maximumRecordingDuration ?? const Duration(seconds: 60),
    ),
    sessionRepository: _DeferredWebSessionRepository(web),
    voiceComparisonPlanStore: _DeferredWebVoiceComparisonPlanStore(web),
    usesNativePersistence: false,
    usesPersistentStorage: true,
    web: web,
  );
}

final class _WebPersistenceHost {
  final WebRecordingStore store = WebRecordingStore();
  Future<_WebPersistence>? _opening;

  Future<_WebPersistence> open() async {
    final existing = _opening;
    if (existing != null) return existing;
    final opening = _open();
    _opening = opening;
    try {
      return await opening;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<_WebPersistence?> openedOrNull() async => _opening;

  Future<_WebPersistence> _open() async {
    AppDatabase? database;
    try {
      final databaseResult = await openAppDatabase();
      database = AppDatabase(databaseResult.executor);
      requirePersistentWebDatabase(databaseResult.chosenImplementation);
      final recordingKind = await store.probe();
      final repository = DriftSessionRepository(
        database,
        recordingStore: store,
      );
      final voiceComparisonPlanStore = DriftVoiceComparisonPlanStore(database);
      await RecordingRecoveryService(
        database: database,
        store: store,
      ).recover();
      return _WebPersistence(
        database: database,
        repository: repository,
        voiceComparisonPlanStore: voiceComparisonPlanStore,
        report: PersistenceStorageReport(
          structuredDataKind: databaseResult.chosenImplementation,
          recordingStorageKind: recordingKind,
          isPersistent: true,
          missingFeatures: List<String>.unmodifiable(
            databaseResult.missingFeatures,
          ),
        ),
      );
    } on PersistenceFailure {
      await database?.close();
      rethrow;
    } catch (_) {
      await database?.close();
      throw const PersistenceFailure();
    }
  }
}

final class _WebPersistence {
  const _WebPersistence({
    required this.database,
    required this.repository,
    required this.voiceComparisonPlanStore,
    required this.report,
  });

  final AppDatabase database;
  final DriftSessionRepository repository;
  final DriftVoiceComparisonPlanStore voiceComparisonPlanStore;
  final PersistenceStorageReport report;
}

final class _DeferredWebVoiceComparisonPlanStore
    implements VoiceComparisonPlanStore {
  const _DeferredWebVoiceComparisonPlanStore(this._web);
  final _WebPersistenceHost _web;

  Future<DriftVoiceComparisonPlanStore> get _delegate async =>
      (await _web.open()).voiceComparisonPlanStore;

  @override
  Future<VoiceComparisonPlan?> loadLatestPlan() async =>
      (await _delegate).loadLatestPlan();

  @override
  Future<void> savePlan(VoiceComparisonPlan plan) async =>
      (await _delegate).savePlan(plan);
}

final class _DeferredWebRecordingStore implements RecordingStore {
  const _DeferredWebRecordingStore(this._web);
  final _WebPersistenceHost _web;

  @override
  Future<void> delete(RecordingLocator locator) async {
    await _web.open();
    await _web.store.delete(locator);
  }

  @override
  Future<bool> exists(RecordingLocator locator) async {
    await _web.open();
    return _web.store.exists(locator);
  }
}

final class _DeferredWebRecordingSink implements RecordingSink {
  _DeferredWebRecordingSink(this._web, {required this.maximumDuration});
  final _WebPersistenceHost _web;
  final Duration maximumDuration;
  WebRecordingSink? _sink;

  @override
  Future<void> open(RecordingMetadata metadata) async {
    await _web.open();
    final sink = WebRecordingSink(_web.store, maximumDuration: maximumDuration);
    _sink = sink;
    await sink.open(metadata);
  }

  WebRecordingSink get _active =>
      _sink ?? (throw StateError('Recording sink is not open.'));

  @override
  Future<void> append(chunk) => _active.append(chunk);

  @override
  Future<RecordingLocator> finalize() => _active.finalize();

  @override
  Future<void> abort() async => _sink?.abort();
}

final class _DeferredWebSessionRepository implements SessionRepository {
  const _DeferredWebSessionRepository(this._web);
  final _WebPersistenceHost _web;

  Future<DriftSessionRepository> get _delegate async =>
      (await _web.open()).repository;

  @override
  Future<void> save(PracticeSessionRecord record) async =>
      (await _delegate).save(record);

  @override
  Future<PracticeSessionRecord?> findById(String id) async =>
      (await _delegate).findById(id);

  @override
  Future<List<PracticeSessionRecord>> listRecent({int limit = 20}) async =>
      (await _delegate).listRecent(limit: limit);

  @override
  Future<void> delete(String id) async => (await _delegate).delete(id);

  @override
  Future<void> deleteRecording(String id) async =>
      (await _delegate).deleteRecording(id);
}
