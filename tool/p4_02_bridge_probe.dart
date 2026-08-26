import 'dart:math' as math;
import 'dart:typed_data';

import 'package:voice_trainer/core/domain/analysis/analysis_config.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/infrastructure/dsp/frb_analysis_worker.dart';
import 'package:voice_trainer/src/rust/api/simple.dart';

const p402ProbeFormat = CaptureFormat(sampleRate: 48000, channels: 1);
const _batchSize = 1024;
const _totalSamples = 48000;

final class P402BridgeProbeResult {
  const P402BridgeProbeResult({
    required this.greeting,
    required this.frameCount,
    required this.sampleChecksum,
    required this.rmsChecksum,
    required this.pitchChecksum,
    required this.hasBoundedDtos,
    required this.hasConsistentVoicing,
  });

  final String greeting;
  final int frameCount;
  final int sampleChecksum;
  final double rmsChecksum;
  final double pitchChecksum;
  final bool hasBoundedDtos;
  final bool hasConsistentVoicing;

  bool get matchesExpectedContract =>
      greeting == 'Hello, Android!' &&
      frameCount == 94 &&
      sampleChecksum == 2098080 &&
      (rmsChecksum - -868.26486).abs() <= 0.001 &&
      (pitchChecksum - 20681.109375).abs() <= 0.001 &&
      hasBoundedDtos &&
      hasConsistentVoicing;
}

Future<P402BridgeProbeResult> runP402BridgeProbe() async {
  final worker = FrbAnalysisWorker();
  try {
    await worker.initialize(const AnalysisConfig(inputFormat: p402ProbeFormat));

    final frames = <AnalysisFrame>[];
    for (var start = 0; start < _totalSamples; start += _batchSize) {
      final count = math.min(_batchSize, _totalSamples - start);
      final pcm = Int16List.fromList(
        List<int>.generate(count, (offset) {
          final phase =
              math.pi * 2 * 220 * (start + offset) / p402ProbeFormat.sampleRate;
          return (math.sin(phase) * 16000).truncate();
        }, growable: false),
      );
      frames.addAll(
        (await worker.pushPcm(
          PcmBatch(
            firstSampleIndex: start,
            format: p402ProbeFormat,
            bytes: Uint8List.view(pcm.buffer),
          ),
        )).frames,
      );
    }

    final finalFrames = (await worker.finish()).finalFrames;
    return P402BridgeProbeResult(
      greeting: greet(name: 'Android'),
      frameCount: frames.length,
      sampleChecksum: frames.fold<int>(
        0,
        (sum, frame) => sum + frame.sampleIndex,
      ),
      rmsChecksum: frames.fold<double>(0, (sum, frame) => sum + frame.rmsDbfs),
      pitchChecksum: frames.fold<double>(
        0,
        (sum, frame) => sum + (frame.f0Hz ?? 0),
      ),
      hasBoundedDtos: frames.every(
        (frame) =>
            frame.bandPowersDb.length == 8 && frame.spectrumBinsDb.isEmpty,
      ),
      hasConsistentVoicing:
          finalFrames.length == frames.length &&
          frames.every((frame) => frame.voiced == (frame.f0Hz != null)),
    );
  } finally {
    await worker.dispose();
  }
}
