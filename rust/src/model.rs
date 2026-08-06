#[derive(Clone, Debug, PartialEq)]
pub struct AnalysisFrame {
    pub start_sample: u64,
    pub rms: f32,
    pub peak: f32,
    pub spectral_centroid_hz: f32,
    pub pitch_hz: Option<f32>,
    pub pitch_clarity: f32,
    /// Fixed-width full-band summary for the public bridge. The 128-bin UI
    /// spectrum remains an internal spectrum-module result.
    pub band_powers_dbfs: [f32; crate::spectrum::BAND_POWER_COUNT],
    /// Bitset from `features::QualityFlags`; the bridge maps it to Dart's
    /// domain enum without exposing the feature implementation state.
    pub quality_flags: u16,
}
