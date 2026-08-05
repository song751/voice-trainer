import 'dart:convert';
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
    const AnalysisConfig(inputFormatSampleRate: _sampleRate),
  );

  var frameCount = 0;
  var startSampleChecksum = 0;
  var rmsChecksum = 0.0;
  var pitchChecksum = 0.0;
  try {
    for (var start = 0; start < _totalSamples; start += _batchSize) {
      final count = math.min(_batchSize, _totalSamples - start);
      final pcm = Int16List.fromList(
        List<int>.generate(count, (offset) {
          final phase = math.pi * 2 * 220 * (start + offset) / _sampleRate;
          return (math.sin(phase) * 16000).truncate();
        }, growable: false),
      );
      final batch = PcmBatch(
        firstSampleIndex: start,
        format: _format,
        bytes: Uint8List.view(pcm.buffer),
      );
      for (final frame in (await worker.pushPcm(batch)).frames) {
        frameCount++;
        startSampleChecksum += frame.sampleIndex;
        rmsChecksum += frame.rmsDbfs;
        pitchChecksum += frame.f0Hz ?? 0;
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
      }),
    );
  } finally {
    await worker.dispose();
  }
}
