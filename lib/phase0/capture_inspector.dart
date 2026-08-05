import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:record/record.dart';

import 'capture_artifact_writer.dart';

const captureSampleRate = 48000;
const captureChannels = 1;
const captureBytesPerSample = 2;

class CaptureInspectorOptions {
  const CaptureInspectorOptions({
    this.captureDuration = const Duration(seconds: 60),
    this.pauseAfter,
    this.pauseDuration = const Duration(seconds: 20),
    this.streamBufferSize = 1024,
    this.deviceId,
  });

  final Duration captureDuration;
  final Duration? pauseAfter;
  final Duration pauseDuration;
  final int streamBufferSize;
  final String? deviceId;
}

class WavInspection {
  const WavInspection({
    required this.riff,
    required this.wave,
    required this.audioFormat,
    required this.numChannels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.dataBytes,
    required this.durationSeconds,
  });

  final String riff;
  final String wave;
  final int audioFormat;
  final int numChannels;
  final int sampleRate;
  final int bitsPerSample;
  final int dataBytes;
  final double durationSeconds;

  Map<String, Object> toJson() => {
    'riff': riff,
    'wave': wave,
    'audioFormat': audioFormat,
    'numChannels': numChannels,
    'sampleRate': sampleRate,
    'bitsPerSample': bitsPerSample,
    'dataBytes': dataBytes,
    'durationSeconds': durationSeconds,
  };
}

class CaptureInspectorReport {
  const CaptureInspectorReport(this.values);

  final Map<String, Object?> values;

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(values);

  String toCompactJson() => jsonEncode(values);
}

