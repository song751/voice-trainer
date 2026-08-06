// Dedicated Rust DSP execution context for Flutter Web.
//
// FRB's 2.12 WASM WorkerPool is intentionally disabled: it tries to transfer
// non-shared WebAssembly.Memory and fails with DataCloneError in Edge. This
// worker owns a separate WASM instance and receives only PCM16 typed batches.
importScripts('pkg/rust_lib_voice_trainer.js');

let analyzer = null;

function reply(id, payload) {
  self.postMessage({ id, ok: true, payload });
}

function fail(id, error) {
  self.postMessage({
    id,
    ok: false,
    error: error instanceof Error ? error.message : String(error),
  });
}

self.onmessage = async ({ data }) => {
  const { id, kind } = data;
  try {
    if (kind === 'initialize') {
      await wasm_bindgen('pkg/rust_lib_voice_trainer_bg.wasm');
      analyzer = new wasm_bindgen.WorkerRealtimeAnalyzer(data.sampleRate);
      reply(id, { initialized: true });
      return;
    }
    if (kind === 'pushPcm') {
      if (analyzer === null) throw new Error('Worker analyzer is not initialized.');
      const pcm = new Int16Array(data.pcm);
      if (pcm.length > 1024) throw new Error('Worker batch exceeds 1024 samples.');
      const frames = analyzer.pushPcm16(pcm);
      reply(id, frames.map((frame) => ({
        startSample: Number(frame.start_sample),
        rmsDbfs: frame.rms_dbfs,
        peakDbfs: frame.peak_dbfs,
        pitchHz: frame.pitch_hz,
        pitchClarity: frame.pitch_clarity,
        voiced: frame.voiced,
        bandPowersDbfs: frame.band_powers_dbfs,
        qualityFlags: frame.quality_flags,
      })));
      return;
    }
    if (kind === 'reset') {
      if (analyzer !== null) analyzer.reset();
      reply(id, { reset: true });
      return;
    }
    if (kind === 'dispose') {
      analyzer = null;
      reply(id, { disposed: true });
      self.close();
      return;
    }
    throw new Error(`Unknown analysis worker operation: ${kind}`);
  } catch (error) {
    fail(id, error);
  }
};
