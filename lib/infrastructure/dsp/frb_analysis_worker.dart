import 'dart:math';
import 'dart:typed_data';

import '../../core/domain/analysis/analysis_config.dart';
import '../../core/domain/analysis/analysis_engine.dart';
import '../../core/domain/analysis/analysis_frame.dart' as domain;
import '../../core/domain/analysis/feature_series.dart';
import '../../core/domain/audio/pcm_chunk.dart';
import '../../src/rust/api/realtime.dart';
import '../../src/rust/model.dart' as rust;
import 'analysis_worker_supervisor.dart';

/// FRB-backed worker used on native platforms.
///
/// The native FRB configuration retains its worker-pool capability. This
/// Phase 0 API is synchronous; the supervisor keeps calls bounded to 1024
/// samples and serializes them away from capture/UI orchestration.
final class FrbAnalysisWorker implements AnalysisWorker {
  RealtimeAnalyzer? _analyzer;
  final List<domain.AnalysisFrame> _frames = <domain.AnalysisFrame>[];
  int? _originSampleIndex;
  int? _nextInputSampleIndex;

  @override
  Future<void> initialize(AnalysisConfig config) async {
    _analyzer = RealtimeAnalyzer(sampleRate: config.inputFormatSampleRate);
    _frames.clear();
    _originSampleIndex = null;
    _nextInputSampleIndex = null;
  }

  @override
  Future<domain.AnalysisBatch> pushPcm(PcmBatch batch) async {
    final analyzer = _requireAnalyzer();
    if (_nextInputSampleIndex != null &&
        batch.firstSampleIndex != _nextInputSampleIndex) {
      analyzer.reset();
      _originSampleIndex = batch.firstSampleIndex;
    }
    _originSampleIndex ??= batch.firstSampleIndex;
    _nextInputSampleIndex = batch.firstSampleIndex + batch.frameCount;
    final pcm = Int16List.view(
      batch.bytes.buffer,
      batch.bytes.offsetInBytes,
      batch.bytes.lengthInBytes ~/ Int16List.bytesPerElement,
    );
    final result = analyzer.pushPcm16(pcm: pcm);
    final frames = result
        .map((frame) => _mapFrame(frame, _originSampleIndex!))
        .toList(growable: false);
    _frames.addAll(frames);
    return domain.AnalysisBatch(frames);
  }

  @override
  Future<AnalysisFinalization> finish() async => AnalysisFinalization(
    featureSeries: FeatureSeries(frameRateHz: 100, frames: _frames),
    finalFrames: _frames,
  );

  @override
  Future<void> reset() async {
    _requireAnalyzer().reset();
    _frames.clear();
    _originSampleIndex = null;
    _nextInputSampleIndex = null;
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

  domain.AnalysisFrame _mapFrame(rust.AnalysisFrame frame, int origin) {
    final pitch = frame.pitchHz;
    return domain.AnalysisFrame(
      sampleIndex: origin + frame.startSample.toInt(),
      rmsDbfs: _dbfs(frame.rms),
      peakDbfs: _dbfs(frame.peak),
      pitchClarity: frame.pitchClarity,
      voiced: pitch != null,
      algorithmVersion: 'phase0-autocorrelation-v1',
      f0Hz: pitch,
    );
  }

  RealtimeAnalyzer _requireAnalyzer() =>
      _analyzer ?? (throw StateError('FRB analyzer is not initialized.'));

  double _dbfs(double amplitude) =>
      amplitude <= 0 ? -160 : max(-160, 20 * (log(amplitude) / ln10));
}