class CaptureInspector {
  CaptureInspector({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  Future<List<InputDevice>> listDevices() => _recorder.listInputDevices();

  Future<CaptureInspectorReport> run(CaptureInspectorOptions options) async {
    if (options.captureDuration <= Duration.zero) {
      throw ArgumentError.value(options.captureDuration, 'captureDuration');
    }
    if (options.streamBufferSize <= 0) {
      throw ArgumentError.value(options.streamBufferSize, 'streamBufferSize');
    }

    final granted = await _recorder.hasPermission();
    if (!granted) {
      throw StateError('Microphone permission was not granted.');
    }

    final devices = await _recorder.listInputDevices();
    final requestedDevice = options.deviceId == null
        ? null
        : devices.where((device) => device.id == options.deviceId).firstOrNull;
    if (options.deviceId != null && requestedDevice == null) {
      throw StateError(
        'Requested input device was not found: ${options.deviceId}',
      );
    }

    final requested = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: captureSampleRate,
      numChannels: captureChannels,
      device: requestedDevice,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
      streamBufferSize: options.streamBufferSize,
    );
    var effective = requested;
    var effectiveWasAdjusted = false;
    await _recorder.setOnConfigChanged((config) {
      effective = config;
      effectiveWasAdjusted = true;
    });

    final chunks = <Uint8List>[];
    final chunkBytes = <int>[];
    final chunkSamples = <int>[];
    final arrivalIntervalsUs = <int>[];
    final callbackWorkUs = <int>[];
    final captureClock = Stopwatch()..start();
    int? firstChunkUs;
    int? previousChunkUs;
    var discontinuityCount = 0;
    var oddByteChunkCount = 0;
    var ignoreNextInterval = false;
    var paused = false;
    Object? streamError;
    StackTrace? streamStack;
    final firstChunkReady = Completer<void>();

    final stream = await _recorder.startStream(requested);
    final startLatencyUs = captureClock.elapsedMicroseconds;
    late final StreamSubscription<Uint8List> subscription;
    final streamDone = Completer<void>();
    subscription = stream.listen(
      (chunk) {
        final workClock = Stopwatch()..start();
        final arrivalUs = captureClock.elapsedMicroseconds;
        firstChunkUs ??= arrivalUs;
        if (!firstChunkReady.isCompleted) firstChunkReady.complete();
        if (chunk.lengthInBytes.isOdd) {
          oddByteChunkCount++;
        }
        final safeLength = chunk.lengthInBytes - (chunk.lengthInBytes % 2);
        final owned = Uint8List.fromList(chunk.sublist(0, safeLength));
        chunks.add(owned);
        chunkBytes.add(owned.lengthInBytes);
        final samples =
            owned.lengthInBytes ~/ captureBytesPerSample ~/ captureChannels;
        chunkSamples.add(samples);

        final previous = previousChunkUs;
        if (previous != null && !paused && !ignoreNextInterval) {
          final intervalUs = arrivalUs - previous;
          arrivalIntervalsUs.add(intervalUs);
          final expectedUs =
              samples * Duration.microsecondsPerSecond ~/ effective.sampleRate;
          final discontinuityThresholdUs = math.max(100000, expectedUs * 3);
          if (intervalUs > discontinuityThresholdUs) {
            discontinuityCount++;
          }
        }
        ignoreNextInterval = false;
        previousChunkUs = arrivalUs;
        workClock.stop();
        callbackWorkUs.add(workClock.elapsedMicroseconds);
      },
      onError: (Object error, StackTrace stack) {
        streamError = error;
        streamStack = stack;
      },
      onDone: () {
        if (!streamDone.isCompleted) streamDone.complete();
      },
      cancelOnError: false,
    );

    var pauseLatencyUs = 0;
    var resumeLatencyUs = 0;
    var stopLatencyUs = 0;
    final pauseAfter = options.pauseAfter;
    try {
      await firstChunkReady.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException(
          'No PCM chunk arrived within five seconds after startStream.',
        ),
      );
      if (pauseAfter != null && pauseAfter < options.captureDuration) {
        await Future<void>.delayed(pauseAfter);
        final pauseClock = Stopwatch()..start();
        await _recorder.pause();
        pauseClock.stop();
        pauseLatencyUs = pauseClock.elapsedMicroseconds;
        paused = true;
        await Future<void>.delayed(options.pauseDuration);
        final resumeClock = Stopwatch()..start();
        await _recorder.resume();
        resumeClock.stop();
        resumeLatencyUs = resumeClock.elapsedMicroseconds;
        paused = false;
        ignoreNextInterval = true;
        await Future<void>.delayed(options.captureDuration - pauseAfter);
      } else {
        await Future<void>.delayed(options.captureDuration);
      }
    } finally {
      final stopClock = Stopwatch()..start();
      await _recorder.stop();
      stopClock.stop();
      stopLatencyUs = stopClock.elapsedMicroseconds;
      await Future.any<void>([
        streamDone.future,
        Future<void>.delayed(const Duration(milliseconds: 500)),
      ]);
      await subscription.cancel();
      await _recorder.setOnConfigChanged(null);
      await _recorder.dispose();
      captureClock.stop();
    }
    if (streamError != null) {
      Error.throwWithStackTrace(
        streamError!,
        streamStack ?? StackTrace.current,
      );
    }

    final pcmBytes = _concatenate(chunks);
    final totalSamples =
        pcmBytes.lengthInBytes ~/ captureBytesPerSample ~/ captureChannels;
    final wavBytes = buildPcm16Wav(
      pcmBytes,
      sampleRate: effective.sampleRate,
      channels: effective.numChannels,
    );
    final wav = inspectPcm16Wav(wavBytes);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final artifactPath = await writeCaptureArtifact(
      wavBytes,
      'voice_trainer_phase0_$stamp.wav',
    );
    final expectedSamples =
        options.captureDuration.inMicroseconds *
        effective.sampleRate /
        Duration.microsecondsPerSecond;
    final sampleErrorPercent = expectedSamples == 0
        ? 0.0
        : (totalSamples - expectedSamples).abs() / expectedSamples * 100;
    final wavVsSamplesErrorPercent = totalSamples == 0
        ? 0.0
        : (wav.durationSeconds * effective.sampleRate - totalSamples).abs() /
              totalSamples *
              100;

    return CaptureInspectorReport({
      'schema': 'voice-trainer.capture-inspector.v1',
      'requestedConfig': _configJson(requested),
      'effectiveConfig': _configJson(effective),
      'effectiveConfigSource': effectiveWasAdjusted
          ? 'platform-adjusted-callback'
          : 'requested-accepted-no-change-callback',
      'devices': devices.map(_deviceJson).toList(growable: false),
      'selectedDeviceId': requestedDevice?.id ?? 'default',
      'targetActiveDurationSeconds':
          options.captureDuration.inMicroseconds /
          Duration.microsecondsPerSecond,
      'pauseDurationSeconds': pauseAfter == null
          ? 0.0
          : options.pauseDuration.inMicroseconds /
                Duration.microsecondsPerSecond,
      'chunkCount': chunkBytes.length,
      'chunkBytes': _stats(chunkBytes),
      'chunkSamples': _stats(chunkSamples),
      'arrivalIntervalMs': _stats(arrivalIntervalsUs, scale: 0.001),
      'callbackWorkUs': _stats(callbackWorkUs),
      'totalPcmBytes': pcmBytes.lengthInBytes,
      'totalSamples': totalSamples,
      'expectedSamplesFromTargetWall': expectedSamples.round(),
      'sampleCountErrorPercent': sampleErrorPercent,
      'oddByteChunkCount': oddByteChunkCount,
      'discontinuityProxyCount': discontinuityCount,
      'latencyMs': {
        'startStream': startLatencyUs / 1000,
        'firstChunkFromStart': (firstChunkUs ?? -1) / 1000,
        'pause': pauseLatencyUs / 1000,
        'resume': resumeLatencyUs / 1000,
        'stop': stopLatencyUs / 1000,
      },
      'wav': wav.toJson(),
      'wavVsSampleCountErrorPercent': wavVsSamplesErrorPercent,
      'wavSha256': sha256.convert(wavBytes).toString(),
      'wavArtifactPath': artifactPath ?? 'memory-only',
    });
  }
}

