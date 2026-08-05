import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/phase0/capture_inspector.dart';

void main() {
  test('PCM16 WAV header and duration agree with sample count', () {
    final pcm = Uint8List(captureSampleRate * captureBytesPerSample);
    final wav = buildPcm16Wav(
      pcm,
      sampleRate: captureSampleRate,
      channels: captureChannels,
    );
    final inspected = inspectPcm16Wav(wav);

    expect(inspected.riff, 'RIFF');
    expect(inspected.wave, 'WAVE');
    expect(inspected.audioFormat, 1);
    expect(inspected.numChannels, 1);
    expect(inspected.sampleRate, 48000);
    expect(inspected.bitsPerSample, 16);
    expect(inspected.dataBytes, pcm.lengthInBytes);
    expect(inspected.durationSeconds, 1.0);
  });

  test('PCM16 WAV writer rejects partial samples', () {
    expect(
      () => buildPcm16Wav(
        Uint8List(3),
        sampleRate: captureSampleRate,
        channels: captureChannels,
      ),
      throwsArgumentError,
    );
  });
}
