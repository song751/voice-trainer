import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/persistence/recording_locator.dart';
import 'package:voice_trainer/core/errors/failure.dart';
import 'package:voice_trainer/infrastructure/persistence/recordings/web_storage_result.dart';

void main() {
  test('maps only durable recording storage kinds', () {
    expect(decodeWebRecordingStorageResult('opfs'), RecordingStorageKind.opfs);
    expect(
      decodeWebRecordingStorageResult('indexedDb'),
      RecordingStorageKind.indexedDb,
    );
  });

  test('maps quota, private mode, and unavailable to typed failures', () {
    expect(
      () => decodeWebRecordingStorageResult('quotaExceeded'),
      throwsA(
        isA<PersistenceFailure>().having(
          (failure) => failure.reason,
          'reason',
          PersistenceFailureReason.quotaExceeded,
        ),
      ),
    );
    expect(
      () => decodeWebRecordingStorageResult('privateMode'),
      throwsA(
        isA<PersistenceFailure>().having(
          (failure) => failure.reason,
          'reason',
          PersistenceFailureReason.privateMode,
        ),
      ),
    );
    expect(
      () => decodeWebRecordingStorageResult('unavailable'),
      throwsA(
        isA<PersistenceFailure>().having(
          (failure) => failure.reason,
          'reason',
          PersistenceFailureReason.unavailable,
        ),
      ),
    );
  });

  test('rejects an in-memory Drift Web backend', () {
    expect(
      () => requirePersistentWebDatabase('inMemory'),
      throwsA(
        isA<PersistenceFailure>().having(
          (failure) => failure.reason,
          'reason',
          PersistenceFailureReason.privateMode,
        ),
      ),
    );
    expect(
      () => requirePersistentWebDatabase('sharedIndexedDb'),
      returnsNormally,
    );
    expect(() => requirePersistentWebDatabase('opfsLocks'), returnsNormally);
  });
}
