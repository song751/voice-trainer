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

  test(
    'verified byte cap accepts the boundary and rejects one byte over',
    () async {
      final file = File('${root.path}${Platform.pathSeparator}bounded.wav');
      await file.writeAsBytes(<int>[1, 2, 3]);
      final identity = await NativeManagedAudioStore.identify(file);
      final managed = NativeManagedAudioStore(root);

      final lease = await managed.openVerified(
        locator: 'bounded.wav',
        expected: identity,
        maximumBytes: 3,
      );
      expect(lease.bytes, hasLength(3));
      await lease.dispose();

      await expectLater(
        managed.openVerified(
          locator: 'bounded.wav',
          expected: identity,
          maximumBytes: 2,
        ),
        throwsA(_failure(AudioContentFailureReason.resourceLimit)),
      );
    },
  );

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
    'verified bytes stay stable when source changes and reject caller mutation',
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
      expect(() => lease.bytes[0] = 99, throwsUnsupportedError);
      expect(lease.bytes, <int>[1, 2, 3]);
      expect(lease.identity, identity);
      expect(
        await Directory(
          '${root.path}${Platform.pathSeparator}.verified',
        ).exists(),
        isFalse,
      );
    },
  );

  test('legacy verified snapshots are cleaned idempotently', () async {
    final snapshots = Directory(
      '${root.path}${Platform.pathSeparator}.verified',
    );
    await snapshots.create();
    final stale = File(
      '${snapshots.path}${Platform.pathSeparator}lease_123_0.wav',
    );
    final unrelated = File(
      '${snapshots.path}${Platform.pathSeparator}keep.txt',
    );
    await stale.writeAsBytes(<int>[1, 2, 3]);
    await unrelated.writeAsString('keep');

    final managed = NativeManagedAudioStore(root);
    await managed.recoverVerifiedLeases();
    await managed.recoverVerifiedLeases();

    expect(await stale.exists(), isFalse);
    expect(await unrelated.readAsString(), 'keep');
  });

  test('startup recovery cleans recording and stem managed roots', () async {
    final recordings = Directory(
      '${sandbox.path}${Platform.pathSeparator}recordings-startup',
    );
    final stems = Directory(
      '${sandbox.path}${Platform.pathSeparator}stems-startup',
    );
    for (final managedRoot in <Directory>[recordings, stems]) {
      final verified = Directory(
        '${managedRoot.path}${Platform.pathSeparator}.verified',
      );
      await verified.create(recursive: true);
      await File(
        '${verified.path}${Platform.pathSeparator}lease_123_0.wav',
      ).writeAsBytes(<int>[1, 2, 3]);
    }

    await recoverVerifiedAudioRoots(<Directory>[recordings, stems]);
    await recoverVerifiedAudioRoots(<Directory>[recordings, stems]);

    for (final managedRoot in <Directory>[recordings, stems]) {
      expect(
        await Directory(
          '${managedRoot.path}${Platform.pathSeparator}.verified',
        ).exists(),
        isFalse,
      );
    }
  });

  test('verified recovery rejects a linked snapshot directory', () async {
    final outside = Directory(
      '${sandbox.path}${Platform.pathSeparator}outside-verified',
    );
    await outside.create();
    final outsideLease = File(
      '${outside.path}${Platform.pathSeparator}lease_123_0.wav',
    );
    await outsideLease.writeAsBytes(<int>[9, 8, 7]);
    final link = Link('${root.path}${Platform.pathSeparator}.verified');
    try {
      await link.create(outside.path);
    } on FileSystemException {
      return;
    }

    await expectLater(
      NativeManagedAudioStore(root).recoverVerifiedLeases(),
      throwsA(_failure(AudioContentFailureReason.outsideManagedRoot)),
    );
    expect(await outsideLease.readAsBytes(), <int>[9, 8, 7]);
  });

  test(
    'verified recovery rejects linked entries without following them',
    () async {
      final snapshots = Directory(
        '${root.path}${Platform.pathSeparator}.verified',
      );
      await snapshots.create();
      final outside = File(
        '${sandbox.path}${Platform.pathSeparator}outside.wav',
      );
      await outside.writeAsBytes(<int>[4, 5, 6]);
      final link = Link(
        '${snapshots.path}${Platform.pathSeparator}lease_123_0.wav',
      );
      try {
        await link.create(outside.path);
      } on FileSystemException {
        return;
      }

      await expectLater(
        NativeManagedAudioStore(root).recoverVerifiedLeases(),
        throwsA(_failure(AudioContentFailureReason.outsideManagedRoot)),
      );
      expect(await outside.readAsBytes(), <int>[4, 5, 6]);
    },
  );
}

Matcher _failure(AudioContentFailureReason reason) => isA<AudioContentFailure>()
    .having((failure) => failure.reason, 'reason', reason);
