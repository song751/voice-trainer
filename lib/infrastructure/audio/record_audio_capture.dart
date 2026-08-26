import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../core/domain/audio/audio_capture.dart';
import '../../core/domain/audio/capture_format.dart';
import '../../core/domain/audio/capture_health.dart';
import '../../core/domain/audio/pcm_chunk.dart';
import '../../core/errors/failure.dart';
import 'capture_metrics_collector.dart';
import 'record_capture_mapper.dart';

final class RecordAudioCapture implements AudioCapture {
  factory RecordAudioCapture({
    RecordClientFactory? clientFactory,
    RecordCaptureMapper mapper = const RecordCaptureMapper(),
    int? fallbackStreamBufferSamples,
  }) => RecordAudioCapture._(
    clientFactory ?? RecordPluginClient.new,
    mapper,
    fallbackStreamBufferSamples,
  );

  RecordAudioCapture._(
    this._clientFactory,
    this._mapper,
    this._fallbackStreamBufferSamples,
  ) : assert(
        _fallbackStreamBufferSamples == null ||
            _fallbackStreamBufferSamples > 0,
      );
  final RecordClientFactory _clientFactory;
  final RecordCaptureMapper _mapper;
  final int? _fallbackStreamBufferSamples;

  @override
  Future<List<CaptureDevice>> listDevices() async {
    final client = _clientFactory();
    try {
      return (await client.listInputDevices())
          .map(_mapper.toCaptureDevice)
          .toList(growable: false);
    } finally {
      await client.dispose();
    }
  }

  @override
  Future<PermissionResult> requestPermission() async {
    final client = _clientFactory();
    try {
      return await client.hasPermission()
          ? const PermissionGranted()
          : const PermissionDenied(PermissionDeniedFailure());
    } finally {
      await client.dispose();
    }
  }

  @override
  Future<CaptureSession> start(CaptureRequest request) async {
    try {
      return await _startOnce(request);
    } on CaptureFailure {
      rethrow;
    } catch (_) {
      final fallback = _fallbackStreamBufferSamples;
      if (fallback == null || request.streamBufferSamples != null) rethrow;
      return _startOnce(_withStreamBuffer(request, fallback));
    }
  }

  Future<CaptureSession> _startOnce(CaptureRequest request) async {
    final client = _clientFactory();
    try {
      final devices = await client.listInputDevices();
      final selected = request.deviceId == null
          ? null
          : devices
                .where((device) => device.id == request.deviceId)
                .firstOrNull;
      if (request.deviceId != null && selected == null) {
        throw const CaptureFailure(CaptureFailureReason.deviceUnavailable);
      }
      final requested = _mapper.toRecordConfig(request, selected);
      final session = _RecordCaptureSession(client, _mapper, requested);
      await session.open();
      return session;
    } catch (_) {
      await client.dispose();
      rethrow;
    }
  }

  CaptureRequest _withStreamBuffer(CaptureRequest request, int samples) =>
      CaptureRequest(
        format: request.format,
        processing: request.processing,
        streamBufferSamples: samples,
        deviceId: request.deviceId,
      );
}

final class _RecordCaptureSession implements CaptureSession {
  _RecordCaptureSession(this._client, this._mapper, this._requested);
  final RecordClient _client;
  final RecordCaptureMapper _mapper;
  final RecordConfig _requested;
  final _chunks = StreamController<PcmChunk>.broadcast();
  final _health = StreamController<CaptureHealth>.broadcast();
  final _metrics = CaptureMetricsCollector();
  final _clock = Stopwatch();
  late CaptureFormat _effectiveFormat;
  StreamSubscription<Uint8List>? _subscription;
  int _sequence = 0;
  int _nextSample = 0;
  bool _closed = false;

  @override
  CaptureFormat get effectiveFormat => _effectiveFormat;
  @override
  Stream<PcmChunk> get pcmChunks => _chunks.stream;
  @override
  Stream<CaptureHealth> get health => _health.stream;

  Future<void> open() async {
    _effectiveFormat = _mapper.toCaptureFormat(_requested);
    await _client.setOnConfigChanged((config) {
      _effectiveFormat = _mapper.toCaptureFormat(config);
      _health.add(
        CaptureHealth(
          effectiveFormat: _effectiveFormat,
          flags: const {CaptureHealthFlag.processingAdjusted},
        ),
      );
    });
    final stream = await _client.startStream(_requested);
    _clock.start();
    _subscription = stream.listen(
      _onChunk,
      onError: _chunks.addError,
      onDone: () {
        if (!_closed) _chunks.close();
      },
    );
  }

  void _onChunk(Uint8List input) {
    if (_closed) {
      return;
    }
    if (input.lengthInBytes.isOdd) {
      _metrics.recordOddBytes();
      _chunks.addError(const CaptureFailure(CaptureFailureReason.invalidPcm));
      return;
    }
    final chunk = PcmChunk(
      sequenceNumber: _sequence++,
      firstSampleIndex: _nextSample,
      format: _effectiveFormat,
      bytes: input,
      captureMonotonicTime: _clock.elapsed,
    );
    _nextSample = chunk.endSampleIndexExclusive;
    final discontinuity = _metrics.add(chunk, _clock.elapsed);
    _chunks.add(chunk);
    if (discontinuity) {
      _health.add(
        CaptureHealth(
          effectiveFormat: _effectiveFormat,
          flags: const {CaptureHealthFlag.discontinuity},
        ),
      );
    }
  }

  @override
  Future<void> pause() => _client.pause();
  @override
  Future<void> resume() async {
    await _client.resume();
    _metrics.ignoreNextIntervalAfterResume();
  }

  @override
  Future<void> stop() => _close();
  @override
  Future<void> dispose() => _close();
  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    await _client.stop();
    await _subscription?.cancel();
    await _client.setOnConfigChanged(null);
    await _client.dispose();
    await _chunks.close();
    await _health.close();
    _clock.stop();
  }
}
