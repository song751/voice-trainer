import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/metrics/p3_performance_observer.dart';

void main() {
  test('correlates capture to analysis with bounded quantiles', () {
    var now = Duration.zero;
    final observer = P3PerformanceObserver.enabled(clock: () => now);
    observer.onCaptureChunk(_chunk(0, Duration.zero));
    now = const Duration(milliseconds: 12);
    observer.onAnalysisPublished(_frame(0));
    observer.onCaptureChunk(_chunk(4, const Duration(milliseconds: 20)));
    now = const Duration(milliseconds: 36);
    observer.onAnalysisPublished(_frame(4));
    observer.onUiFrameTiming(
      build: const Duration(milliseconds: 3),
      raster: const Duration(milliseconds: 5),
    );
    observer.sampleMemory(workingSetMib: 100, privateMib: 80);
    observer.onQueueAccounting(
      analysisDroppedSamples: 4,
      recordingDroppedSamples: 0,
    );

    final snapshot = observer.snapshot();
    expect(snapshot.pipelineLatency.p50, 16);
    expect(snapshot.pipelineLatency.p95, 16);
    expect(snapshot.uiBuild.p95, 3);
    expect(snapshot.uiRaster.p95, 5);
    expect(snapshot.analysisQueueDroppedSamples, 4);
    expect(snapshot.memorySamples, hasLength(1));
  });

  test('disabled observer retains no frame or memory measurements', () {
    final observer = P3PerformanceObserver.disabled();
    observer.onCaptureChunk(_chunk(0, Duration.zero));
    observer.onAnalysisPublished(_frame(0));
    observer.sampleMemory(workingSetMib: 100, privateMib: 80);

    expect(observer.snapshot().pipelineLatency.count, 0);
    expect(observer.snapshot().memorySamples, isEmpty);
  });
}

PcmChunk _chunk(int sample, Duration timestamp) => PcmChunk(
  sequenceNumber: sample,
  firstSampleIndex: sample,
  format: const CaptureFormat(sampleRate: 48000, channels: 1),
  bytes: Uint8List(8),
  captureMonotonicTime: timestamp,
);

AnalysisFrame _frame(int sample) => AnalysisFrame(
  sampleIndex: sample,
  rmsDbfs: -10,
  peakDbfs: -5,
  pitchClarity: 1,
  voiced: true,
  algorithmVersion: 'test',
);
