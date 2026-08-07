import 'dart:typed_data';

import '../../core/domain/analysis/analysis_config.dart';
import '../../core/domain/analysis/analysis_engine.dart';
import '../../core/domain/analysis/analysis_frame.dart';
import '../../core/domain/audio/capture_format.dart';
import '../../core/domain/audio/pcm_chunk.dart';
import '../../core/errors/failure.dart';
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
  AnalysisConfig? _config;
  int? _nextInputSampleIndex;

  @override
  AnalysisWorkerMetrics get workerMetrics => _supervisor.metrics;

  @override
  Stream<AnalysisWorkerMetrics> get workerMetricsStream =>
      _supervisor.metricsStream;

  @override
  Future<void> initialize(AnalysisConfig config) async {
    _validateSupportedFormat(config.inputFormat);
    await _supervisor.initialize(config);
    _config = config;
    _nextInputSampleIndex = null;
  }

  @override
  Future<AnalysisBatch> pushPcm(PcmBatch batch) async {
    final config =
        _config ??
        (throw StateError('Rust analysis engine is not initialized.'));
    _validateBatch(batch, config);
    final maximum = _bridgeBatchSamples;
    if (batch.frameCount <= maximum) {
      final result = await _supervisor.pushPcm(batch);
      _nextInputSampleIndex = batch.firstSampleIndex + batch.frameCount;
      return result;
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
          droppedSamplesBefore: offsetFrames == 0
              ? batch.droppedSamplesBefore
              : 0,
          discontinuityBefore: offsetFrames == 0 && batch.discontinuityBefore,
        ),
      );
      frames.addAll(result.frames);
    }
    _nextInputSampleIndex = batch.firstSampleIndex + batch.frameCount;
    return AnalysisBatch(frames);
  }

  // The supervisor validates against the initialized config.  The v1 contract
  // fixes 1024 as the only message size sent to the bridge/worker.
  int get _bridgeBatchSamples => 1024;

  @override
  Future<AnalysisFinalization> finish() => _supervisor.finish();

  @override
  Future<void> reset() async {
    await _supervisor.reset();
    _nextInputSampleIndex = null;
  }

  @override
  Future<void> dispose() => _supervisor.dispose();

  void _validateBatch(PcmBatch batch, AnalysisConfig config) {
    if (batch.format != config.inputFormat) {
      throw const AnalysisFailure(AnalysisFailureReason.formatChanged);
    }
    if (!batch.isFrameAligned) {
      throw const AnalysisFailure(AnalysisFailureReason.invalidPcm);
    }
    final expected = _nextInputSampleIndex;
    if (expected != null && batch.firstSampleIndex < expected) {
      throw const AnalysisFailure(
        AnalysisFailureReason.nonMonotonicSampleIndex,
      );
    }
  }

  void _validateSupportedFormat(CaptureFormat format) {
    if (format.sampleRate != 48000 ||
        format.channels != 1 ||
        format.encoding != PcmEncoding.signedPcm16LittleEndian) {
      throw const AnalysisFailure(AnalysisFailureReason.unsupportedFormat);
    }
  }
}
