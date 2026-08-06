#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PitchAlgorithm {
    Mpm,
    Yin,
}

pub const DEFAULT_PITCH_ALGORITHM: PitchAlgorithm = PitchAlgorithm::Yin;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PitchConfig {
    pub sample_rate_hz: u32,
    pub min_frequency_hz: f32,
    pub max_frequency_hz: f32,
}

impl PitchConfig {
    pub const fn voice_16khz() -> Self {
        Self {
            sample_rate_hz: 16_000,
            min_frequency_hz: 60.0,
            max_frequency_hz: 1_200.0,
        }
    }

    pub fn lag_bounds(self, sample_count: usize) -> (usize, usize) {
        let min_lag = (self.sample_rate_hz as f32 / self.max_frequency_hz).floor() as usize;
        let max_lag = (self.sample_rate_hz as f32 / self.min_frequency_hz).ceil() as usize;
        (min_lag.max(2), max_lag.min(sample_count.saturating_sub(2)))
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PitchEstimate {
    pub frequency_hz: f32,
    /// Algorithm-specific periodicity confidence normalized to the [0, 1] range.
    pub clarity: f32,
}

pub trait PitchEstimator: Send + Sync {
    fn algorithm(&self) -> PitchAlgorithm;
    fn estimate(&self, samples: &[f32], config: PitchConfig) -> Option<PitchEstimate>;
}

/// Returns the offset from the centre sample of a three-point parabola.
pub fn parabolic_offset(left: f32, centre: f32, right: f32) -> f32 {
    let denominator = left - 2.0 * centre + right;
    if denominator.abs() <= 1.0e-12 {
        0.0
    } else {
        (0.5 * (left - right) / denominator).clamp(-0.5, 0.5)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lag_bounds_cover_the_configured_voice_range() {
        assert_eq!(PitchConfig::voice_16khz().lag_bounds(1024), (13, 267));
    }

    #[test]
    fn parabolic_interpolation_finds_a_symmetric_peak() {
        assert_eq!(parabolic_offset(0.5, 1.0, 0.5), 0.0);
        assert!(parabolic_offset(0.8, 1.0, 0.5) < 0.0);
    }
}
