use super::quality::QualityFlags;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct OnsetSettings {
    pub energy_threshold_dbfs: f32,
    pub required_consecutive_voiced_frames: usize,
}

impl Default for OnsetSettings {
    fn default() -> Self {
        Self {
            energy_threshold_dbfs: -45.0,
            required_consecutive_voiced_frames: 3,
        }
    }
}

#[derive(Clone, Debug)]
pub struct OnsetDetector {
    settings: OnsetSettings,
    energy_crossing_sample: Option<u64>,
    consecutive_voiced_frames: usize,
    onset_delay_samples: Option<u64>,
}

impl OnsetDetector {
    pub fn new(settings: OnsetSettings) -> Self {
        assert!(settings.required_consecutive_voiced_frames > 0);
        Self {
            settings,
            energy_crossing_sample: None,
            consecutive_voiced_frames: 0,
            onset_delay_samples: None,
        }
    }

    pub fn push(&mut self, start_sample: u64, rms_dbfs: f32, voiced: bool, flags: QualityFlags) {
        if self.onset_delay_samples.is_some() {
            return;
        }
        if self.energy_crossing_sample.is_none() {
            if rms_dbfs >= self.settings.energy_threshold_dbfs {
                self.energy_crossing_sample = Some(start_sample);
                self.consecutive_voiced_frames = 0;
            } else {
                return;
            }
        }
        let valid_voiced = voiced
            && !flags.contains(QualityFlags::DROPPED_SAMPLES)
            && !flags.contains(QualityFlags::DISCONTINUITY)
            && !flags.contains(QualityFlags::INPUT_TOO_LOW);
        self.consecutive_voiced_frames = if valid_voiced {
            self.consecutive_voiced_frames + 1
        } else {
            0
        };
        if self.consecutive_voiced_frames >= self.settings.required_consecutive_voiced_frames {
            if let Some(crossing) = self.energy_crossing_sample {
                self.onset_delay_samples = Some(start_sample.saturating_sub(crossing));
            }
        }
    }

    pub fn onset_delay_samples(&self) -> Option<u64> {
        self.onset_delay_samples
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn onset_waits_for_consecutive_valid_voiced_frames() {
        let mut onset = OnsetDetector::new(OnsetSettings::default());
        onset.push(0, -60.0, false, QualityFlags::NONE);
        onset.push(480, -30.0, true, QualityFlags::NONE);
        onset.push(960, -30.0, true, QualityFlags::NONE);
        onset.push(1_440, -30.0, true, QualityFlags::NONE);
        assert_eq!(onset.onset_delay_samples(), Some(960));
    }
}
