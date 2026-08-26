import '../../../core/domain/persistence/recording_locator.dart';
import '../../../core/errors/failure.dart';

RecordingStorageKind decodeWebRecordingStorageResult(String result) =>
    switch (result) {
      'opfs' => RecordingStorageKind.opfs,
      'indexedDb' => RecordingStorageKind.indexedDb,
      'quotaExceeded' => throw const PersistenceFailure(
        reason: PersistenceFailureReason.quotaExceeded,
      ),
      'privateMode' => throw const PersistenceFailure(
        reason: PersistenceFailureReason.privateMode,
      ),
      _ => throw const PersistenceFailure(
        reason: PersistenceFailureReason.unavailable,
      ),
    };

void requirePersistentWebDatabase(String chosenImplementation) {
  if (chosenImplementation == 'inMemory') {
    throw const PersistenceFailure(
      reason: PersistenceFailureReason.privateMode,
    );
  }
}
