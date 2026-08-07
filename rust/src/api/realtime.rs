use crate::{
    features::{RobustStability, SegmentSummary},
    model::AnalysisFrame,
    pipeline::realtime_analyzer::RealtimeAnalyzerCore,
};

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

/// Stable segment-level result exposed only when an analyzer is finalized.
/// Keeping this separate from the per-frame DTO prevents summary statistics
/// from being reconstructed with a subtly different algorithm in Dart.
#[cfg_attr(target_family = "wasm", derive(serde::Serialize))]
#[derive(Clone, Debug, PartialEq)]
pub struct SegmentSummaryDto {
    pub start_sample: Option<u64>,
    pub end_sample: Option<u64>,
    pub frame_count: u32,
    pub valid_frame_count: u32,
    pub dropped_samples: u64,
    pub quality_flags: u16,
    pub pitch_stability: Option<RobustStabilityDto>,
    pub level_stability: Option<RobustStabilityDto>,
    pub onset_delay_samples: Option<u64>,
}

#[cfg_attr(target_family = "wasm", derive(serde::Serialize))]
#[derive(Clone, Debug, PartialEq)]
pub struct RobustStabilityDto {
    pub median: f32,
    pub median_absolute_deviation: f32,
    pub slope_per_second: f32,
    pub frame_count: u32,
}

impl From<RobustStability> for RobustStabilityDto {
    fn from(stability: RobustStability) -> Self {
        Self {
            median: stability.median,
            median_absolute_deviation: stability.median_absolute_deviation,
            slope_per_second: stability.slope_per_second,
            frame_count: stability.frame_count.try_into().unwrap_or(u32::MAX),
        }
    }
}

impl From<SegmentSummary> for SegmentSummaryDto {
    fn from(summary: SegmentSummary) -> Self {
        Self {
            start_sample: summary.start_sample,
            end_sample: summary.end_sample,
            frame_count: summary.frame_count.try_into().unwrap_or(u32::MAX),
            valid_frame_count: summary.valid_frame_count.try_into().unwrap_or(u32::MAX),
            dropped_samples: summary.dropped_samples,
            quality_flags: summary.quality_flags.bits(),
            pitch_stability: summary.pitch_stability.map(RobustStabilityDto::from),
            level_stability: summary.level_stability.map(RobustStabilityDto::from),
            onset_delay_samples: summary.onset_delay_samples,
        }
    }
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
        let start_sample = self.core.next_input_sample();
        self.push_pcm16_at(start_sample, pcm)
    }

    /// Production entry point. Capture owns the monotonically increasing
    /// sample position; the DSP never invents a per-batch clock.
    #[flutter_rust_bridge::frb(sync)]
    pub fn push_pcm16_at(&mut self, start_sample: u64, pcm: Vec<i16>) -> Vec<AnalysisFrameDto> {
        self.push_pcm16_with_metadata(start_sample, pcm, 0, false)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn push_pcm16_with_metadata(
        &mut self,
        start_sample: u64,
        pcm: Vec<i16>,
        dropped_samples_before: u32,
        discontinuity_before: bool,
    ) -> Vec<AnalysisFrameDto> {
        assert!(
            pcm.len() <= MAX_BRIDGE_BATCH_SAMPLES,
            "bridge batch exceeds {MAX_BRIDGE_BATCH_SAMPLES} samples"
        );
        self.core
            .push_pcm16_with_metadata(
                start_sample,
                &pcm,
                dropped_samples_before,
                discontinuity_before,
            )
            .into_iter()
            .map(AnalysisFrameDto::from)
            .collect()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn finish(&mut self) -> SegmentSummaryDto {
        self.core.finish().into()
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

    #[test]
    fn bridge_exposes_segment_summary_only_at_finalization() {
        let mut analyzer = RealtimeAnalyzer::new(48_000);
        let samples: Vec<i16> = (0..48_000)
            .map(|index| {
                (std::f32::consts::TAU * 220.0 * index as f32 / 48_000.0)
                    .sin()
                    .mul_add(16_000.0, 0.0) as i16
            })
            .collect();
        for (offset, batch) in samples.chunks(MAX_BRIDGE_BATCH_SAMPLES).enumerate() {
            let _ =
                analyzer.push_pcm16_at((offset * MAX_BRIDGE_BATCH_SAMPLES) as u64, batch.to_vec());
        }

        let summary = analyzer.finish();
        assert!(summary.frame_count > 0);
        assert!(summary.valid_frame_count >= 30);
        assert!(summary.pitch_stability.is_some());
    }
}
