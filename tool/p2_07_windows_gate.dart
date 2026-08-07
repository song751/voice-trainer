import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:voice_trainer/core/domain/analysis/analysis_config.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/infrastructure/dsp/frb_analysis_worker.dart';
import 'package:voice_trainer/src/rust/frb_generated.dart';

const _sampleRate = 48000;
const _batchSize = 1024;
const _totalSamples = _sampleRate;
const _format = CaptureFormat(sampleRate: _sampleRate, channels: 1);

Future<void> main() async {
  await RustLib.init();
  final worker = FrbAnalysisWorker();
  await worker.initialize(
    const AnalysisConfig(
      inputFormat: CaptureFormat(sampleRate: _sampleRate, channels: 1),
    ),
  );
  var frameCount = 0;
  var startSampleChecksum = 0;
  var rmsChecksum = 0.0;
  var pitchChecksum = 0.0;
  var maxBandPowers = 0;
  var qualityFrameCount = 0;
  try {
    for (var start = 0; start < _totalSamples; start += _batchSize) {
      final count = math.min(_batchSize, _totalSamples - start);
      final pcm = Int16List.fromList(
        List<int>.generate(count, (offset) {
          final phase = math.pi * 2 * 220 * (start + offset) / _sampleRate;
          return (math.sin(phase) * 16000).truncate();
        }, growable: false),
      );
      final frames = (await worker.pushPcm(
        PcmBatch(
          firstSampleIndex: start,
          format: _format,
          bytes: Uint8List.view(pcm.buffer),
        ),
      )).frames;
      for (final frame in frames) {
        if (frame.bandPowersDb.length != 8 || frame.spectrumBinsDb.isNotEmpty) {
          throw StateError(
            'Native bridge payload is not bounded to eight bands.',
          );
        }
        if (frame.voiced != (frame.f0Hz != null)) {
          throw StateError('Native voiced state disagrees with optional F0.');
        }
        frameCount++;
        startSampleChecksum += frame.sampleIndex;
        rmsChecksum += frame.rmsDbfs;
        pitchChecksum += frame.f0Hz ?? 0;
        maxBandPowers = math.max(maxBandPowers, frame.bandPowersDb.length);
        if (frame.qualityFlags.isNotEmpty) qualityFrameCount++;
      }
    }
    // ignore: avoid_print
    print(
      jsonEncode(<String, Object>{
        'sampleRate': _sampleRate,
        'totalSamples': _totalSamples,
        'batchSize': _batchSize,
        'frameCount': frameCount,
        'startSampleChecksum': startSampleChecksum,
        'rmsChecksum': rmsChecksum,
        'pitchChecksum': pitchChecksum,
        'maxBandPowers': maxBandPowers,
        'qualityFrameCount': qualityFrameCount,
      }),
    );
  } finally {
    await worker.dispose();
  }
  exit(0);
}
