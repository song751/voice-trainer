//! Minimal WASM surface for the application's dedicated DSP Worker.
//!
//! This intentionally has no relationship to FRB's 2.12 `WorkerPool`: that
//! pool transfers non-shared WebAssembly memory and fails in Edge.  Each
//! browser Worker owns one analyzer and receives only PCM16 batches.

use wasm_bindgen::prelude::*;

use crate::{api::realtime::AnalysisFrameDto, pipeline::realtime_analyzer::RealtimeAnalyzerCore};

const MAX_BRIDGE_BATCH_SAMPLES: usize = 1_024;

#[wasm_bindgen]
pub struct WorkerRealtimeAnalyzer {
    core: RealtimeAnalyzerCore,
}

#[wasm_bindgen]
impl WorkerRealtimeAnalyzer {
    #[wasm_bindgen(constructor)]
    pub fn new(sample_rate: u32) -> WorkerRealtimeAnalyzer {
        WorkerRealtimeAnalyzer {
            core: RealtimeAnalyzerCore::new(sample_rate),
        }
    }

    #[wasm_bindgen(js_name = pushPcm16)]
    pub fn push_pcm16(&mut self, pcm: &[i16]) -> Result<JsValue, JsValue> {
        if pcm.len() > MAX_BRIDGE_BATCH_SAMPLES {
            return Err(JsValue::from_str("Worker batch exceeds 1024 samples."));
        }
        let frames: Vec<AnalysisFrameDto> = self
            .core
            .push_pcm16(pcm)
            .into_iter()
            .map(AnalysisFrameDto::from)
            .collect();
        serde_wasm_bindgen::to_value(&frames).map_err(|error| JsValue::from_str(&error.to_string()))
    }

    pub fn reset(&mut self) {
        self.core.reset();
    }
}
