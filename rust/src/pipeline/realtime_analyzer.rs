use std::sync::Arc;

use rustfft::{num_complex::Complex32, Fft, FftPlanner};

use crate::model::AnalysisFrame;

pub const WINDOW_SIZE: usize = 2048;
pub const HOP_SIZE: usize = 512;
const AUTOCORRELATION_FFT_SIZE: usize = WINDOW_SIZE * 2;
const MIN_PITCH_HZ: f32 = 60.0;
const MAX_PITCH_HZ: f32 = 1000.0;
const MIN_PITCH_CLARITY: f32 = 0.55;

pub struct RealtimeAnalyzerCore {
    sample_rate: u32,
    pending: Vec<f32>,
    next_frame_start: u64,
    hann: Vec<f32>,
    spectrum_buffer: Vec<Complex32>,
    autocorrelation_buffer: Vec<Complex32>,
    spectrum_fft: Arc<dyn Fft<f32>>,
    autocorrelation_forward: Arc<dyn Fft<f32>>,
    autocorrelation_inverse: Arc<dyn Fft<f32>>,
}

impl RealtimeAnalyzerCore {
    pub fn new(sample_rate: u32) -> Self {
        assert!(sample_rate > 0, "sample rate must be positive");
        let mut planner = FftPlanner::new();
        let spectrum_fft = planner.plan_fft_forward(WINDOW_SIZE);
        let autocorrelation_forward = planner.plan_fft_forward(AUTOCORRELATION_FFT_SIZE);
        let autocorrelation_inverse = planner.plan_fft_inverse(AUTOCORRELATION_FFT_SIZE);
        let hann = (0..WINDOW_SIZE)
            .map(|index| {
                0.5 - 0.5 * (std::f32::consts::TAU * index as f32 / (WINDOW_SIZE - 1) as f32).cos()
            })
            .collect();
        Self {
            sample_rate,
            pending: Vec::with_capacity(WINDOW_SIZE + HOP_SIZE),
            next_frame_start: 0,
            hann,
            spectrum_buffer: vec![Complex32::default(); WINDOW_SIZE],
            autocorrelation_buffer: vec![Complex32::default(); AUTOCORRELATION_FFT_SIZE],
            spectrum_fft,
            autocorrelation_forward,
            autocorrelation_inverse,
        }
    }

    pub fn push_pcm16(&mut self, pcm: &[i16]) -> Vec<AnalysisFrame> {
        self.pending
            .extend(pcm.iter().map(|sample| *sample as f32 / 32768.0));
        let frame_count = self
            .pending
            .len()
            .saturating_sub(WINDOW_SIZE)
            .checked_div(HOP_SIZE)
            .unwrap_or(0)
            + usize::from(self.pending.len() >= WINDOW_SIZE);
        let mut frames = Vec::with_capacity(frame_count);
        while self.pending.len() >= WINDOW_SIZE {
            frames.push(self.analyze_current_frame());
            self.pending.drain(..HOP_SIZE);
            self.next_frame_start += HOP_SIZE as u64;
        }
        frames
    }

    pub fn reset(&mut self) {
        self.pending.clear();
        self.next_frame_start = 0;
    }

    fn analyze_current_frame(&mut self) -> AnalysisFrame {
        let frame = &self.pending[..WINDOW_SIZE];
        let mut sum_squares = 0.0_f32;
        let mut peak = 0.0_f32;
        for sample in frame {
            sum_squares += sample * sample;
            peak = peak.max(sample.abs());
        }
        let rms = (sum_squares / WINDOW_SIZE as f32).sqrt();

        for (index, (sample, window)) in frame.iter().zip(&self.hann).enumerate() {
            self.spectrum_buffer[index] = Complex32::new(sample * window, 0.0);
        }
        self.spectrum_fft.process(&mut self.spectrum_buffer);
        let bin_hz = self.sample_rate as f32 / WINDOW_SIZE as f32;
        let mut magnitude_sum = 0.0_f32;
        let mut weighted_sum = 0.0_f32;
        for (index, bin) in self.spectrum_buffer[..=WINDOW_SIZE / 2].iter().enumerate() {
            let magnitude = bin.norm();
            magnitude_sum += magnitude;
            weighted_sum += magnitude * index as f32 * bin_hz;
        }
        let spectral_centroid_hz = if magnitude_sum > f32::EPSILON {
            weighted_sum / magnitude_sum
        } else {
            0.0
        };

        let (pitch_hz, pitch_clarity) = self.estimate_pitch();
        AnalysisFrame {
            start_sample: self.next_frame_start,
            rms,
            peak,
            spectral_centroid_hz,
            pitch_hz,
            pitch_clarity,
        }
    }

