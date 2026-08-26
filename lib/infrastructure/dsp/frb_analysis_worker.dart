import 'dart:typed_data';

import '../../core/domain/analysis/analysis_config.dart';
import '../../core/domain/analysis/analysis_engine.dart';
import '../../core/domain/analysis/analysis_frame.dart' as domain;
import '../../core/domain/analysis/feature_series.dart';
import '../../core/domain/audio/pcm_chunk.dart';
import '../../src/rust/api/realtime.dart';
import '../../src/rust/frb_generated.dart';
import 'analysis_frame_dto_mapper.dart';
import 'analysis_worker_supervisor.dart';
import 'segment_summary_dto_mapper.dart';

/// FRB-backed worker used on native platforms.
///
/// The native FRB configuration retains its worker-pool capability. This
/// Phase 0 API is synchronous; the supervisor keeps calls bounded to 1024
/// samples and serializes them away from capture/UI orchestration.
final class FrbAnalysisWorker implements AnalysisWorker {
  RealtimeAnalyzer? _analyzer;
  final List<domain.AnalysisFrame> _frames = <domain.AnalysisFrame>[];

  @override
  Future<void> initialize(AnalysisConfig config) async {
    await _ensureRustInitialized();
    _analyzer = RealtimeAnalyzer(sampleRate: config.inputFormatSampleRate);
    _frames.clear();
  }

  @override
  Future<domain.AnalysisBatch> pushPcm(PcmBatch batch) async {
    final analyzer = _requireAnalyzer();
    final pcm = Int16List.view(
      batch.bytes.buffer,
      batch.bytes.offsetInBytes,
      batch.bytes.lengthInBytes ~/ Int16List.bytesPerElement,
    );
    final result = analyzer.pushPcm16WithMetadata(
      startSample: BigInt.from(batch.firstSampleIndex),
      pcm: pcm,
      droppedSamplesBefore: batch.droppedSamplesBefore,
      discontinuityBefore: batch.discontinuityBefore,
    );
    final frames = result.map(_mapFrame).toList(growable: false);
    _frames.addAll(frames);
    return domain.AnalysisBatch(frames);
  }

  @override
  Future<AnalysisFinalization> finish() async {
    final summary = _requireAnalyzer().finish();
    return AnalysisFinalization(
      featureSeries: FeatureSeries(frameRateHz: 100, frames: _frames),
      finalFrames: _frames,
      segmentSummary: mapSegmentSummaryDto(summary),
    );
  }

  @override
  Future<void> reset() async {
    _requireAnalyzer().reset();
    _frames.clear();
  }

  @override
  Future<void> dispose() async {
    terminate();
  }

  @override
  void terminate() {
    // RustOpaque is finalized by FRB. Dropping the retained handle releases
    // the DSP buffers promptly without waiting on a failed worker response.
    final analyzer = _analyzer;
    _analyzer = null;
    if (analyzer != null) {
      analyzer.reset();
    }
    _frames.clear();
  }

  domain.AnalysisFrame _mapFrame(AnalysisFrameDto frame) => mapAnalysisFrameDto(
    startSample: frame.startSample.toInt(),
    rmsDbfs: frame.rmsDbfs,
    peakDbfs: frame.peakDbfs,
    pitchClarity: frame.pitchClarity,
    voiced: frame.voiced,
    f0Hz: frame.pitchHz,
    bandPowersDb: frame.bandPowersDbfs,
    qualityFlags: frame.qualityFlags,
  );

  RealtimeAnalyzer _requireAnalyzer() =>
      _analyzer ?? (throw StateError('FRB analyzer is not initialized.'));
}

Future<void>? _rustInitialization;

Future<void> _ensureRustInitialized() async {
  // Generated singleton access is the only FRB 2.12 API that can distinguish
  // app-owned initialization (for example a dedicated probe entrypoint) from
  // the production worker's lazy initialization.
  // ignore: invalid_use_of_internal_member
  if (RustLib.instance.initialized) {
    return;
  }
  final initialization = _rustInitialization ??= RustLib.init();
  try {
    await initialization;
  } catch (_) {
    if (identical(_rustInitialization, initialization)) {
      _rustInitialization = null;
    }
    rethrow;
  }
}
