import 'dart:typed_data';

import '../../../core/domain/audio/pcm_chunk.dart';

/// Enforces the Web MVP limit on the monotonic capture sample timeline.
///
/// Wall-clock time is deliberately absent, so a paused capture does not spend
/// the recording budget. A chunk crossing the boundary is trimmed exactly to
/// the remaining sample frames and later chunks are ignored.
final class WebRecordingSampleLimit {
  WebRecordingSampleLimit({required this.maximumDuration})
    : assert(maximumDuration > Duration.zero);

  final Duration maximumDuration;
  int? _firstSampleIndex;
  int? _sampleRate;
  int? _expectedNextSampleIndex;
  bool _reached = false;

  bool get reached => _reached;

  PcmChunk? accept(PcmChunk chunk) {
    if (_reached) return null;
    final first = _firstSampleIndex ??= chunk.firstSampleIndex;
    final sampleRate = _sampleRate ??= chunk.format.sampleRate;
    if (chunk.format.sampleRate != sampleRate) {
      throw StateError('Recording sample rate changed during capture.');
    }
    final expected = _expectedNextSampleIndex;
    if (expected != null && chunk.firstSampleIndex < expected) {
      throw StateError('Recording sample index moved backwards.');
    }
    _expectedNextSampleIndex = chunk.endSampleIndexExclusive;
    final maximumSamples =
        maximumDuration.inMicroseconds *
        sampleRate ~/
        Duration.microsecondsPerSecond;
    final limitExclusive = first + maximumSamples;
    final remaining = limitExclusive - chunk.firstSampleIndex;
    if (remaining <= 0) {
      _reached = true;
      return null;
    }
    if (chunk.frameCount <= remaining) {
      if (chunk.endSampleIndexExclusive >= limitExclusive) _reached = true;
      return chunk;
    }
    _reached = true;
    final byteCount = remaining * chunk.format.bytesPerFrame;
    return PcmChunk(
      sequenceNumber: chunk.sequenceNumber,
      firstSampleIndex: chunk.firstSampleIndex,
      format: chunk.format,
      bytes: Uint8List.sublistView(chunk.bytes, 0, byteCount),
      captureMonotonicTime: chunk.captureMonotonicTime,
      droppedSamplesBefore: chunk.droppedSamplesBefore,
      discontinuityBefore: chunk.discontinuityBefore,
    );
  }
}
