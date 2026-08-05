import 'dart:typed_data';

import '../../../core/domain/audio/capture_format.dart';
import '../../../core/domain/audio/pcm_chunk.dart';

abstract interface class WavOutput {
  Future<void> append(Uint8List bytes);
  Future<void> overwrite(int offset, Uint8List bytes);
  Future<void> close();
  Future<void> abort();
}

final class WavStreamWriter {
  WavStreamWriter(this._output);
  final WavOutput _output;
  CaptureFormat? _format;
  int _dataBytes = 0;
  bool _opened = false;

  Future<void> open(CaptureFormat format) async {
    _format = format;
    _opened = true;
    await _output.append(Uint8List(44));
  }

  Future<void> append(PcmChunk chunk) async {
    if (!_opened || chunk.format != _format) {
      throw StateError('Unexpected PCM format.');
    }
    _dataBytes += chunk.bytes.lengthInBytes;
    await _output.append(chunk.bytes);
  }

  Future<void> finalize() async {
    final format = _format;
    if (!_opened || format == null) throw StateError('WAV writer is not open.');
    await _output.overwrite(0, _header(format, _dataBytes));
    await _output.close();
    _opened = false;
  }

  Future<void> abort() async {
    _opened = false;
    await _output.abort();
  }
}

Uint8List _header(CaptureFormat format, int dataBytes) {
  final bytes = Uint8List(44);
  final data = ByteData.sublistView(bytes);
  void ascii(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes[o + i] = s.codeUnitAt(i);
    }
  }

  const bits = 16;
  final align = format.channels * 2;
  ascii(0, 'RIFF');
  data.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, format.channels, Endian.little);
  data.setUint32(24, format.sampleRate, Endian.little);
  data.setUint32(28, format.sampleRate * align, Endian.little);
  data.setUint16(32, align, Endian.little);
  data.setUint16(34, bits, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, dataBytes, Endian.little);
  return bytes;
}
