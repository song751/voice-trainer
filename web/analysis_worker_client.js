// Thin main-thread facade. It transfers PCM ArrayBuffers to the dedicated
// worker and exposes JSON-only DTO results to Dart's static JS interop.
class VoiceTrainerAnalysisWorker {
  constructor() {
    this._nextId = 1;
    this._pending = new Map();
    this._worker = new Worker(new URL('analysis_worker.js', document.baseURI));
    this._worker.onmessage = ({ data }) => {
      if (!data || !Number.isInteger(data.id) || typeof data.ok !== 'boolean') {
        this._terminate(new Error('Analysis worker returned an invalid envelope.'));
        return;
      }
      const pending = this._pending.get(data.id);
      if (!pending) return;
      this._pending.delete(data.id);
      if (data.ok) pending.resolve(JSON.stringify(data.payload));
      else pending.reject(new Error(data.error));
    };
    this._worker.onerror = (event) => {
      const error = new Error(event.message || 'Analysis worker crashed.');
      this._terminate(error);
    };
  }

  initialize(sampleRate) {
    return this._request('initialize', { sampleRate });
  }

  pushPcm(pcm, startSample, droppedSamplesBefore, discontinuityBefore) {
    return this._request('pushPcm', {
      pcm: pcm.buffer,
      startSample,
      droppedSamplesBefore,
      discontinuityBefore,
    }, [pcm.buffer]);
  }

  reset() {
    return this._request('reset');
  }

  finish() {
    return this._request('finish');
  }

  dispose() {
    return this._request('dispose').finally(() => this._worker.terminate());
  }

  terminate() {
    this._terminate(new Error('Analysis worker terminated.'));
  }

  _request(kind, payload = {}, transfer = []) {
    const id = this._nextId++;
    return new Promise((resolve, reject) => {
      this._pending.set(id, { resolve, reject });
      try {
        this._worker.postMessage({ id, kind, ...payload }, transfer);
      } catch (error) {
        this._pending.delete(id);
        reject(error);
      }
    });
  }

  _terminate(error) {
    for (const pending of this._pending.values()) pending.reject(error);
    this._pending.clear();
    this._worker.terminate();
  }
}

window.VoiceTrainerAnalysisWorker = VoiceTrainerAnalysisWorker;