Uint8List buildPcm16Wav(
  Uint8List pcmBytes, {
  required int sampleRate,
  required int channels,
}) {
  if (pcmBytes.lengthInBytes.isOdd) {
    throw ArgumentError('PCM16 payload must contain an even number of bytes.');
  }
  final bytes = Uint8List(44 + pcmBytes.lengthInBytes);
  final view = ByteData.sublistView(bytes);
  void ascii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes[offset + index] = value.codeUnitAt(index);
    }
  }

  const bitsPerSample = 16;
  final blockAlign = channels * bitsPerSample ~/ 8;
  ascii(0, 'RIFF');
  view.setUint32(4, bytes.lengthInBytes - 8, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, channels, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, sampleRate * blockAlign, Endian.little);
  view.setUint16(32, blockAlign, Endian.little);
  view.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  view.setUint32(40, pcmBytes.lengthInBytes, Endian.little);
  bytes.setRange(44, bytes.lengthInBytes, pcmBytes);
  return bytes;
}

WavInspection inspectPcm16Wav(Uint8List bytes) {
  if (bytes.lengthInBytes < 44) {
    throw const FormatException('WAV is shorter than 44 bytes.');
  }
  final view = ByteData.sublistView(bytes);
  String ascii(int offset, int length) =>
      String.fromCharCodes(bytes.sublist(offset, offset + length));
  final dataBytes = view.getUint32(40, Endian.little);
  if (dataBytes + 44 != bytes.lengthInBytes) {
    throw const FormatException(
      'WAV data length does not match the file length.',
    );
  }
  final sampleRate = view.getUint32(24, Endian.little);
  final channels = view.getUint16(22, Endian.little);
  final bitsPerSample = view.getUint16(34, Endian.little);
  return WavInspection(
    riff: ascii(0, 4),
    wave: ascii(8, 4),
    audioFormat: view.getUint16(20, Endian.little),
    numChannels: channels,
    sampleRate: sampleRate,
    bitsPerSample: bitsPerSample,
    dataBytes: dataBytes,
    durationSeconds: dataBytes / (sampleRate * channels * (bitsPerSample / 8)),
  );
}

Uint8List _concatenate(List<Uint8List> chunks) {
  final total = chunks.fold<int>(0, (sum, chunk) => sum + chunk.lengthInBytes);
  final output = Uint8List(total);
  var offset = 0;
  for (final chunk in chunks) {
    output.setRange(offset, offset + chunk.lengthInBytes, chunk);
    offset += chunk.lengthInBytes;
  }
  return output;
}

Map<String, Object?> _configJson(RecordConfig config) => {
  'encoder': config.encoder.name,
  'sampleRate': config.sampleRate,
  'numChannels': config.numChannels,
  'streamBufferSize': config.streamBufferSize,
  'autoGain': config.autoGain,
  'echoCancel': config.echoCancel,
  'noiseSuppress': config.noiseSuppress,
  'deviceId': config.device?.id ?? 'default',
};

Map<String, Object> _deviceJson(InputDevice device) => {
  'id': device.id,
  'label': device.label,
  'type': device.type.name,
  'sampleRates': device.sampleRates,
};

Map<String, num> _stats(List<int> values, {double scale = 1}) {
  if (values.isEmpty) {
    return {'count': 0, 'min': 0, 'median': 0, 'p95': 0, 'max': 0};
  }
  final sorted = List<int>.from(values)..sort();
  num percentile(double fraction) {
    final index = ((sorted.length - 1) * fraction).ceil();
    return sorted[index] * scale;
  }

  return {
    'count': sorted.length,
    'min': sorted.first * scale,
    'median': percentile(0.5),
    'p95': percentile(0.95),
    'max': sorted.last * scale,
  };
}
