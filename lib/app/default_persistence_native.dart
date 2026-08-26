import 'dart:async';
import 'dart:io' show Directory, File, Platform;

import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../core/domain/analysis/voice_comparison.dart';
import '../core/domain/persistence/audio_content_identity.dart';
import '../core/domain/persistence/recording_locator.dart';
import '../core/domain/persistence/persistence_storage_report.dart';
import '../core/domain/persistence/recording_sink.dart';
import '../core/domain/persistence/recording_store.dart';
import '../core/domain/persistence/session_repository.dart';
import '../core/domain/persistence/voice_comparison_plan_store.dart';
import '../core/domain/persistence/verified_recording_resolver.dart';
import '../core/platform/platform_capabilities.dart';
import '../infrastructure/persistence/database/app_database.dart';
import '../infrastructure/persistence/in_memory_recording_store.dart';
import '../infrastructure/persistence/in_memory_session_repository.dart';
import '../infrastructure/persistence/in_memory_voice_comparison_plan_store.dart';
import '../infrastructure/persistence/recordings/native_recording_sink.dart';
import '../infrastructure/persistence/recordings/native_managed_audio_store.dart';
import '../infrastructure/persistence/recordings/recording_recovery_service.dart';
import '../infrastructure/persistence/repositories/drift_session_repository.dart';
import '../infrastructure/persistence/repositories/drift_voice_comparison_plan_store.dart';
import '../infrastructure/song_separation/native_song_reference_ownership.dart';

/// Lazily opens native files so app composition remains synchronous while the
/// first recording still waits for recovery before it accepts PCM.
final class DefaultPersistenceAdapters {
  DefaultPersistenceAdapters._(
    this.recordingStore,
    this.verifiedRecordingResolver,
    this.recordingSink,
    this.sessionRepository,
    this.voiceComparisonPlanStore,
    this.usesNativePersistence,
    this.usesPersistentStorage,
  );

  final RecordingStore recordingStore;
  final VerifiedRecordingResolver verifiedRecordingResolver;
  final RecordingSink recordingSink;
  final SessionRepository sessionRepository;
  final VoiceComparisonPlanStore voiceComparisonPlanStore;
  final bool usesNativePersistence;
  final bool usesPersistentStorage;

  Future<PersistenceStorageReport> storageReport() async =>
      usesPersistentStorage
      ? const PersistenceStorageReport(
          structuredDataKind: 'nativeSqlite',
          recordingStorageKind: RecordingStorageKind.file,
          isPersistent: true,
        )
      : const PersistenceStorageReport(
          structuredDataKind: 'memory',
          recordingStorageKind: RecordingStorageKind.none,
          isPersistent: false,
        );

  Future<void> dispose() async {
    final native = await _nativeOrNull();
    await native?.database.close();
  }

  Future<_NativePersistence?> _nativeOrNull() =>
      _native?.openedOrNull() ?? Future<_NativePersistence?>.value(null);
  _NativePersistenceHost? _native;
}

DefaultPersistenceAdapters createDefaultPersistenceAdapters(
  PlatformCapabilities capabilities,
) {
  if (!_supportsNativePersistence(capabilities.target) ||
      capabilities.persistence != PlatformAdapterMode.production) {
    final store = InMemoryRecordingStore();
    return DefaultPersistenceAdapters._(
      store,
      const UnavailableVerifiedRecordingResolver(),
      InMemoryRecordingSink(store),
      InMemorySessionRepository(recordingStore: store),
      InMemoryVoiceComparisonPlanStore(),
      false,
      false,
    );
  }
  final native = _NativePersistenceHost();
  final adapters = DefaultPersistenceAdapters._(
    _DeferredRecordingStore(native),
    _DeferredVerifiedRecordingResolver(native),
    _DeferredRecordingSink(native),
    _DeferredSessionRepository(native),
    _DeferredVoiceComparisonPlanStore(native),
    true,
    true,
  );
  adapters._native = native;
  return adapters;
}

bool _supportsNativePersistence(PlatformTarget target) =>
    target == PlatformTarget.windows || target == PlatformTarget.android;

final class _NativePersistenceHost {
  Future<_NativePersistence>? _opening;

