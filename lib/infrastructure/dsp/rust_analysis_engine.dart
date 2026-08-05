import 'dart:typed_data';

import '../../core/domain/analysis/analysis_config.dart';
import '../../core/domain/analysis/analysis_engine.dart';
import '../../core/domain/analysis/analysis_frame.dart';
import '../../core/domain/audio/pcm_chunk.dart';
import 'analysis_worker_supervisor.dart';
import 'platform_analysis_worker.dart';

/// Formal application adapter for the Phase 0 `RealtimeAnalyzer`.
///
/// Capture-sized chunks are split into the accepted 1024-sample bridge batches
/// before they reach either FRB or the browser Worker.
final class RustAnalysisEngine implements AnalysisEngine {
  RustAnalysisEngine({
    AnalysisWorkerFactory? primaryWorkerFactory,
    AnalysisWorkerFactory? fallbackWorkerFactory,
    int maxQueuedSamples = 12000,
  }) : _supervisor = AnalysisWorkerSupervisor(
         primaryWorkerFactory:
             primaryWorkerFactory ?? createPrimaryAnalysisWorker,
         fallbackWorkerFactory:
             fallbackWorkerFactory ?? createFallbackAnalysisWorker,
         maxQueuedSamples: maxQueuedSamples,
       );

  final AnalysisWorkerSupervisor _supervisor;

  AnalysisWorkerMetrics get workerMetrics => _supervisor.metrics;

  @override
  Future<void> initialize(AnalysisConfig config) =>
      _supervisor.initialize(config);

  @override
  Future<AnalysisBatch> pushPcm(PcmBatch batch) async {
    final maximum = _bridgeBatchSamples;
    if (batch.frameCount <= maximum) {
      return _supervisor.pushPcm(batch);
    }
    final frames = <AnalysisFrame>[];
    for (
      var offsetFrames = 0;
      offsetFrames < batch.frameCount;
      offsetFrames += maximum
    ) {
      final frameCount = (batch.frameCount - offsetFrames).clamp(0, maximum);
      final byteOffset = offsetFrames * batch.format.bytesPerFrame;
      final byteLength = frameCount * batch.format.bytesPerFrame;
      final result = await _supervisor.pushPcm(
        PcmBatch(
          firstSampleIndex: batch.firstSampleIndex + offsetFrames,
          format: batch.format,
          bytes: Uint8List.fromList(
            batch.bytes.sublist(byteOffset, byteOffset + byteLength),
          ),
        ),
      );
      frames.addAll(result.frames);
    }
    return AnalysisBatch(frames);
  }

  // The supervisor validates against the initialized config.  The v1 contract
  // fixes 1024 as the only message size sent to the bridge/worker.
  int get _bridgeBatchSamples => 1024;

  @override
  Future<AnalysisFinalization> finish() => _supervisor.finish();

  @override
  Future<void> reset() => _supervisor.reset();

  @override
  Future<void> dispose() => _supervisor.dispose();
}
