import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/infrastructure/persistence/recordings/web_recording_limit.dart';

void main() {
  test('limits recording by sample index and trims a crossing chunk', () {
    final limit = WebRecordingSampleLimit(
      maximumDuration: const Duration(seconds: 3),
    );

    final first = limit.accept(_chunk(first: 100, frames: 20));
    final crossing = limit.accept(_chunk(first: 120, frames: 20));
    final after = limit.accept(_chunk(first: 130, frames: 10));

    expect(first!.frameCount, 20);
    expect(crossing!.firstSampleIndex, 120);
    expect(crossing.frameCount, 10);
    expect(crossing.endSampleIndexExclusive, 130);
    expect(after, isNull);
    expect(limit.reached, isTrue);
  });

  test('pause wall time does not consume the sample-index budget', () {
    final limit = WebRecordingSampleLimit(
      maximumDuration: const Duration(seconds: 3),
    );

    final beforePause = limit.accept(
      _chunk(first: 0, frames: 10, captureTime: const Duration(seconds: 1)),
    );
    final afterPause = limit.accept(
      _chunk(first: 10, frames: 10, captureTime: const Duration(hours: 1)),
    );

    expect(beforePause!.frameCount, 10);
    expect(afterPause!.frameCount, 10);
    expect(limit.reached, isFalse);
  });

  test('a discontinuity cannot extend the sample-index boundary', () {
    final limit = WebRecordingSampleLimit(
      maximumDuration: const Duration(seconds: 3),
    );

    expect(limit.accept(_chunk(first: 50, frames: 10)), isNotNull);
    expect(limit.accept(_chunk(first: 79, frames: 5))!.frameCount, 1);
    expect(limit.accept(_chunk(first: 80, frames: 5)), isNull);
    expect(limit.reached, isTrue);
  });

  test('rejects a sample-rate change instead of changing the limit', () {
    final limit = WebRecordingSampleLimit(
      maximumDuration: const Duration(seconds: 3),
    );
    limit.accept(_chunk(first: 0, frames: 10));

    expect(
      () => limit.accept(
        PcmChunk(
          sequenceNumber: 1,
          firstSampleIndex: 10,
          format: const CaptureFormat(sampleRate: 20, channels: 1),
          bytes: Uint8List(20),
          captureMonotonicTime: Duration.zero,
        ),
      ),
      throwsStateError,
    );
  });

  test('rejects a backwards sample index', () {
    final limit = WebRecordingSampleLimit(
      maximumDuration: const Duration(seconds: 3),
    );
    limit.accept(_chunk(first: 10, frames: 10));

    expect(() => limit.accept(_chunk(first: 19, frames: 5)), throwsStateError);
  });
}

PcmChunk _chunk({
  required int first,
  required int frames,
  Duration captureTime = Duration.zero,
}) => PcmChunk(
  sequenceNumber: first,
  firstSampleIndex: first,
  format: const CaptureFormat(sampleRate: 10, channels: 1),
  bytes: Uint8List(frames * 2),
  captureMonotonicTime: captureTime,
);
