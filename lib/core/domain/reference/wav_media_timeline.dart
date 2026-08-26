import 'dart:convert';
import 'dart:typed_data';

final class WavMediaTimeline {
  const WavMediaTimeline({required this.sampleRate, required this.frameCount});

  final int sampleRate;
  final int frameCount;

  double get durationSeconds => frameCount / sampleRate;

  static WavMediaTimeline parse(Uint8List bytes) {
    if (bytes.lengthInBytes < 12 ||
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WAVE') {
      throw const FormatException('Expected a RIFF/WAVE recording.');
    }
    final data = ByteData.sublistView(bytes);
    int? sampleRate;
    int? blockAlign;
    int? dataBytes;
    var offset = 12;
    while (offset + 8 <= bytes.lengthInBytes) {
      final id = ascii.decode(
        bytes.sublist(offset, offset + 4),
        allowInvalid: true,
      );
      final size = data.getUint32(offset + 4, Endian.little);
      final payload = offset + 8;
      final end = payload + size;
      if (end > bytes.lengthInBytes) {
        throw const FormatException('WAV chunk exceeds verified bytes.');
      }
      if (id == 'fmt ') {
        if (size < 16 || data.getUint16(payload, Endian.little) != 1) {
          throw const FormatException('Expected uncompressed PCM WAV.');
        }
        sampleRate = data.getUint32(payload + 4, Endian.little);
        blockAlign = data.getUint16(payload + 12, Endian.little);
      } else if (id == 'data') {
        dataBytes = size;
      }
      offset = end + (size.isOdd ? 1 : 0);
    }
    if (sampleRate == null ||
        sampleRate <= 0 ||
        blockAlign == null ||
        blockAlign <= 0 ||
        dataBytes == null ||
        dataBytes % blockAlign != 0) {
      throw const FormatException('WAV media timeline is inconsistent.');
    }
    return WavMediaTimeline(
      sampleRate: sampleRate,
      frameCount: dataBytes ~/ blockAlign,
    );
  }
}
