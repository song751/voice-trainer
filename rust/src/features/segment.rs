use super::{
    level_stability, pitch_stability, FeatureInput, OnsetDetector, OnsetSettings, QualityConfig,
    QualityFlags, RobustStability,
};

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct SegmentConfig {
    pub sample_rate_hz: u32,
    pub minimum_valid_frames: usize,
    pub quality: QualityConfig,
    pub onset: OnsetSettings,
}

impl Default for SegmentConfig {
    fn default() -> Self {
        Self {
            sample_rate_hz: 48_000,
            minimum_valid_frames: 30,
            quality: QualityConfig::default(),
            onset: OnsetSettings::default(),
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct SegmentSummary {
    pub start_sample: Option<u64>,
    pub end_sample: Option<u64>,
    pub frame_count: usize,
    pub valid_frame_count: usize,
    pub dropped_samples: u64,
    pub quality_flags: QualityFlags,
    pub pitch_stability: Option<RobustStability>,
    pub level_stability: Option<RobustStability>,
    pub onset_delay_samples: Option<u64>,
}

pub struct SegmentAggregator {
    config: SegmentConfig,
    onset: OnsetDetector,
    start_sample: Option<u64>,
    previous_end_sample: Option<u64>,
    frame_count: usize,
    valid_frame_count: usize,
    dropped_samples: u64,
    quality_flags: QualityFlags,
    valid_pitch: Vec<(u64, f32)>,
    valid_level: Vec<(u64, f32)>,
}

impl SegmentAggregator {
    pub fn new(config: SegmentConfig) -> Self {
        assert!(config.sample_rate_hz > 0);
        Self {
            onset: OnsetDetector::new(config.onset),
            config,
            start_sample: None,
            previous_end_sample: None,
            frame_count: 0,
            valid_frame_count: 0,
            dropped_samples: 0,
            quality_flags: QualityFlags::NONE,
            valid_pitch: Vec::with_capacity(6_000),
            valid_level: Vec::with_capacity(6_000),
        }
    }

    pub fn push(&mut self, input: FeatureInput) {
        let mut flags = input.quality_flags(self.config.quality);
        if let Some(expected_start) = self.previous_end_sample {
            if input.start_sample != expected_start {
                flags = flags.union(QualityFlags::DISCONTINUITY);
                if input.start_sample > expected_start {
                    let missing = input.start_sample - expected_start;
                    self.dropped_samples += missing.max(input.dropped_samples as u64);
                    flags = flags.union(QualityFlags::DROPPED_SAMPLES);
                } else {
                    self.dropped_samples += input.dropped_samples as u64;
                }
            } else {
                self.dropped_samples += input.dropped_samples as u64;
            }
        } else {
            self.dropped_samples += input.dropped_samples as u64;
        }
        self.start_sample.get_or_insert(input.start_sample);
        self.previous_end_sample = Some(input.start_sample + input.hop_samples as u64);
        self.frame_count += 1;
        self.quality_flags = self.quality_flags.union(flags);
        self.onset
            .push(input.start_sample, input.rms_dbfs, input.voiced, flags);

        let valid = input.voiced
            && input.frequency_hz.is_some()
            && !flags.contains(QualityFlags::CLIPPING)
            && !flags.contains(QualityFlags::INPUT_TOO_LOW)
            && !flags.contains(QualityFlags::DROPPED_SAMPLES)
            && !flags.contains(QualityFlags::DISCONTINUITY);
        if valid {
            self.valid_frame_count += 1;
            self.valid_level.push((input.start_sample, input.rms_dbfs));
            if let Some(frequency_hz) = input.frequency_hz {
                self.valid_pitch.push((input.start_sample, frequency_hz));
            }
        }
    }

    /// Carries a capture/worker break into the summary without pretending that
    /// un-emitted tail windows were lost PCM. The next supplied frame is
    /// explicitly marked discontinuous by the caller and remains excluded
    /// from cross-breakpoint statistics.
    pub fn mark_discontinuity(&mut self, dropped_samples: u64, resume_at_sample: u64) {
        self.quality_flags = self.quality_flags.union(QualityFlags::DISCONTINUITY);
        if dropped_samples > 0 {
            self.quality_flags = self.quality_flags.union(QualityFlags::DROPPED_SAMPLES);
            self.dropped_samples += dropped_samples;
        }
        self.previous_end_sample = Some(resume_at_sample);
    }

    pub fn finish(self) -> SegmentSummary {
        let mut quality_flags = self.quality_flags;
        if self.valid_frame_count < self.config.minimum_valid_frames {
            quality_flags = quality_flags.union(QualityFlags::INSUFFICIENT_VALID_FRAMES);
        }
        SegmentSummary {
            start_sample: self.start_sample,
            end_sample: self.previous_end_sample,
            frame_count: self.frame_count,
            valid_frame_count: self.valid_frame_count,
            dropped_samples: self.dropped_samples,
            quality_flags,
            pitch_stability: pitch_stability(&self.valid_pitch, self.config.sample_rate_hz),
            level_stability: level_stability(&self.valid_level, self.config.sample_rate_hz),
            onset_delay_samples: self.onset.onset_delay_samples(),
        }
    }
}
