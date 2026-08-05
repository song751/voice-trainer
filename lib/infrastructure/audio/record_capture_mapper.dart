import 'dart:typed_data';

import 'package:record/record.dart';

import '../../core/domain/audio/audio_capture.dart';
import '../../core/domain/audio/capture_format.dart';

final class RecordCaptureMapper {
  const RecordCaptureMapper();

  RecordConfig toRecordConfig(CaptureRequest request, InputDevice? device) {
    if (request.format.encoding != PcmEncoding.signedPcm16LittleEndian) {
      throw ArgumentError.value(request.format.encoding, 'encoding');
    }
    return RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: request.format.sampleRate,
      numChannels: request.format.channels,
      device: device,
      autoGain: request.processing.automaticGainControl,
      echoCancel: request.processing.echoCancellation,
      noiseSuppress: request.processing.noiseSuppression,
      streamBufferSize: request.streamBufferSamples ?? 512,
    );
  }

  CaptureFormat toCaptureFormat(RecordConfig config) => CaptureFormat(
    sampleRate: config.sampleRate,
    channels: config.numChannels,
  );

  CaptureDevice toCaptureDevice(InputDevice device) =>
      CaptureDevice(id: device.id, label: device.label);
}

abstract interface class RecordClient {
  Future<bool> hasPermission();
  Future<List<InputDevice>> listInputDevices();
  Future<Stream<Uint8List>> startStream(RecordConfig config);
  Future<void> setOnConfigChanged(void Function(RecordConfig)? callback);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

final class RecordPluginClient implements RecordClient {
  RecordPluginClient([AudioRecorder? recorder])
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();
  @override
  Future<List<InputDevice>> listInputDevices() => _recorder.listInputDevices();
  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) =>
      _recorder.startStream(config);
  @override
  Future<void> setOnConfigChanged(void Function(RecordConfig)? callback) =>
      _recorder.setOnConfigChanged(callback);
  @override
  Future<void> pause() => _recorder.pause();
  @override
  Future<void> resume() => _recorder.resume();
  @override
  Future<void> stop() => _recorder.stop();
  @override
  Future<void> dispose() => _recorder.dispose();
}
