import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/reference/song_reference.dart';
import 'package:voice_trainer/infrastructure/persistence/recordings/native_managed_audio_store.dart';
import 'package:voice_trainer/infrastructure/song_separation/native_song_reference_ownership.dart';

void main() {
  late Directory sandbox;
  late Directory root;
  late DateTime now;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('stem-ownership-test-');
    root = Directory('${sandbox.path}${Platform.pathSeparator}stems');
    await root.create();
    now = DateTime.utc(2026, 8, 27, 12);
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  NativeSongReferenceOwnership ownership() => NativeSongReferenceOwnership(
    root,
    now: () => now,
    maximumStemBytes: 1024,
  );

  test(
    'replacement commits new ownership before removing the old pair',
    () async {
      final old = await _writeReference(root, 'song_100_0', <int>[1, 2, 3]);
      await ownership().activate(old);
      now = now.add(const Duration(seconds: 1));
      final replacement = await _writeReference(root, 'song_200_0', <int>[
        4,
        5,
        6,
      ]);

      await ownership().activate(replacement);

      expect(await _stem(root, 'song_100_0', 'vocals').exists(), isFalse);
      expect(
        await _stem(root, 'song_100_0', 'accompaniment').exists(),
        isFalse,
      );
      expect(
        await File(
          '${root.path}${Platform.pathSeparator}reference-song_100_0.json',
        ).exists(),
        isFalse,
      );
      expect((await ownership().restore())?.displayName, 'song_200_0.wav');
    },
  );

  test('failed activation preserves the current valid pair', () async {
    final current = await _writeReference(root, 'song_100_0', <int>[1, 2, 3]);
    await ownership().activate(current);
    final broken = await _writeReference(root, 'song_200_0', <int>[4, 5, 6]);
    await _stem(root, 'song_200_0', 'accompaniment').delete();

    await expectLater(ownership().activate(broken), throwsA(isA<Object>()));

    expect((await ownership().restore())?.displayName, 'song_100_0.wav');
    expect(await _stem(root, 'song_100_0', 'vocals').exists(), isTrue);
    expect(await _stem(root, 'song_100_0', 'accompaniment').exists(), isTrue);
  });

  test(
    'explicit delete removes both stems and their ownership manifest',
    () async {
      final current = await _writeReference(root, 'song_100_0', <int>[1, 2, 3]);
      final store = ownership();
      await store.activate(current);
      await _stem(root, 'song_100_0', 'vocals').delete();

      await store.delete(current);

      expect(
        await _stem(root, 'song_100_0', 'accompaniment').exists(),
        isFalse,
      );
      expect(await store.restore(), isNull);
    },
  );

  test('managed-name links never delete an outside target', () async {
    final current = await _writeReference(root, 'song_100_0', <int>[1, 2, 3]);
    final store = ownership();
    await store.activate(current);
    final vocals = _stem(root, 'song_100_0', 'vocals');
    await vocals.delete();
    final outside = File('${sandbox.path}${Platform.pathSeparator}outside.wav');
    await outside.writeAsBytes(<int>[9, 8, 7]);
    try {
      await Link(vocals.path).create(outside.path);
    } on FileSystemException {
      return;
    }

    await expectLater(
      store.delete(current),
      throwsA(
        isA<SongSeparationFailure>().having(
          (failure) => failure.reason,
          'reason',
          SongSeparationFailureReason.outputFailed,
        ),
      ),
    );
    expect(await outside.readAsBytes(), <int>[9, 8, 7]);
    expect(await _stem(root, 'song_100_0', 'accompaniment').exists(), isTrue);
  });

  test('age cleanup removes only exact unowned stem names', () async {
    final vocals = _stem(root, 'song_100_0', 'vocals');
    final accompaniment = _stem(root, 'song_100_0', 'accompaniment');
    final unrelated = File('${root.path}${Platform.pathSeparator}keep.wav');
    final partial = File(
      '${root.path}${Platform.pathSeparator}.reference-song_100_0.json.partial',
    );
    await vocals.writeAsBytes(<int>[1]);
    await accompaniment.writeAsBytes(<int>[2]);
    await unrelated.writeAsBytes(<int>[3]);
    await partial.writeAsString('incomplete private metadata');
    final stale = now.subtract(const Duration(days: 2));
    await vocals.setLastModified(stale);
    await accompaniment.setLastModified(stale);
    await unrelated.setLastModified(stale);
    await partial.setLastModified(stale);

    await ownership().recover();

    expect(await vocals.exists(), isFalse);
    expect(await accompaniment.exists(), isFalse);
    expect(await partial.exists(), isFalse);
    expect(await unrelated.readAsBytes(), <int>[3]);
  });

  test(
    'startup recovery protects the persistently owned current pair',
    () async {
      final current = await _writeReference(root, 'song_200_0', <int>[4, 5, 6]);
      final store = ownership();
      await store.activate(current);
      final orphanVocals = _stem(root, 'song_100_0', 'vocals');
      final orphanAccompaniment = _stem(root, 'song_100_0', 'accompaniment');
      await orphanVocals.writeAsBytes(<int>[1]);
      await orphanAccompaniment.writeAsBytes(<int>[2]);
      final stale = now.subtract(const Duration(days: 2));
      for (final file in <File>[
        _stem(root, 'song_200_0', 'vocals'),
        _stem(root, 'song_200_0', 'accompaniment'),
        orphanVocals,
        orphanAccompaniment,
      ]) {
        await file.setLastModified(stale);
      }

      await store.recover();

      expect(await _stem(root, 'song_200_0', 'vocals').exists(), isTrue);
      expect(await _stem(root, 'song_200_0', 'accompaniment').exists(), isTrue);
      expect(await orphanVocals.exists(), isFalse);
      expect(await orphanAccompaniment.exists(), isFalse);
    },
  );
}

Future<SeparatedSongReference> _writeReference(
  Directory root,
  String jobId,
  List<int> seed,
) async {
  final vocals = _stem(root, jobId, 'vocals');
  final accompaniment = _stem(root, jobId, 'accompaniment');
  await vocals.writeAsBytes(seed);
  await accompaniment.writeAsBytes(seed.reversed.toList());
  final vocalsIdentity = await NativeManagedAudioStore.identify(vocals);
  final accompanimentIdentity = await NativeManagedAudioStore.identify(
    accompaniment,
  );
  return SeparatedSongReference(
    displayName: '$jobId.wav',
    generatedByModel: true,
    modelId: 'test-model',
    algorithmVersion: 'test-v1',
    sourceSampleRate: 48000,
    sourceChannels: 2,
    sampleRate: 44100,
    channels: 2,
    durationSamples: 44100,
    chunkCount: 1,
    artifactWarning: true,
    vocals: SongStemReference(
      locator: vocals.uri.pathSegments.last,
      sha256: vocalsIdentity.sha256,
      byteLength: vocalsIdentity.byteLength,
    ),
    accompaniment: SongStemReference(
      locator: accompaniment.uri.pathSegments.last,
      sha256: accompanimentIdentity.sha256,
      byteLength: accompanimentIdentity.byteLength,
    ),
  );
}

File _stem(Directory root, String jobId, String kind) =>
    File('${root.path}${Platform.pathSeparator}$jobId-$kind.wav');
