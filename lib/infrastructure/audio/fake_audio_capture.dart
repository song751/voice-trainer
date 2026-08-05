import 'dart:async';

import '../../core/domain/audio/audio_capture.dart';
import '../../core/domain/audio/capture_format.dart';
import '../../core/domain/audio/capture_health.dart';
import '../../core/domain/audio/pcm_chunk.dart';
import '../../core/errors/failure.dart';

/// Deterministic capture adapter for application-flow tests.
final class FakeAudioCapture implements AudioCapture {
  FakeAudioCapture({
    this.permissionResult = const PermissionGranted(),
    this.effectiveFormat = const CaptureFormat(sampleRate: 48000, channels: 1),
    this.startFailure,
  });

  PermissionResult permissionResult;
  CaptureFormat effectiveFormat;
  CaptureFailure? startFailure;
  CaptureRequest? lastRequest;
  int startCallCount = 0;
  _FakeCaptureSession? _session;

  @override
  Future<List<CaptureDevice>> listDevices() async => const <CaptureDevice>[
    CaptureDevice(id: 'fake-input', label: 'Fake input'),
  ];

  @override
  Future<PermissionResult> requestPermission() async => permissionResult;

  @override
  Future<CaptureSession> start(CaptureRequest request) async {
    startCallCount += 1;
    lastRequest = request;
    final failure = startFailure;
    if (failure != null) {
      throw failure;
    }
    final session = _FakeCaptureSession(effectiveFormat);
    _session = session;
    return session;
  }

  void emit(PcmChunk chunk) {
    final session = _session;
    if (session == null) {
      throw StateError('Fake capture has not started.');
    }
    session.emit(chunk);
  }

  void emitHealth(CaptureHealth health) {
    final session = _session;
    if (session == null) {
      throw StateError('Fake capture has not started.');
    }
    session.emitHealth(health);
  }
}

final class _FakeCaptureSession implements CaptureSession {
  _FakeCaptureSession(this.effectiveFormat);

  final StreamController<PcmChunk> _chunks =
      StreamController<PcmChunk>.broadcast(sync: true);
  final StreamController<CaptureHealth> _health =
      StreamController<CaptureHealth>.broadcast(sync: true);

  @override
  final CaptureFormat effectiveFormat;

  bool _paused = false;
  bool _stopped = false;

  @override
  Stream<PcmChunk> get pcmChunks => _chunks.stream;

  @override
  Stream<CaptureHealth> get health => _health.stream;

  @override
  Future<void> dispose() => stop();

  void emit(PcmChunk chunk) {
    if (_stopped || _paused) {
      return;
    }
    _chunks.add(chunk);
  }

  void emitHealth(CaptureHealth health) {
    if (!_stopped) {
      _health.add(health);
    }
  }

  @override
  Future<void> pause() async {
    if (!_stopped) {
      _paused = true;
    }
  }

  @override
  Future<void> resume() async {
    if (!_stopped) {
      _paused = false;
    }
  }

  @override
  Future<void> stop() async {
    if (_stopped) {
      return;
    }
    _stopped = true;
    // A broadcast controller's close future can wait for paused listeners.
    // The fake has already stopped emitting, so teardown does not wait on UI.
    unawaited(_chunks.close());
    unawaited(_health.close());
  }
}