  Future<_NativePersistence> open() => _opening ??= _open();

  Future<_NativePersistence?> openedOrNull() async {
    final opening = _opening;
    return opening ?? Future<_NativePersistence?>.value(null);
  }

  Future<_NativePersistence> _open() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(
      '${support.path}${Platform.pathSeparator}voice_trainer',
    );
    await root.create(recursive: true);
    final recordings = Directory(
      '${root.path}${Platform.pathSeparator}recordings',
    );
    final stems = Directory(
      '${support.path}${Platform.pathSeparator}song-separation'
      '${Platform.pathSeparator}stems',
    );
    final database = AppDatabase(
      NativeDatabase.createInBackground(
        File('${root.path}${Platform.pathSeparator}voice_trainer.sqlite'),
      ),
    );
    final store = NativeRecordingStore(recordings);
    final repository = DriftSessionRepository(database, recordingStore: store);
    final voiceComparisonPlanStore = DriftVoiceComparisonPlanStore(database);
    await recoverVerifiedAudioRoots(<Directory>[recordings, stems]);
    await NativeSongReferenceOwnership(stems).recover();
    await RecordingRecoveryService(database: database, store: store).recover();
    return _NativePersistence(
      database: database,
      store: store,
      repository: repository,
      voiceComparisonPlanStore: voiceComparisonPlanStore,
      recordings: recordings,
    );
  }
}

final class _NativePersistence {
  const _NativePersistence({
    required this.database,
    required this.store,
    required this.repository,
    required this.voiceComparisonPlanStore,
    required this.recordings,
  });

  final AppDatabase database;
  final NativeRecordingStore store;
  final DriftSessionRepository repository;
  final DriftVoiceComparisonPlanStore voiceComparisonPlanStore;
  final Directory recordings;
}

final class _DeferredVoiceComparisonPlanStore
    implements VoiceComparisonPlanStore {
  const _DeferredVoiceComparisonPlanStore(this._native);
  final _NativePersistenceHost _native;

  Future<DriftVoiceComparisonPlanStore> get _delegate async =>
      (await _native.open()).voiceComparisonPlanStore;

  @override
  Future<VoiceComparisonPlan?> loadLatestPlan() async =>
      (await _delegate).loadLatestPlan();

  @override
  Future<void> savePlan(VoiceComparisonPlan plan) async =>
      (await _delegate).savePlan(plan);
}

final class _DeferredRecordingStore implements RecordingStore {
  const _DeferredRecordingStore(this._native);
  final _NativePersistenceHost _native;

  @override
  Future<void> delete(RecordingLocator locator) async =>
      (await _native.open()).store.delete(locator);

  @override
  Future<bool> exists(RecordingLocator locator) async =>
      (await _native.open()).store.exists(locator);
}

final class _DeferredVerifiedRecordingResolver
    implements VerifiedRecordingResolver {
  const _DeferredVerifiedRecordingResolver(this._native);
  final _NativePersistenceHost _native;

  @override
  bool get available => true;

  @override
  Future<VerifiedAudioLease> openVerified(RecordingLocator locator) async =>
      (await _native.open()).store.openVerified(locator);
}

final class _DeferredRecordingSink implements RecordingSink {
  _DeferredRecordingSink(this._native);
  final _NativePersistenceHost _native;
  NativeRecordingSink? _sink;

  @override
  Future<void> open(RecordingMetadata metadata) async {
    final persistence = await _native.open();
    final sink = NativeRecordingSink(persistence.recordings);
    _sink = sink;
    await sink.open(metadata);
  }

  NativeRecordingSink get _active =>
      _sink ?? (throw StateError('Recording sink is not open.'));

  @override
  Future<void> append(chunk) => _active.append(chunk);

  @override
  Future<RecordingLocator> finalize() => _active.finalize();

  @override
  Future<void> abort() async {
    final sink = _sink;
    if (sink != null) await sink.abort();
  }
}

final class _DeferredSessionRepository implements SessionRepository {
  const _DeferredSessionRepository(this._native);
  final _NativePersistenceHost _native;

  Future<DriftSessionRepository> get _delegate async =>
      (await _native.open()).repository;

  @override
  Future<void> save(record) async => (await _delegate).save(record);

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
