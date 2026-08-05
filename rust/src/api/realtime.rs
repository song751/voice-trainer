use crate::{model::AnalysisFrame, pipeline::realtime_analyzer::RealtimeAnalyzerCore};

#[flutter_rust_bridge::frb(opaque)]
pub struct RealtimeAnalyzer {
    core: RealtimeAnalyzerCore,
}

impl RealtimeAnalyzer {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(sample_rate: u32) -> Self {
        Self {
            core: RealtimeAnalyzerCore::new(sample_rate),
        }
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn push_pcm16(&mut self, pcm: Vec<i16>) -> Vec<AnalysisFrame> {
        self.core.push_pcm16(&pcm)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn reset(&mut self) {
        self.core.reset();
    }
}
