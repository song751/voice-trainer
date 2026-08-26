import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/infrastructure/dsp/web_worker_message_decoder.dart';

void main() {
  const decoder = WebWorkerMessageDecoder();

  test('decodes the bounded dedicated-worker frame and summary DTOs', () {
    final batch = decoder.decodeBatch(jsonEncode(<Object?>[_frame()]));
    expect(batch.frames, hasLength(1));
    expect(batch.frames.single.sampleIndex, 480);
    expect(batch.frames.single.bandPowersDb, hasLength(8));

    final finalization = decoder.decodeFinalization(
      jsonEncode(_summary()),
      batch.frames,
    );
    expect(finalization.featureSeries.frames, hasLength(1));
    expect(finalization.segmentSummary.validFrameCount, 1);
  });

  test('rejects malformed or unknown frame DTO data', () {
    expect(() => decoder.decodeBatch('{}'), throwsFormatException);
    expect(
      () => decoder.decodeBatch(jsonEncode(<Object?>[42])),
      throwsFormatException,
    );
    expect(
      () => decoder.decodeBatch(
        jsonEncode(<Object?>[_frame(qualityFlags: 0x20)]),
      ),
      throwsArgumentError,
    );
    expect(
      () =>
          decoder.decodeBatch(jsonEncode(<Object?>[_frame(bandPowerCount: 9)])),
      throwsArgumentError,
    );
  });

  test('rejects unknown summary quality bits', () {
    expect(
      () => decoder.decodeFinalization(
        jsonEncode(_summary(qualityFlags: 0x20)),
        const [],
      ),
      throwsArgumentError,
    );
  });
}

Map<String, Object?> _frame({int qualityFlags = 0, int bandPowerCount = 8}) =>
    <String, Object?>{
      'startSample': 480,
      'rmsDbfs': -12.0,
      'peakDbfs': -3.0,
      'pitchClarity': 0.9,
      'voiced': true,
      'pitchHz': 220.0,
      'bandPowersDbfs': List<double>.filled(bandPowerCount, -40.0),
      'qualityFlags': qualityFlags,
    };

Map<String, Object?> _summary({int qualityFlags = 0}) => <String, Object?>{
  'startSample': 0,
  'endSample': 960,
  'frameCount': 1,
  'validFrameCount': 1,
  'droppedSamples': 0,
  'qualityFlags': qualityFlags,
  'pitchStability': null,
  'levelStability': null,
  'onsetDelaySamples': null,
};
