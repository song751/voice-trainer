import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/persistence/audio_content_identity.dart';
import 'package:voice_trainer/core/domain/persistence/recording_locator.dart';
import 'package:voice_trainer/infrastructure/persistence/recordings/native_managed_audio_store.dart';
import 'package:voice_trainer/infrastructure/persistence/recordings/native_recording_sink.dart';

void main() {
  late Directory sandbox;
  late Directory root;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('managed-audio-test-');
    root = Directory('${sandbox.path}${Platform.pathSeparator}recordings');
    await root.create();
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test(
    'outside-root read and delete are rejected without touching file',
    () async {
      final outside = File(
        '${sandbox.path}${Platform.pathSeparator}outside.wav',
      );
      await outside.writeAsBytes(<int>[1, 2, 3]);
      final identity = await NativeManagedAudioStore.identify(outside);
      final store = NativeRecordingStore(root);
      final locator = RecordingLocator(
        value: outside.path,
        storageKind: RecordingStorageKind.file,
        identity: identity,
      );

      await expectLater(
        store.openVerified(locator),
        throwsA(_failure(AudioContentFailureReason.outsideManagedRoot)),
      );
      await expectLater(
        store.delete(locator),
        throwsA(_failure(AudioContentFailureReason.outsideManagedRoot)),
      );
      expect(await outside.exists(), isTrue);
    },
  );

  test('legacy absolute locator works only inside managed root', () async {
    final file = File('${root.path}${Platform.pathSeparator}legacy.wav');
    await file.writeAsBytes(<int>[1, 2, 3]);
    final store = NativeRecordingStore(root);
    final locator = RecordingLocator(
      value: file.path,
      storageKind: RecordingStorageKind.file,
    );

    expect(await store.exists(locator), isTrue);
    await expectLater(
      store.openVerified(locator),
      throwsA(_failure(AudioContentFailureReason.legacyUnbound)),
    );
    await store.delete(locator);
    expect(await file.exists(), isFalse);
  });

  test('missing, length swap, and same-length hash swap are typed', () async {
    final store = NativeRecordingStore(root);
    const missingIdentity = AudioContentIdentity(
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      byteLength: 3,
    );
    await expectLater(
      store.openVerified(
        const RecordingLocator(
          value: 'missing.wav',
          storageKind: RecordingStorageKind.file,
          identity: missingIdentity,
        ),
      ),
      throwsA(_failure(AudioContentFailureReason.missing)),
    );

    final file = File('${root.path}${Platform.pathSeparator}take.wav');
    await file.writeAsBytes(<int>[1, 2, 3]);
    final original = await NativeManagedAudioStore.identify(file);
    await file.writeAsBytes(<int>[9, 8, 7, 6]);
    await expectLater(
      store.openVerified(
        RecordingLocator(
          value: 'take.wav',
          storageKind: RecordingStorageKind.file,
          identity: original,
        ),
      ),
      throwsA(_failure(AudioContentFailureReason.lengthMismatch)),
    );

    await file.writeAsBytes(<int>[9, 8, 7]);
    await expectLater(
      store.openVerified(
        RecordingLocator(
          value: 'take.wav',
          storageKind: RecordingStorageKind.file,
          identity: original,
        ),
      ),
      throwsA(_failure(AudioContentFailureReason.hashMismatch)),
    );
  });

  test(
    'verified lease stays stable when source is replaced afterwards',
    () async {
      final file = File('${root.path}${Platform.pathSeparator}take.wav');
      await file.writeAsBytes(<int>[1, 2, 3]);
      final identity = await NativeManagedAudioStore.identify(file);
      final lease = await NativeRecordingStore(root).openVerified(
        RecordingLocator(
          value: 'take.wav',
          storageKind: RecordingStorageKind.file,
          identity: identity,
        ),
      );
      addTearDown(lease.dispose);

      await file.writeAsBytes(<int>[7, 8, 9]);
      expect(await File(lease.path).readAsBytes(), <int>[1, 2, 3]);
      expect(lease.identity, identity);
    },
  );
}

Matcher _failure(AudioContentFailureReason reason) => isA<AudioContentFailure>()
    .having((failure) => failure.reason, 'reason', reason);
