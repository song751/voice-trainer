import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:voice_trainer/core/domain/audio/audio_capture.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/capture_health.dart';
import 'package:voice_trainer/core/errors/failure.dart';
import 'package:voice_trainer/infrastructure/audio/record_audio_capture.dart';
import 'package:voice_trainer/infrastructure/audio/record_capture_mapper.dart';
import 'package:voice_trainer/infrastructure/persistence/recordings/wav_stream_writer.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';

void main() {
  test(
    'record adapter emits copied PCM with monotonic sample indices',
    () async {
      final client = _FakeRecordClient();
      final adapter = RecordAudioCapture(clientFactory: () => client);
      final session = await adapter.start(const CaptureRequest());
      final chunks = <PcmChunk>[];
      final sub = session.pcmChunks.listen(chunks.add);
      final input = Uint8List(8)..[0] = 7;
      client.emit(input);
      await Future<void>.delayed(Duration.zero);
      input[0] = 99;
      client.emit(Uint8List(8));
      await Future<void>.delayed(Duration.zero);
      expect(client.config!.streamBufferSize, 512);
      expect(chunks.map((chunk) => chunk.firstSampleIndex), <int>[0, 4]);
      expect(chunks.first.bytes.first, 7);
      await session.stop();
      await sub.cancel();
    },
  );

  test(
    'record adapter reports invalid PCM, config changes and stream errors',
    () async {
      final client = _FakeRecordClient();
      final session = await RecordAudioCapture(
        clientFactory: () => client,
      ).start(const CaptureRequest());
      final health = <CaptureHealth>[];
      final healthSub = session.health.listen(health.add);
      final errors = <Object>[];
      final chunkSub = session.pcmChunks.listen((_) {}, onError: errors.add);

      client.emit(Uint8List(3));
      client.emitConfig(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
        ),
      );
      client.emitError(StateError('stream stopped'));
      await Future<void>.delayed(Duration.zero);

      expect(errors.whereType<CaptureFailure>(), isNotEmpty);
      expect(session.effectiveFormat.sampleRate, 44100);
      expect(
        health.single.flags,
        contains(CaptureHealthFlag.processingAdjusted),
      );
      await session.pause();
      await session.resume();
      expect(client.pauseCalls, 1);
      expect(client.resumeCalls, 1);
      await session.stop();
      await healthSub.cancel();
      await chunkSub.cancel();
    },
  );

  test('record adapter rejects an unavailable requested device', () async {
    final client = _FakeRecordClient(devices: const <InputDevice>[]);
    expect(
      () => RecordAudioCapture(
        clientFactory: () => client,
      ).start(const CaptureRequest(deviceId: 'missing')),
      throwsA(
        isA<CaptureFailure>().having(
          (failure) => failure.reason,
          'reason',
          CaptureFailureReason.deviceUnavailable,
        ),
      ),
    );
  });

  test('record adapter owns a fresh plugin client for each session', () async {
    final clients = <_FakeRecordClient>[
      _FakeRecordClient(),
      _FakeRecordClient(),
    ];
    var nextClient = 0;
    final adapter = RecordAudioCapture(
      clientFactory: () => clients[nextClient++],
    );

    for (var index = 0; index < clients.length; index += 1) {
      final session = await adapter.start(const CaptureRequest());
      final chunks = <PcmChunk>[];
      final subscription = session.pcmChunks.listen(chunks.add);
      clients[index].emit(Uint8List(8));
      await Future<void>.delayed(Duration.zero);
      expect(chunks.single.firstSampleIndex, 0);
      await session.stop();
      await subscription.cancel();
    }

    expect(nextClient, 2);
    expect(clients.map((client) => client.disposeCalls), <int>[1, 1]);
  });

  test('record adapter retries the Web default with a 1024 buffer', () async {
    final clients = <_FakeRecordClient>[
      _FakeRecordClient(startError: StateError('512 startup failed')),
      _FakeRecordClient(),
    ];
    var nextClient = 0;
    final adapter = RecordAudioCapture(
      clientFactory: () => clients[nextClient++],
      fallbackStreamBufferSamples: 1024,
    );

    final session = await adapter.start(const CaptureRequest());

    expect(clients.first.config!.streamBufferSize, 512);
    expect(clients.last.config!.streamBufferSize, 1024);
    expect(clients.first.disposeCalls, 1);
    await session.stop();
    expect(clients.last.disposeCalls, 1);
  });

  test(
    'record adapter returns a typed denied permission and disposes query client',
    () async {
      final client = _FakeRecordClient(permissionGranted: false);
      final adapter = RecordAudioCapture(clientFactory: () => client);

      expect(await adapter.requestPermission(), isA<PermissionDenied>());
      expect(client.disposeCalls, 1);
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
  _FakeRecordClient({
    this.devices = const <InputDevice>[],
    this.permissionGranted = true,
    this.startError,
  });

  final _controller = StreamController<Uint8List>.broadcast();
  final List<InputDevice> devices;
  final bool permissionGranted;
  final Object? startError;
  RecordConfig? config;
  void Function(RecordConfig)? _onConfigChanged;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int disposeCalls = 0;
  @override
  Future<bool> hasPermission() async => permissionGranted;
  @override
  Future<List<InputDevice>> listInputDevices() async => devices;
  @override
  Future<Stream<Uint8List>> startStream(RecordConfig value) async {
    config = value;
    final error = startError;
    if (error != null) throw error;
    return _controller.stream;
  }

  void emit(Uint8List bytes) => _controller.add(bytes);
  void emitError(Object error) => _controller.addError(error);
  void emitConfig(RecordConfig config) => _onConfigChanged?.call(config);
  @override
  Future<void> setOnConfigChanged(
    void Function(RecordConfig p1)? callback,
  ) async => _onConfigChanged = callback;
  @override
  Future<void> pause() async => pauseCalls++;
  @override
  Future<void> resume() async => resumeCalls++;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    disposeCalls += 1;
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
  Future<void> flush() async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> abort() async {}
}
