import 'dart:convert';
import 'dart:js_interop';

import '../../core/domain/analysis/analysis_config.dart';
import '../../core/domain/analysis/analysis_engine.dart';
import '../../core/domain/analysis/analysis_frame.dart';
import '../../core/domain/analysis/feature_series.dart';
import '../../core/domain/audio/pcm_chunk.dart';
import 'analysis_frame_dto_mapper.dart';
import 'analysis_worker_supervisor.dart';

@JS('VoiceTrainerAnalysisWorker')
extension type _WebWorkerClient._(JSObject _) implements JSObject {
  external factory _WebWorkerClient();

  external JSPromise<JSString> initialize(int sampleRate);
  external JSPromise<JSString> pushPcm(JSUint8Array pcm);
  external JSPromise<JSString> reset();
  external JSPromise<JSString> dispose();
  external void terminate();
}

/// Dedicated browser Worker client. The JavaScript counterpart transfers a
/// PCM16 ArrayBuffer and sends back only the compact Phase 2 frame DTO.
final class WebWorkerAnalysisWorker implements AnalysisWorker {
  final _WebWorkerClient _client = _WebWorkerClient();
  final List<AnalysisFrame> _frames = <AnalysisFrame>[];
  int? _originSampleIndex;
  int? _nextInputSampleIndex;

  @override
  Future<void> initialize(AnalysisConfig config) async {
    await _client.initialize(config.inputFormatSampleRate).toDart;
    _frames.clear();
    _originSampleIndex = null;
    _nextInputSampleIndex = null;
  }

  @override
  Future<AnalysisBatch> pushPcm(PcmBatch batch) async {
    if (_nextInputSampleIndex != null &&
        batch.firstSampleIndex != _nextInputSampleIndex) {
      await _client.reset().toDart;
      _originSampleIndex = batch.firstSampleIndex;
    }
    _originSampleIndex ??= batch.firstSampleIndex;
    _nextInputSampleIndex = batch.firstSampleIndex + batch.frameCount;
    final raw = (await _client.pushPcm(batch.bytes.toJS).toDart).toDart;
    final decoded = jsonDecode(raw) as List<dynamic>;
    final frames = decoded
        .cast<Map<String, dynamic>>()
        .map((frame) => _mapFrame(frame, _originSampleIndex!))
        .toList(growable: false);
    _frames.addAll(frames);
    return AnalysisBatch(frames);
  }

  @override
  Future<AnalysisFinalization> finish() async => AnalysisFinalization(
    featureSeries: FeatureSeries(frameRateHz: 100, frames: _frames),
    finalFrames: _frames,
  );

  @override
  Future<void> reset() async {
    await _client.reset().toDart;
    _frames.clear();
    _originSampleIndex = null;
    _nextInputSampleIndex = null;
  }

  @override
  Future<void> dispose() async {
    // Disposal normally gives the worker a chance to close itself. The
    // supervisor uses [terminate] when a request is hung or crashed.
    await _client.dispose().toDart;
    _frames.clear();
  }

  @override
  void terminate() {
    _client.terminate();
    _frames.clear();
    _originSampleIndex = null;
    _nextInputSampleIndex = null;
  }

  AnalysisFrame _mapFrame(Map<String, dynamic> frame, int origin) =>
      mapAnalysisFrameDto(
        startSample: origin + (frame['startSample'] as num).toInt(),
        rmsDbfs: (frame['rmsDbfs'] as num).toDouble(),
        peakDbfs: (frame['peakDbfs'] as num).toDouble(),
        pitchClarity: (frame['pitchClarity'] as num).toDouble(),
        voiced: frame['voiced'] as bool,
        f0Hz: (frame['pitchHz'] as num?)?.toDouble(),
        bandPowersDb: (frame['bandPowersDbfs'] as List<dynamic>)
            .map((value) => (value as num).toDouble())
            .toList(growable: false),
        qualityFlags: (frame['qualityFlags'] as num).toInt(),
      );
}
