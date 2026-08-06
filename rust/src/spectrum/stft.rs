use std::sync::Arc;

use rustfft::{num_complex::Complex32, Fft, FftPlanner};

use crate::{
    signal::{ring_buffer::RingBuffer, window::periodic_hann},
    spectrum::{band_index_for_frequency, ui_bin_for_frequency, BAND_POWER_COUNT, UI_BIN_COUNT},
};

pub const SPECTRUM_SAMPLE_RATE_HZ: u32 = 48_000;
pub const SPECTRUM_WINDOW_SIZE: usize = 2_048;
pub const SPECTRUM_HOP_SIZE: usize = 480;
const DBFS_FLOOR: f32 = -120.0;

#[derive(Clone, Debug, PartialEq)]
pub struct SpectrumFrame {
    pub start_sample: u64,
    /// Window-energy-normalized total full-band power in dBFS.
    pub total_power_dbfs: f32,
    pub spectral_centroid_hz: f32,
    pub band_powers_dbfs: [f32; BAND_POWER_COUNT],
    pub ui_bins_dbfs: [f32; UI_BIN_COUNT],
}

/// Streaming 48 kHz STFT with periodic Hann windows and 10 ms frame hops.
pub struct SpectrumAnalyzer {
    pending: RingBuffer<f32>,
    frame_buffer: Vec<f32>,
    window: Vec<f32>,
    window_energy: f32,
    fft_buffer: Vec<Complex32>,
    fft: Arc<dyn Fft<f32>>,
    band_for_fft_bin: Vec<Option<usize>>,
    ui_bin_for_fft_bin: Vec<Option<usize>>,
    next_frame_start: u64,
}

impl SpectrumAnalyzer {
    pub fn new() -> Self {
        let window = periodic_hann(SPECTRUM_WINDOW_SIZE);
        let window_energy = window.iter().map(|sample| sample * sample).sum();
        let mut planner = FftPlanner::new();
        let bin_width_hz = SPECTRUM_SAMPLE_RATE_HZ as f32 / SPECTRUM_WINDOW_SIZE as f32;
        let bin_count = SPECTRUM_WINDOW_SIZE / 2 + 1;
        let band_for_fft_bin = (0..bin_count)
            .map(|bin| band_index_for_frequency(bin as f32 * bin_width_hz))
            .collect();
        let ui_bin_for_fft_bin = (0..bin_count)
            .map(|bin| {
                ui_bin_for_frequency(
                    bin as f32 * bin_width_hz,
                    SPECTRUM_SAMPLE_RATE_HZ as f32 / 2.0,
                )
            })
            .collect();
        Self {
            pending: RingBuffer::new(SPECTRUM_WINDOW_SIZE + SPECTRUM_HOP_SIZE),
            frame_buffer: vec![0.0; SPECTRUM_WINDOW_SIZE],
            window,
            window_energy,
            fft_buffer: vec![Complex32::default(); SPECTRUM_WINDOW_SIZE],
            fft: planner.plan_fft_forward(SPECTRUM_WINDOW_SIZE),
            band_for_fft_bin,
            ui_bin_for_fft_bin,
            next_frame_start: 0,
        }
    }

    pub fn push(&mut self, input: &[f32]) -> Vec<SpectrumFrame> {
        let expected_frame_count = (self.pending.len() + input.len())
            .saturating_sub(SPECTRUM_WINDOW_SIZE)
            .checked_div(SPECTRUM_HOP_SIZE)
            .unwrap_or(0)
            + usize::from(self.pending.len() + input.len() >= SPECTRUM_WINDOW_SIZE);
        let mut frames = Vec::with_capacity(expected_frame_count);
        for &sample in input {
            let overwritten = self.pending.push(sample);
            debug_assert!(
                overwritten.is_none(),
                "frame production must prevent ring overflow"
            );
            if self.pending.len() >= SPECTRUM_WINDOW_SIZE {
                frames.push(self.analyze_current_frame());
                self.pending.discard_oldest(SPECTRUM_HOP_SIZE);
                self.next_frame_start += SPECTRUM_HOP_SIZE as u64;
            }
        }
        frames
    }

    pub fn reset(&mut self) {
        self.pending.clear();
        self.next_frame_start = 0;
    }

    fn analyze_current_frame(&mut self) -> SpectrumFrame {
        self.pending.copy_oldest_into(&mut self.frame_buffer);
        for (target, (sample, window)) in self
            .fft_buffer
            .iter_mut()
            .zip(self.frame_buffer.iter().zip(&self.window))
        {
            *target = Complex32::new(sample * window, 0.0);
        }
        self.fft.process(&mut self.fft_buffer);

        let bin_width_hz = SPECTRUM_SAMPLE_RATE_HZ as f32 / SPECTRUM_WINDOW_SIZE as f32;
        let nyquist_bin = SPECTRUM_WINDOW_SIZE / 2;
        let mut total_power = 0.0;
        let mut centroid_numerator = 0.0;
        let mut band_powers = [0.0; BAND_POWER_COUNT];
        let mut ui_powers = [0.0; UI_BIN_COUNT];
        for (bin, value) in self.fft_buffer[..=nyquist_bin].iter().enumerate() {
            let frequency_hz = bin as f32 * bin_width_hz;
            // A one-sided, window-energy-normalized power spectrum.  Its bins
            // sum to input mean-square power, including DC and Nyquist once.
            let sidedness = if bin == 0 || bin == nyquist_bin {
                1.0
            } else {
                2.0
            };
            let power =
                sidedness * value.norm_sqr() / (SPECTRUM_WINDOW_SIZE as f32 * self.window_energy);
            total_power += power;
            centroid_numerator += frequency_hz * power;
            if let Some(band) = self.band_for_fft_bin[bin] {
                band_powers[band] += power;
            }
            if let Some(ui_bin) = self.ui_bin_for_fft_bin[bin] {
                ui_powers[ui_bin] += power;
            }
        }

        SpectrumFrame {
            start_sample: self.next_frame_start,
            total_power_dbfs: power_to_dbfs(total_power),
            spectral_centroid_hz: if total_power > f32::EPSILON {
                centroid_numerator / total_power
            } else {
                0.0
            },
            band_powers_dbfs: band_powers.map(power_to_dbfs),
            ui_bins_dbfs: ui_powers.map(power_to_dbfs),
        }
    }
}

impl Default for SpectrumAnalyzer {
    fn default() -> Self {
        Self::new()
    }
}

fn power_to_dbfs(power: f32) -> f32 {
    (10.0 * power.max(10.0_f32.powf(DBFS_FLOOR / 10.0)).log10()).max(DBFS_FLOOR)
}
