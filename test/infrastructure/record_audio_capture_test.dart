import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:voice_trainer/core/domain/audio/audio_capture.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/infrastructure/audio/record_audio_capture.dart';
import 'package:voice_trainer/infrastructure/audio/record_capture_mapper.dart';
import 'package:voice_trainer/infrastructure/persistence/recordings/wav_stream_writer.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';

void main() {
  test(
    'record adapter emits copied PCM with monotonic sample indices',
    () async {
      final client = _FakeRecordClient();
      final adapter = RecordAudioCapture(client: client);
      final session = await adapter.start(const CaptureRequest());
      final chunks = <PcmChunk>[];
      final sub = session.pcmChunks.listen(chunks.add);
      client.emit(Uint8List(8));
      client.emit(Uint8List(8));
      await Future<void>.delayed(Duration.zero);
      expect(client.config!.streamBufferSize, 512);
      expect(chunks.map((chunk) => chunk.firstSampleIndex), <int>[0, 4]);
      await session.stop();
      await sub.cancel();
    },
  );

  test('streaming WAV writer patches header after PCM append', () async {
    final output = _MemoryOutput();
    final writer = WavStreamWriter(output);
    const format = CaptureFormat(sampleRate: 48000, channels: 1);
    await writer.open(format);
    await writer.append(
      PcmChunk(
        sequenceNumber: 0,
        firstSampleIndex: 0,
        format: format,
        bytes: Uint8List(8),
        captureMonotonicTime: Duration.zero,
      ),
    );
    await writer.finalize();
    final data = ByteData.sublistView(output.bytes);
    expect(String.fromCharCodes(output.bytes.sublist(0, 4)), 'RIFF');
    expect(data.getUint32(40, Endian.little), 8);
  });
}

final class _FakeRecordClient implements RecordClient {
  final _controller = StreamController<Uint8List>.broadcast();
  RecordConfig? config;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<List<InputDevice>> listInputDevices() async => const [];
  @override
  Future<Stream<Uint8List>> startStream(RecordConfig value) async {
    config = value;
    return _controller.stream;
  }

  void emit(Uint8List bytes) => _controller.add(bytes);
  @override
  Future<void> setOnConfigChanged(
    void Function(RecordConfig p1)? callback,
  ) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

final class _MemoryOutput implements WavOutput {
  final bytes = Uint8List(52);
  int _offset = 0;
  @override
  Future<void> append(Uint8List value) async {
    bytes.setRange(_offset, _offset + value.lengthInBytes, value);
    _offset += value.lengthInBytes;
  }

  @override
  Future<void> overwrite(int offset, Uint8List value) async =>
      bytes.setRange(offset, offset + value.lengthInBytes, value);
  @override
  Future<void> close() async {}
  @override
  Future<void> abort() async {}
}
