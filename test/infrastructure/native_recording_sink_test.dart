import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/domain/persistence/recording_sink.dart';
import 'package:voice_trainer/infrastructure/persistence/database/app_database.dart';
import 'package:voice_trainer/infrastructure/persistence/recordings/native_recording_sink.dart';
import 'package:voice_trainer/infrastructure/persistence/recordings/recording_recovery_service.dart';

void main() {
  test('native sink atomically promotes a flushed WAV from partial', () async {
    final directory = await Directory.systemTemp.createTemp(
      'voice-trainer-c3-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final sink = NativeRecordingSink(directory);
    const format = CaptureFormat(sampleRate: 48000, channels: 1);
    await sink.open(
      RecordingMetadata(sessionId: 'session-a', startedAt: DateTime.utc(2026)),
    );
    await sink.append(
      PcmChunk(
        sequenceNumber: 0,
        firstSampleIndex: 0,
        format: format,
        bytes: Uint8List(8),
        captureMonotonicTime: Duration.zero,
      ),
    );
    expect(
      await directory.list().any((file) => file.path.endsWith('.partial')),
      isTrue,
    );

    final locator = await sink.finalize();
    final bytes = await File(locator.value).readAsBytes();
    expect(locator.storageKind.name, 'file');
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(ByteData.sublistView(bytes).getUint32(40, Endian.little), 8);
    expect(
      await directory.list().any((file) => file.path.endsWith('.partial')),
      isFalse,
    );
  });

  test(
    'recovery removes partial files and completes recording tombstones',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'voice-trainer-c3-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = NativeRecordingStore(directory);
      final orphan = File(
        '${directory.path}${Platform.pathSeparator}orphan.partial',
      );
      await orphan.writeAsBytes(<int>[1, 2]);
      final completed = File(
        '${directory.path}${Platform.pathSeparator}saved.wav',
      );
      await completed.writeAsBytes(<int>[1, 2]);

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.practiceSessions)
          .insert(
            PracticeSessionsCompanion.insert(
              id: 'session-b',
              templateJson: '{}',
              startedAt: DateTime.utc(2026),
              validFrameCount: 0,
              totalFrameCount: 0,
              qualityFlagsJson: '[]',
            ),
          );
      await database
          .into(database.recordings)
          .insert(
            RecordingsCompanion.insert(
              sessionId: 'session-b',
              locator: completed.path,
              storageKind: 'file',
            ),
          );
      await database.deleteRecordingWithTombstone('session-b');

      await RecordingRecoveryService(
        database: database,
        store: store,
      ).recover();

      expect(await orphan.exists(), isFalse);
      expect(await completed.exists(), isFalse);
      expect(await database.select(database.recordings).get(), isEmpty);
    },
  );
}
