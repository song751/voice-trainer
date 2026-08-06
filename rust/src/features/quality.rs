pub const DBFS_FLOOR: f32 = -120.0;
const PCM16_FULL_SCALE: f32 = 1.0 - 1.0 / 32_768.0;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct QualityFlags(u16);

impl QualityFlags {
    pub const NONE: Self = Self(0);
    pub const CLIPPING: Self = Self(1 << 0);
    pub const INPUT_TOO_LOW: Self = Self(1 << 1);
    pub const DROPPED_SAMPLES: Self = Self(1 << 2);
    pub const DISCONTINUITY: Self = Self(1 << 3);
    pub const INSUFFICIENT_VALID_FRAMES: Self = Self(1 << 4);

    pub const fn contains(self, other: Self) -> bool {
        self.0 & other.0 != 0
    }

    /// Stable compact representation for the bridge DTO.
    pub const fn bits(self) -> u16 {
        self.0
    }

    pub const fn union(self, other: Self) -> Self {
        Self(self.0 | other.0)
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct QualityConfig {
    pub clipping_ratio_threshold: f32,
    pub input_too_low_dbfs: f32,
}

impl Default for QualityConfig {
    fn default() -> Self {
        Self {
            clipping_ratio_threshold: 0.001,
            input_too_low_dbfs: -50.0,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct FeatureInput {
    pub start_sample: u64,
    pub hop_samples: u32,
    pub rms_dbfs: f32,
    pub peak_dbfs: f32,
    pub clipped_ratio: f32,
    pub dropped_samples: u32,
    pub discontinuity: bool,
    pub frequency_hz: Option<f32>,
    pub voiced: bool,
}

impl FeatureInput {
    pub fn from_samples(
        start_sample: u64,
        hop_samples: u32,
        samples: &[f32],
        frequency_hz: Option<f32>,
        voiced: bool,
    ) -> Self {
        assert!(!samples.is_empty(), "feature input must contain samples");
        let mut sum_squares = 0.0;
        let mut peak = 0.0_f32;
        let mut clipped = 0;
        for &sample in samples {
            sum_squares += sample * sample;
            peak = peak.max(sample.abs());
            if sample.abs() >= PCM16_FULL_SCALE {
                clipped += 1;
            }
        }
        let rms = (sum_squares / samples.len() as f32).sqrt();
        Self {
            start_sample,
            hop_samples,
            rms_dbfs: amplitude_to_dbfs(rms),
            peak_dbfs: amplitude_to_dbfs(peak),
            clipped_ratio: clipped as f32 / samples.len() as f32,
            dropped_samples: 0,
            discontinuity: false,
            frequency_hz,
            voiced,
        }
    }

    pub fn quality_flags(self, config: QualityConfig) -> QualityFlags {
        let mut flags = QualityFlags::NONE;
        if self.clipped_ratio >= config.clipping_ratio_threshold {
            flags = flags.union(QualityFlags::CLIPPING);
        }
        if self.rms_dbfs < config.input_too_low_dbfs {
            flags = flags.union(QualityFlags::INPUT_TOO_LOW);
        }
        if self.dropped_samples > 0 {
            flags = flags.union(QualityFlags::DROPPED_SAMPLES);
        }
        if self.discontinuity {
            flags = flags.union(QualityFlags::DISCONTINUITY);
        }
        flags
    }
}

pub(crate) fn amplitude_to_dbfs(amplitude: f32) -> f32 {
    (20.0 * amplitude.max(10.0_f32.powf(DBFS_FLOOR / 20.0)).log10()).max(DBFS_FLOOR)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quality_flags_cover_clipping_and_low_input() {
        let clipped = FeatureInput::from_samples(0, 480, &[1.0; 480], Some(220.0), true);
        assert!(clipped
            .quality_flags(QualityConfig::default())
            .contains(QualityFlags::CLIPPING));
        let silence = FeatureInput::from_samples(0, 480, &[0.0; 480], None, false);
        assert!(silence
            .quality_flags(QualityConfig::default())
            .contains(QualityFlags::INPUT_TOO_LOW));
    }
}
