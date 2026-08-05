// Thin main-thread facade. It transfers PCM ArrayBuffers to the dedicated
// worker and exposes JSON-only DTO results to Dart's static JS interop.
class VoiceTrainerAnalysisWorker {
  constructor() {
    this._nextId = 1;
    this._pending = new Map();
    this._worker = new Worker(new URL('analysis_worker.js', document.baseURI));
    this._worker.onmessage = ({ data }) => {
      const pending = this._pending.get(data.id);
      if (!pending) return;
      this._pending.delete(data.id);
      if (data.ok) pending.resolve(JSON.stringify(data.payload));
      else pending.reject(new Error(data.error));
    };
    this._worker.onerror = (event) => {
      const error = new Error(event.message || 'Analysis worker crashed.');
      for (const pending of this._pending.values()) pending.reject(error);
      this._pending.clear();
    };
  }

  initialize(sampleRate) {
    return this._request('initialize', { sampleRate });
  }

  pushPcm(pcm) {
    return this._request('pushPcm', { pcm: pcm.buffer }, [pcm.buffer]);
  }

  reset() {
    return this._request('reset');
  }

  dispose() {
    return this._request('dispose').finally(() => this._worker.terminate());
  }

  _request(kind, payload = {}, transfer = []) {
    const id = this._nextId++;
    return new Promise((resolve, reject) => {
      this._pending.set(id, { resolve, reject });
      this._worker.postMessage({ id, kind, ...payload }, transfer);
    });
  }
}

window.VoiceTrainerAnalysisWorker = VoiceTrainerAnalysisWorker;
