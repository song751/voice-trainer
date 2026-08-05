import '../../errors/failure.dart';
import 'capture_format.dart';
import 'capture_health.dart';
import 'pcm_chunk.dart';

final class CaptureRequest {
  const CaptureRequest({
    this.format = const CaptureFormat(sampleRate: 48000, channels: 1),
    this.processing = const CaptureProcessingConfig(),
    this.streamBufferSamples,
    this.deviceId,
  }) : assert(streamBufferSamples == null || streamBufferSamples > 0);

  final CaptureFormat format;
  final CaptureProcessingConfig processing;
  final int? streamBufferSamples;
  final String? deviceId;
}

final class CaptureDevice {
  const CaptureDevice({required this.id, this.label});

  final String id;
  final String? label;
}

sealed class PermissionResult {
  const PermissionResult();
}

final class PermissionGranted extends PermissionResult {
  const PermissionGranted();
}

final class PermissionDenied extends PermissionResult {
  const PermissionDenied(this.failure);

  final PermissionDeniedFailure failure;
}

abstract interface class AudioCapture {
  Future<List<CaptureDevice>> listDevices();

  Future<PermissionResult> requestPermission();

  Future<CaptureSession> start(CaptureRequest request);
}

abstract interface class CaptureSession {
  CaptureFormat get effectiveFormat;

  Stream<PcmChunk> get pcmChunks;

  Stream<CaptureHealth> get health;

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();

  Future<void> dispose();
}
