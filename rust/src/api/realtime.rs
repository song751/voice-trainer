use crate::{model::AnalysisFrame, pipeline::realtime_analyzer::RealtimeAnalyzerCore};

/// The intentionally small, stable result crossing the FRB and browser-worker
/// boundaries. It contains scalar analysis results, eight full-band summaries,
/// and a compact quality mask only; DSP buffers and 128-bin UI spectrum data
/// remain private to Rust.
#[cfg_attr(target_family = "wasm", derive(serde::Serialize))]
#[derive(Clone, Debug, PartialEq)]
pub struct AnalysisFrameDto {
    pub start_sample: u64,
    pub rms_dbfs: f32,
    pub peak_dbfs: f32,
    pub pitch_hz: Option<f32>,
    pub pitch_clarity: f32,
    pub voiced: bool,
    pub band_powers_dbfs: Vec<f32>,
    pub quality_flags: u16,
}

impl From<AnalysisFrame> for AnalysisFrameDto {
    fn from(frame: AnalysisFrame) -> Self {
        let voiced = frame.pitch_hz.is_some();
        Self {
            start_sample: frame.start_sample,
            rms_dbfs: amplitude_to_dbfs(frame.rms),
            peak_dbfs: amplitude_to_dbfs(frame.peak),
            pitch_hz: frame.pitch_hz,
            pitch_clarity: frame.pitch_clarity,
            voiced,
            band_powers_dbfs: Vec::from(frame.band_powers_dbfs),
            quality_flags: frame.quality_flags,
        }
    }
}

const MAX_BRIDGE_BATCH_SAMPLES: usize = 1_024;

fn amplitude_to_dbfs(amplitude: f32) -> f32 {
    (20.0 * amplitude.max(10.0_f32.powf(-6.0)).log10()).max(-120.0)
}

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
    pub fn push_pcm16(&mut self, pcm: Vec<i16>) -> Vec<AnalysisFrameDto> {
        assert!(
            pcm.len() <= MAX_BRIDGE_BATCH_SAMPLES,
            "bridge batch exceeds {MAX_BRIDGE_BATCH_SAMPLES} samples"
        );
        self.core
            .push_pcm16(&pcm)
            .into_iter()
            .map(AnalysisFrameDto::from)
            .collect()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn reset(&mut self) {
        self.core.reset();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::spectrum::BAND_POWER_COUNT;

    #[test]
    fn bridge_dto_is_fixed_to_eight_band_powers() {
        let frame = AnalysisFrame {
            start_sample: 0,
            rms: 0.5,
            peak: 1.0,
            spectral_centroid_hz: 500.0,
            pitch_hz: Some(220.0),
            pitch_clarity: 0.9,
            band_powers_dbfs: [-30.0; BAND_POWER_COUNT],
            quality_flags: 1,
        };
        let dto = AnalysisFrameDto::from(frame);
        assert_eq!(dto.band_powers_dbfs.len(), BAND_POWER_COUNT);
        assert!(dto.voiced);
        assert!((dto.rms_dbfs + 6.0206).abs() < 0.0001);
    }

    #[test]
    #[should_panic(expected = "bridge batch exceeds 1024 samples")]
    fn bridge_rejects_oversized_pcm_batches() {
        let mut analyzer = RealtimeAnalyzer::new(48_000);
        let _ = analyzer.push_pcm16(vec![0; MAX_BRIDGE_BATCH_SAMPLES + 1]);
    }
}
