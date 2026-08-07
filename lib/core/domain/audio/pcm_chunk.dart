import 'dart:typed_data';

import 'capture_format.dart';

final class PcmChunk {
  PcmChunk({
    required this.sequenceNumber,
    required this.firstSampleIndex,
    required this.format,
    required Uint8List bytes,
    required this.captureMonotonicTime,
    this.droppedSamplesBefore = 0,
    this.discontinuityBefore = false,
  }) : assert(sequenceNumber >= 0),
       assert(firstSampleIndex >= 0),
       assert(bytes.lengthInBytes.isEven),
       assert(bytes.lengthInBytes % format.bytesPerFrame == 0),
       assert(droppedSamplesBefore >= 0),
       bytes = Uint8List.fromList(bytes);

  final int sequenceNumber;
  final int firstSampleIndex;
  final CaptureFormat format;
  final Uint8List bytes;
  final Duration captureMonotonicTime;
  int droppedSamplesBefore;
  bool discontinuityBefore;

  int get frameCount => bytes.lengthInBytes ~/ format.bytesPerFrame;

  int get endSampleIndexExclusive => firstSampleIndex + frameCount;
}

final class PcmBatch {
  PcmBatch({
    required this.firstSampleIndex,
    required this.format,
    required Uint8List bytes,
    this.droppedSamplesBefore = 0,
    this.discontinuityBefore = false,
  }) : assert(firstSampleIndex >= 0),
       assert(droppedSamplesBefore >= 0),
       bytes = Uint8List.fromList(bytes);

  final int firstSampleIndex;
  final CaptureFormat format;
  final Uint8List bytes;
  final int droppedSamplesBefore;
  final bool discontinuityBefore;

  int get frameCount => bytes.lengthInBytes ~/ format.bytesPerFrame;

  bool get hasOddByteLength => bytes.lengthInBytes.isOdd;

  bool get isFrameAligned =>
      !hasOddByteLength && bytes.lengthInBytes % format.bytesPerFrame == 0;
}
