import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_quality_flag.dart';
import 'package:voice_trainer/features/live_practice/application/ui_frame_decimator.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';

void main() {
  group('UiFrameDecimator', () {
    test('emits at most 25 UI frames for one second of 100 Hz raw frames', () {
      final decimator = UiFrameDecimator(
        target: const PracticeTarget(targetMidiNote: 57),
      );
      final emitted = <int>[];

      for (var index = 0; index < 100; index++) {
        final uiFrame = decimator.add(_frame(sampleIndex: index * 480));
        if (uiFrame != null) {
          emitted.add(uiFrame.sampleIndex);
        }
      }

      expect(emitted, hasLength(25));
      expect(emitted.first, 0);
      expect(emitted.last, 46080);
    });

    test('keeps a fixed raw-pitch ring and retains discontinuity evidence', () {
      final decimator = UiFrameDecimator(
        target: const PracticeTarget(targetMidiNote: 57),
        pitchRingCapacity: 3,
      );

      decimator.add(_frame(sampleIndex: 0));
      decimator.add(_frame(sampleIndex: 480));
      decimator.add(
        _frame(
          sampleIndex: 960,
          qualityFlags: const <AnalysisQualityFlag>{
            AnalysisQualityFlag.discontinuity,
          },
        ),
      );
      final uiFrame = decimator.add(_frame(sampleIndex: 1920));

      expect(uiFrame, isNotNull);
      expect(uiFrame!.pitchHistory, hasLength(3));
      expect(uiFrame.pitchHistory.map((point) => point.sampleIndex), <int>[
        480,
        960,
        1920,
      ]);
      expect(uiFrame.pitchHistory[1].discontinuityBefore, isTrue);
      expect(uiFrame.centsFromTarget, 12);
      expect(uiFrame.isWithinTarget, isTrue);
    });
  });
}

AnalysisFrame _frame({
  required int sampleIndex,
  Set<AnalysisQualityFlag> qualityFlags = const <AnalysisQualityFlag>{},
}) => AnalysisFrame(
  sampleIndex: sampleIndex,
  rmsDbfs: -18,
  peakDbfs: -6,
  pitchClarity: 0.9,
  voiced: true,
  algorithmVersion: 'test',
  f0Hz: 220,
  pitchCents: 5712,
  qualityFlags: qualityFlags,
);
