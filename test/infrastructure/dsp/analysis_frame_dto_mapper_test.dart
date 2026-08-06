import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_quality_flag.dart';
import 'package:voice_trainer/infrastructure/dsp/analysis_frame_dto_mapper.dart';

void main() {
  test('maps the bounded bridge DTO into domain fields', () {
    final frame = mapAnalysisFrameDto(
      startSample: 480,
      rmsDbfs: -18.0,
      peakDbfs: -3.0,
      pitchClarity: 0.92,
      voiced: true,
      f0Hz: 220.0,
      bandPowersDb: List<double>.filled(8, -42.0),
      qualityFlags: 0x09,
    );

    expect(frame.sampleIndex, 480);
    expect(frame.f0Hz, 220.0);
    expect(frame.bandPowersDb, hasLength(8));
    expect(frame.spectrumBinsDb, isEmpty);
    expect(
      frame.qualityFlags,
      containsAll(<AnalysisQualityFlag>[
        AnalysisQualityFlag.clipping,
        AnalysisQualityFlag.discontinuity,
      ]),
    );
  });

  test('rejects an oversized spectrum payload or unknown flag', () {
    expect(
      () => mapAnalysisFrameDto(
        startSample: 0,
        rmsDbfs: -120,
        peakDbfs: -120,
        pitchClarity: 0,
        voiced: false,
        bandPowersDb: List<double>.filled(9, -120),
        qualityFlags: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => mapAnalysisFrameDto(
        startSample: 0,
        rmsDbfs: -120,
        peakDbfs: -120,
        pitchClarity: 0,
        voiced: false,
        bandPowersDb: List<double>.filled(8, -120),
        qualityFlags: 0x20,
      ),
      throwsArgumentError,
    );
  });
}
