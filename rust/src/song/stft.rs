use super::pipeline::{SeparationError, SeparationFailureReason, StereoWaveform};
use rustfft::{num_complex::Complex32, FftPlanner};

pub const FFT_SIZE: usize = 4096;
pub const HOP_SIZE: usize = 1024;
pub const BIN_COUNT: usize = FFT_SIZE / 2 + 1;
const CENTER_PADDING: usize = FFT_SIZE / 2;

#[derive(Clone, Debug)]
pub struct StereoSpectrogram {
    pub frames: usize,
    pub values: Vec<Complex32>,
}

impl StereoSpectrogram {
    pub fn index(&self, channel: usize, bin: usize, frame: usize) -> usize {
        (channel * BIN_COUNT + bin) * self.frames + frame
    }

    pub fn magnitudes_onnx_layout(&self) -> Vec<f32> {
        self.values.iter().map(|value| value.norm()).collect()
    }
}

pub fn stft(input: &StereoWaveform) -> StereoSpectrogram {
    let padded_length = input.frame_count() + 2 * CENTER_PADDING;
    let frames = 1 + (padded_length - FFT_SIZE) / HOP_SIZE;
    let window = periodic_hann();
    let mut planner = FftPlanner::<f32>::new();
    let fft = planner.plan_fft_forward(FFT_SIZE);
    let mut values = vec![Complex32::default(); 2 * BIN_COUNT * frames];
    let mut buffer = vec![Complex32::default(); FFT_SIZE];
    for channel in 0..2 {
        for frame in 0..frames {
            let start = frame * HOP_SIZE;
            for index in 0..FFT_SIZE {
                let padded_index = start + index;
                let source_index = reflect_index(
                    padded_index as isize - CENTER_PADDING as isize,
                    input.frame_count(),
                );
                buffer[index] = Complex32::new(
                    input.samples[source_index * 2 + channel] * window[index],
                    0.0,
                );
            }
            fft.process(&mut buffer);
            for bin in 0..BIN_COUNT {
                values[(channel * BIN_COUNT + bin) * frames + frame] = buffer[bin];
            }
        }
    }
    StereoSpectrogram { frames, values }
}

pub fn istft(
    spectrum: &StereoSpectrogram,
    output_frames: usize,
) -> Result<StereoWaveform, SeparationError> {
    if spectrum.frames == 0 || spectrum.values.len() != 2 * BIN_COUNT * spectrum.frames {
        return Err(SeparationError::new(
            SeparationFailureReason::ContractMismatch,
            "istft",
            "spectrogram shape differs from the stereo STFT contract",
        ));
    }
    let padded_length = (spectrum.frames - 1) * HOP_SIZE + FFT_SIZE;
    let window = periodic_hann();
    let mut planner = FftPlanner::<f32>::new();
    let inverse = planner.plan_fft_inverse(FFT_SIZE);
    let mut output = vec![0.0_f32; padded_length * 2];
    let mut weights = vec![0.0_f32; padded_length];
    let mut buffer = vec![Complex32::default(); FFT_SIZE];
    for frame in 0..spectrum.frames {
        for channel in 0..2 {
            for (bin, slot) in buffer.iter_mut().enumerate().take(BIN_COUNT) {
                *slot = spectrum.values[spectrum.index(channel, bin, frame)];
            }
            for bin in BIN_COUNT..FFT_SIZE {
                buffer[bin] = buffer[FFT_SIZE - bin].conj();
            }
            inverse.process(&mut buffer);
            let start = frame * HOP_SIZE;
            for index in 0..FFT_SIZE {
                output[(start + index) * 2 + channel] +=
                    buffer[index].re / FFT_SIZE as f32 * window[index];
            }
        }
        let start = frame * HOP_SIZE;
        for index in 0..FFT_SIZE {
            weights[start + index] += window[index] * window[index];
        }
    }
    let mut cropped = Vec::with_capacity(output_frames * 2);
    for frame in 0..output_frames {
        let padded_index = frame + CENTER_PADDING;
        let normalization = weights[padded_index].max(1.0e-12);
        cropped.push(output[padded_index * 2] / normalization);
        cropped.push(output[padded_index * 2 + 1] / normalization);
    }
    StereoWaveform::new(44_100, cropped)
}

fn periodic_hann() -> Vec<f32> {
    (0..FFT_SIZE)
        .map(|index| 0.5 - 0.5 * (std::f32::consts::TAU * index as f32 / FFT_SIZE as f32).cos())
        .collect()
}

fn reflect_index(index: isize, length: usize) -> usize {
    debug_assert!(length > 0);
    if length == 1 {
        return 0;
    }
    let period = 2 * (length - 1) as isize;
    let folded = index.rem_euclid(period);
    if folded < length as isize {
        folded as usize
    } else {
        (period - folded) as usize
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stft_round_trip_preserves_length_and_samples() {
        let frames = 44_100;
        let samples: Vec<f32> = (0..frames)
            .flat_map(|index| {
                let left = 0.3 * (std::f32::consts::TAU * 220.0 * index as f32 / 44_100.0).sin();
                let right = 0.2 * (std::f32::consts::TAU * 330.0 * index as f32 / 44_100.0).sin();
                [left, right]
            })
            .collect();
        let input = StereoWaveform::new(44_100, samples).expect("valid waveform");
        let spectrum = stft(&input);
        assert_eq!(spectrum.frames, 44);
        let output = istft(&spectrum, frames).expect("ISTFT should complete");
        let max_abs = input
            .samples
            .iter()
            .zip(&output.samples)
            .map(|(left, right)| (left - right).abs())
            .fold(0.0_f32, f32::max);
        assert!(max_abs < 1.0e-5, "round-trip max abs {max_abs}");
    }

    #[test]
    fn reflection_padding_handles_very_short_input() {
        let input =
            StereoWaveform::new(44_100, vec![0.25, -0.25]).expect("single stereo frame is valid");
        let spectrum = stft(&input);
        let output = istft(&spectrum, 1).expect("short ISTFT should complete");
        assert!((output.samples[0] - 0.25).abs() < 1.0e-5);
        assert!((output.samples[1] + 0.25).abs() < 1.0e-5);
    }
}
