import 'dart:js_interop';

import '../../core/domain/analysis/analysis_config.dart';
import '../../core/domain/analysis/analysis_engine.dart';
import '../../core/domain/analysis/analysis_frame.dart';
import '../../core/domain/audio/pcm_chunk.dart';
import 'analysis_worker_supervisor.dart';
import 'web_worker_message_decoder.dart';

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
  WebWorkerAnalysisWorker([this._decoder = const WebWorkerMessageDecoder()]);

  final _WebWorkerClient _client = _WebWorkerClient();
  final WebWorkerMessageDecoder _decoder;
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
    final decodedBatch = _decoder.decodeBatch(raw);
    _frames.addAll(decodedBatch.frames);
    return decodedBatch;
  }

  @override
  Future<AnalysisFinalization> finish() async {
    final raw = (await _client.finish().toDart).toDart;
    return _decoder.decodeFinalization(raw, _frames);
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
}
