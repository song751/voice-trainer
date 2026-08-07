import 'dart:convert';
import 'dart:js_interop';

import '../../core/domain/analysis/analysis_config.dart';
import '../../core/domain/analysis/analysis_engine.dart';
import '../../core/domain/analysis/analysis_frame.dart';
import '../../core/domain/analysis/feature_series.dart';
import '../../core/domain/audio/pcm_chunk.dart';
import 'analysis_frame_dto_mapper.dart';
import 'analysis_worker_supervisor.dart';
import 'segment_summary_dto_mapper.dart';

@JS('VoiceTrainerAnalysisWorker')
extension type _WebWorkerClient._(JSObject _) implements JSObject {
  external factory _WebWorkerClient();

  external JSPromise<JSString> initialize(int sampleRate);
  external JSPromise<JSString> pushPcm(
    JSUint8Array pcm,
    int startSample,
    int droppedSamplesBefore,
    bool discontinuityBefore,
  );
  external JSPromise<JSString> reset();
  external JSPromise<JSString> finish();
  external JSPromise<JSString> dispose();
  external void terminate();
}

/// Dedicated browser Worker client. The JavaScript counterpart transfers a
/// PCM16 ArrayBuffer and sends back only the compact Phase 2 frame DTO.
final class WebWorkerAnalysisWorker implements AnalysisWorker {
  final _WebWorkerClient _client = _WebWorkerClient();
  final List<AnalysisFrame> _frames = <AnalysisFrame>[];

  @override
  Future<void> initialize(AnalysisConfig config) async {
    await _client.initialize(config.inputFormatSampleRate).toDart;
    _frames.clear();
  }

  @override
  Future<AnalysisBatch> pushPcm(PcmBatch batch) async {
    final raw =
        (await _client
                .pushPcm(
                  batch.bytes.toJS,
                  batch.firstSampleIndex,
                  batch.droppedSamplesBefore,
                  batch.discontinuityBefore,
                )
                .toDart)
            .toDart;
    final decoded = jsonDecode(raw) as List<dynamic>;
    final frames = decoded
        .cast<Map<String, dynamic>>()
        .map(_mapFrame)
        .toList(growable: false);
    _frames.addAll(frames);
    return AnalysisBatch(frames);
  }

  @override
  Future<AnalysisFinalization> finish() async {
    final raw = (await _client.finish().toDart).toDart;
    final summary = jsonDecode(raw) as Map<String, dynamic>;
    return AnalysisFinalization(
      featureSeries: FeatureSeries(frameRateHz: 100, frames: _frames),
      finalFrames: _frames,
      segmentSummary: mapWebSegmentSummary(summary),
    );
  }

  @override
  Future<void> reset() async {
    await _client.reset().toDart;
    _frames.clear();
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
  }

  AnalysisFrame _mapFrame(Map<String, dynamic> frame) => mapAnalysisFrameDto(
    startSample: (frame['startSample'] as num).toInt(),
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
