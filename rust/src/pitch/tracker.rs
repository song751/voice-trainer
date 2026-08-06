use crate::signal::{
    dc_blocker::DcBlocker, resampler::PolyphaseDecimator3, ring_buffer::RingBuffer,
};

use super::{PitchConfig, PitchEstimate, PitchEstimator};

pub const PITCH_WINDOW_SIZE: usize = 1024;
pub const PITCH_HOP_SIZE: usize = 160;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct VoicedDecisionConfig {
    pub minimum_rms: f32,
    pub minimum_clarity: f32,
    pub maximum_jump_cents: f32,
}

impl Default for VoicedDecisionConfig {
    fn default() -> Self {
        Self {
            // -55 dBFS: enough headroom for normal capture, while rejecting the P2-01 noise case.
            minimum_rms: 10.0_f32.powf(-55.0 / 20.0),
            minimum_clarity: 0.60,
            maximum_jump_cents: 250.0,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PitchFrame {
    pub start_sample: u64,
    pub frequency_hz: Option<f32>,
    pub clarity: f32,
    pub voiced: bool,
}

pub struct PitchTracker<E: PitchEstimator> {
    estimator: E,
    pitch_config: PitchConfig,
    voiced_config: VoicedDecisionConfig,
    dc_blocker: DcBlocker,
    decimator: PolyphaseDecimator3,
    pending: RingBuffer<f32>,
    dc_blocked_scratch: Vec<f32>,
    decimated_scratch: Vec<f32>,
    next_frame_start: u64,
    previous_voiced_frequency_hz: Option<f32>,
}

impl<E: PitchEstimator> PitchTracker<E> {
    pub fn new(estimator: E, voiced_config: VoicedDecisionConfig) -> Self {
        Self {
            estimator,
            pitch_config: PitchConfig::voice_16khz(),
            voiced_config,
            dc_blocker: DcBlocker::new(48_000, 20.0),
            decimator: PolyphaseDecimator3::new(48_000).expect("canonical rate is supported"),
            pending: RingBuffer::new(PITCH_WINDOW_SIZE + PITCH_HOP_SIZE),
            dc_blocked_scratch: Vec::with_capacity(1_024),
            decimated_scratch: Vec::with_capacity(512),
            next_frame_start: 0,
            previous_voiced_frequency_hz: None,
        }
    }

    pub fn push(&mut self, input_48khz: &[f32]) -> Vec<PitchFrame> {
        self.decimated_scratch.clear();
        self.dc_blocked_scratch.clear();
        for &sample in input_48khz {
            self.dc_blocked_scratch
                .push(self.dc_blocker.process(sample));
        }
        self.decimator
            .process_into(&self.dc_blocked_scratch, &mut self.decimated_scratch);
        let expected_frame_count = (self.pending.len() + self.decimated_scratch.len())
            .saturating_sub(PITCH_WINDOW_SIZE)
            .checked_div(PITCH_HOP_SIZE)
            .unwrap_or(0)
            + usize::from(self.pending.len() + self.decimated_scratch.len() >= PITCH_WINDOW_SIZE);
        let mut frames = Vec::with_capacity(expected_frame_count);
        for index in 0..self.decimated_scratch.len() {
            let sample = self.decimated_scratch[index];
            let overwritten = self.pending.push(sample);
            debug_assert!(
                overwritten.is_none(),
                "frame production must prevent ring overflow"
            );
            if self.pending.len() >= PITCH_WINDOW_SIZE {
                frames.push(self.estimate_frame());
                self.pending.discard_oldest(PITCH_HOP_SIZE);
                self.next_frame_start += (PITCH_HOP_SIZE * 3) as u64;
            }
        }
        frames
    }

    pub fn reset(&mut self) {
        self.decimator.reset();
        self.dc_blocker.reset();
        self.pending.clear();
        self.dc_blocked_scratch.clear();
        self.decimated_scratch.clear();
        self.next_frame_start = 0;
        self.previous_voiced_frequency_hz = None;
    }

    fn estimate_frame(&mut self) -> PitchFrame {
        let mut window = [0.0; PITCH_WINDOW_SIZE];
        self.pending.copy_oldest_into(&mut window);
        let rms = (window.iter().map(|sample| sample * sample).sum::<f32>()
            / PITCH_WINDOW_SIZE as f32)
            .sqrt();
        let estimate = self.estimator.estimate(&window, self.pitch_config);
        let voiced = self.is_voiced(estimate, rms);
        let (frequency_hz, clarity) = match estimate {
            Some(estimate) if voiced => (Some(estimate.frequency_hz), estimate.clarity),
            Some(estimate) => (None, estimate.clarity),
            None => (None, 0.0),
        };
        if let Some(frequency_hz) = frequency_hz {
            self.previous_voiced_frequency_hz = Some(frequency_hz);
        }
        PitchFrame {
            start_sample: self.next_frame_start,
            frequency_hz,
            clarity,
            voiced,
        }
    }

    fn is_voiced(&self, estimate: Option<PitchEstimate>, rms: f32) -> bool {
        let Some(estimate) = estimate else {
            return false;
        };
        if rms < self.voiced_config.minimum_rms
            || estimate.clarity < self.voiced_config.minimum_clarity
        {
            return false;
        }
        self.previous_voiced_frequency_hz.is_none_or(|previous| {
            cents_distance(previous, estimate.frequency_hz).abs()
                <= self.voiced_config.maximum_jump_cents
        })
    }
}

fn cents_distance(reference_hz: f32, observed_hz: f32) -> f32 {
    1_200.0 * (observed_hz / reference_hz).log2()
}
