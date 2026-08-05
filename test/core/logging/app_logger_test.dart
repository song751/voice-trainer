import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/logging/app_logger.dart';
import 'package:voice_trainer/core/logging/log_redaction.dart';

void main() {
  test(
    'redacts audio, identifiers, notes, paths, collections, and messages',
    () {
      final records = <AppLogRecord>[];
      final logger = AppLogger(sink: records.add);

      logger.log(
        AppLogLevel.error,
        'capture.failed',
        fields: <String, Object?>{
          'sampleRate': 48000,
          'pcmBytes': Uint8List.fromList([1, 2, 3]),
          'deviceId': 'hardware-unique-id',
          'userNote': 'private note',
          'output': r'D:\private\recording.wav',
          'message': r'write failed at D:\private\recording.wav',
          'qualityFlags': ['clipping'],
        },
        error: StateError(r'D:\private\recording.wav'),
      );

      final record = records.single;
      expect(record.event, 'capture.failed');
      expect(record.fields['sampleRate'], 48000);
      expect(record.fields['pcmBytes'], redactedValue);
      expect(record.fields['deviceId'], redactedValue);
      expect(record.fields['userNote'], redactedValue);
      expect(record.fields['output'], redactedPath);
      expect(record.fields['message'], redactedPath);
      expect(record.fields['qualityFlags'], '[COLLECTION_REDACTED]');
      expect(record.fields['errorType'], 'StateError');
      expect(record.fields.toString(), isNot(contains('private')));
      expect(record.fields.toString(), isNot(contains('hardware-unique-id')));
    },
  );

  test('redacts sensitive nested structured fields', () {
    const redactor = LogRedactor();

    final result = redactor.redact(<String, Object?>{
      'capture': <String, Object?>{
        'deviceId': 'secret-device',
        'sampleRate': 48000,
      },
    });

    expect(result['capture'], <String, Object?>{
      'deviceId': redactedValue,
      'sampleRate': 48000,
    });
  });

  test('accepts stable event keys and rejects free-text event data', () {
    final records = <AppLogRecord>[];
    final logger = AppLogger(sink: records.add);

    logger.log(AppLogLevel.info, 'session.capture_started');
    logger.log(AppLogLevel.error, r'failed at D:\private\recording.wav');

    expect(records.first.event, 'session.capture_started');
    expect(records.last.event, 'invalid.event');
    expect(records.last.event, isNot(contains('private')));
  });
}