    fn estimate_pitch(&mut self) -> (Option<f32>, f32) {
        let frame = &self.pending[..WINDOW_SIZE];
        let mean = frame.iter().sum::<f32>() / WINDOW_SIZE as f32;
        self.autocorrelation_buffer.fill(Complex32::default());
        for (target, sample) in self.autocorrelation_buffer[..WINDOW_SIZE]
            .iter_mut()
            .zip(frame)
        {
            target.re = sample - mean;
        }
        self.autocorrelation_forward
            .process(&mut self.autocorrelation_buffer);
        for bin in &mut self.autocorrelation_buffer {
            *bin = Complex32::new(bin.norm_sqr(), 0.0);
        }
        self.autocorrelation_inverse
            .process(&mut self.autocorrelation_buffer);

        let zero_lag = self.autocorrelation_buffer[0].re;
        if zero_lag <= f32::EPSILON {
            return (None, 0.0);
        }
        let min_lag = (self.sample_rate as f32 / MAX_PITCH_HZ).floor() as usize;
        let max_lag =
            ((self.sample_rate as f32 / MIN_PITCH_HZ).ceil() as usize).min(WINDOW_SIZE - 2);
        let mut best_lag = min_lag.max(1);
        let mut best_clarity = f32::NEG_INFINITY;
        for lag in min_lag.max(1)..=max_lag {
            let clarity = self.autocorrelation_buffer[lag].re / zero_lag;
            let previous = self.autocorrelation_buffer[lag - 1].re / zero_lag;
            let next = self.autocorrelation_buffer[lag + 1].re / zero_lag;
            if clarity >= previous && clarity > next && clarity > best_clarity {
                best_clarity = clarity;
                best_lag = lag;
            }
        }
        if best_clarity < MIN_PITCH_CLARITY {
            return (None, best_clarity.max(0.0));
        }

        let left = self.autocorrelation_buffer[best_lag - 1].re / zero_lag;
        let center = self.autocorrelation_buffer[best_lag].re / zero_lag;
        let right = self.autocorrelation_buffer[best_lag + 1].re / zero_lag;
        let denominator = left - 2.0 * center + right;
        let offset = if denominator.abs() > 1.0e-12 {
            0.5 * (left - right) / denominator
        } else {
            0.0
        };
        let refined_lag = best_lag as f32 + offset.clamp(-0.5, 0.5);
        (Some(self.sample_rate as f32 / refined_lag), best_clarity)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sine(sample_count: usize, frequency: f32) -> Vec<i16> {
        (0..sample_count)
            .map(|index| {
                let phase = std::f32::consts::TAU * frequency * index as f32 / 48_000.0;
                (phase.sin() * 16_000.0) as i16
            })
            .collect()
    }

    #[test]
    fn detects_a_220_hz_sine() {
        let mut analyzer = RealtimeAnalyzerCore::new(48_000);
        let frames = analyzer.push_pcm16(&sine(48_000, 220.0));
        let pitch = frames[frames.len() / 2].pitch_hz.unwrap();
        assert!((pitch - 220.0).abs() < 1.0, "pitch was {pitch}");
        assert!(frames[0].rms > 0.3);
        assert!(frames[0].peak > 0.45);
    }

    #[test]
    fn arbitrary_chunking_keeps_the_frame_sequence() {
        let signal = sine(48_000 * 3, 233.08);
        let mut whole = RealtimeAnalyzerCore::new(48_000);
        let expected = whole.push_pcm16(&signal);

        let mut chunked = RealtimeAnalyzerCore::new(48_000);
        let pattern = [1, 17, 511, 1024, 37, 2048, 3, 777];
        let mut actual = Vec::new();
        let mut offset = 0;
        let mut pattern_index = 0;
        while offset < signal.len() {
            let end = (offset + pattern[pattern_index % pattern.len()]).min(signal.len());
            actual.extend(chunked.push_pcm16(&signal[offset..end]));
            offset = end;
            pattern_index += 1;
        }

        assert_eq!(actual, expected);
    }
}
