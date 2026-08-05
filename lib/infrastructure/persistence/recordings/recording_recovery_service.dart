import '../../../core/domain/persistence/recording_locator.dart';
import '../../../core/domain/persistence/recording_store.dart';
import '../database/app_database.dart';

abstract interface class IncompleteRecordingRecovery {
  Future<void> recoverIncompleteRecordings();
}

final class RecordingRecoveryService {
  factory RecordingRecoveryService({
    required AppDatabase database,
    required RecordingStore store,
  }) => RecordingRecoveryService._(database, store);

  RecordingRecoveryService._(this._database, this._store);

  final AppDatabase _database;
  final RecordingStore _store;

  Future<void> recover() async {
    final store = _store;
    if (store is IncompleteRecordingRecovery) {
      await (store as IncompleteRecordingRecovery)
          .recoverIncompleteRecordings();
    }
    for (final recording in await _database.pendingRecordings()) {
      final locator = RecordingLocator(
        value: recording.locator,
        storageKind: RecordingStorageKind.values.byName(recording.storageKind),
      );
      try {
        await _store.delete(locator);
        await _database.finalizeRecordingDeletion(recording.sessionId);
      } catch (_) {
        // The tombstone remains durable until a later startup removes the blob.
      }
    }
  }

  Future<void> deleteRecording(String sessionId) async {
    final recording = await _database.recordingForSession(sessionId);
    if (recording == null) return;
    await _database.deleteRecordingWithTombstone(sessionId);
    await _store.delete(
      RecordingLocator(
        value: recording.locator,
        storageKind: RecordingStorageKind.values.byName(recording.storageKind),
      ),
    );
    await _database.finalizeRecordingDeletion(sessionId);
  }
}
