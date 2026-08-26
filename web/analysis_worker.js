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
    if (!Number.isInteger(id) || id <= 0 || typeof kind !== 'string') {
      throw new Error('Invalid analysis worker request envelope.');
    }
    if (kind === 'initialize') {
      if (!Number.isInteger(data.sampleRate) || data.sampleRate <= 0) {
        throw new Error('Invalid analysis worker sample rate.');
      }
      await wasm_bindgen('pkg/rust_lib_voice_trainer_bg.wasm');
      analyzer = new wasm_bindgen.WorkerRealtimeAnalyzer(data.sampleRate);
      reply(id, { initialized: true });
      return;
    }
    if (kind === 'pushPcm') {
      if (analyzer === null) throw new Error('Worker analyzer is not initialized.');
      if (!(data.pcm instanceof ArrayBuffer)) {
        throw new Error('Worker PCM payload must be an ArrayBuffer.');
      }
      if (!Number.isSafeInteger(data.startSample) || data.startSample < 0) {
        throw new Error('Worker start sample must be a non-negative safe integer.');
      }
      if (!Number.isSafeInteger(data.droppedSamplesBefore) || data.droppedSamplesBefore < 0) {
        throw new Error('Worker dropped sample count must be a non-negative safe integer.');
      }
      if (typeof data.discontinuityBefore !== 'boolean') {
        throw new Error('Worker discontinuity flag must be boolean.');
      }
      const pcm = new Int16Array(data.pcm);
      if (pcm.length > 1024) throw new Error('Worker batch exceeds 1024 samples.');
      const frames = analyzer.pushPcm16WithMetadata(
        BigInt(data.startSample),
        pcm,
        data.droppedSamplesBefore,
        data.discontinuityBefore,
      );
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
    if (kind === 'finish') {
      if (analyzer === null) throw new Error('Worker analyzer is not initialized.');
      const summary = analyzer.finish();
      reply(id, {
        startSample: summary.start_sample === undefined ? null : Number(summary.start_sample),
        endSample: summary.end_sample === undefined ? null : Number(summary.end_sample),
        frameCount: summary.frame_count,
        validFrameCount: summary.valid_frame_count,
        droppedSamples: Number(summary.dropped_samples),
        qualityFlags: summary.quality_flags,
        pitchStability: mapStability(summary.pitch_stability),
        levelStability: mapStability(summary.level_stability),
        onsetDelaySamples: summary.onset_delay_samples === undefined ? null : Number(summary.onset_delay_samples),
      });
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

function mapStability(stability) {
  if (stability === undefined) return null;
  return {
    median: stability.median,
    medianAbsoluteDeviation: stability.median_absolute_deviation,
    slopePerSecond: stability.slope_per_second,
    frameCount: stability.frame_count,
  };
}
