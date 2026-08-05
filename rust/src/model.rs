#[cfg_attr(target_family = "wasm", derive(serde::Serialize))]
#[derive(Clone, Debug, PartialEq)]
pub struct AnalysisFrame {
    pub start_sample: u64,
    pub rms: f32,
    pub peak: f32,
    pub spectral_centroid_hz: f32,
    pub pitch_hz: Option<f32>,
    pub pitch_clarity: f32,
}
