//! The low-latency 48 kHz to 16 kHz pitch-branch decimator.

use super::ring_buffer::RingBuffer;

pub const INPUT_SAMPLE_RATE_HZ: u32 = 48_000;
pub const OUTPUT_SAMPLE_RATE_HZ: u32 = 16_000;
const DECIMATION_FACTOR: usize = 3;
const TAP_COUNT: usize = 63;
const CUTOFF_HZ: f32 = 7_000.0;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ResamplerError {
    UnsupportedInputRate { actual_hz: u32 },
}

/// Causal 63-tap Hamming-windowed sinc low-pass FIR, evaluated in three phases.
///
/// Its group delay is 31 input samples (about 0.65 ms).  Non-integer sample-rate
/// conversion intentionally remains unsupported until a future card evaluates a
/// dedicated streaming resampler such as rubato.
pub struct PolyphaseDecimator3 {
    phases: [Vec<f32>; DECIMATION_FACTOR],
    history: RingBuffer<f32>,
    input_count: usize,
}

impl PolyphaseDecimator3 {
    pub fn new(input_sample_rate_hz: u32) -> Result<Self, ResamplerError> {
        if input_sample_rate_hz != INPUT_SAMPLE_RATE_HZ {
            return Err(ResamplerError::UnsupportedInputRate {
                actual_hz: input_sample_rate_hz,
            });
        }
        let coefficients = low_pass_coefficients();
        let phases = std::array::from_fn(|phase| {
            coefficients
                .iter()
                .skip(phase)
                .step_by(DECIMATION_FACTOR)
                .copied()
                .collect()
        });
        Ok(Self {
            phases,
            history: RingBuffer::new(TAP_COUNT),
            input_count: 0,
        })
    }

    pub fn output_sample_rate_hz(&self) -> u32 {
        OUTPUT_SAMPLE_RATE_HZ
    }

    pub fn group_delay_input_samples(&self) -> usize {
        (TAP_COUNT - 1) / 2
    }

    pub fn reset(&mut self) {
        self.history.clear();
        self.input_count = 0;
    }

    /// Appends decimated samples to `output` without allocating internal history.
    pub fn process_into(&mut self, input: &[f32], output: &mut Vec<f32>) {
        for &sample in input {
            let overwritten = self.history.push(sample);
            debug_assert!(overwritten.is_none() || self.history.len() == TAP_COUNT);
            self.input_count += 1;
            if self.input_count.is_multiple_of(DECIMATION_FACTOR) {
                output.push(self.convolve_newest());
            }
        }
    }

    fn convolve_newest(&self) -> f32 {
        self.phases
            .iter()
            .enumerate()
            .map(|(phase, coefficients)| {
                coefficients
                    .iter()
                    .enumerate()
                    .map(|(index, coefficient)| {
                        self.history
                            .get_from_newest(index * DECIMATION_FACTOR + phase)
                            .unwrap_or(0.0)
                            * coefficient
                    })
                    .sum::<f32>()
            })
            .sum()
    }
}

fn low_pass_coefficients() -> Vec<f32> {
    let cutoff = CUTOFF_HZ / INPUT_SAMPLE_RATE_HZ as f32;
    let midpoint = (TAP_COUNT - 1) as f32 / 2.0;
    let mut coefficients: Vec<f32> = (0..TAP_COUNT)
        .map(|index| {
            let distance = index as f32 - midpoint;
            let sinc = if distance == 0.0 {
                2.0 * cutoff
            } else {
                (std::f32::consts::TAU * cutoff * distance).sin()
                    / (std::f32::consts::PI * distance)
            };
            let hamming =
                0.54 - 0.46 * (std::f32::consts::TAU * index as f32 / (TAP_COUNT - 1) as f32).cos();
            sinc * hamming
        })
        .collect();
    let gain = coefficients.iter().sum::<f32>();
    for coefficient in &mut coefficients {
        *coefficient /= gain;
    }
    coefficients
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sine(frequency_hz: f32, sample_count: usize) -> Vec<f32> {
        (0..sample_count)
            .map(|index| {
                (std::f32::consts::TAU * frequency_hz * index as f32 / INPUT_SAMPLE_RATE_HZ as f32)
                    .sin()
            })
            .collect()
    }

    fn rms(input: &[f32]) -> f32 {
        (input.iter().map(|sample| sample * sample).sum::<f32>() / input.len() as f32).sqrt()
    }

    #[test]
    fn downsampling_is_chunk_invariant_and_exactly_three_to_one() {
        let input = sine(1_000.0, 48_000);
        let mut whole = PolyphaseDecimator3::new(48_000).unwrap();
        let mut expected = Vec::new();
        whole.process_into(&input, &mut expected);
        assert_eq!(expected.len(), 16_000);

        let mut chunked = PolyphaseDecimator3::new(48_000).unwrap();
        let mut actual = Vec::new();
        for chunk in input.chunks(317) {
            chunked.process_into(chunk, &mut actual);
        }
        assert_eq!(actual, expected);
    }

    #[test]
    fn rejects_frequency_above_the_16khz_nyquist_limit() {
        let mut low = PolyphaseDecimator3::new(48_000).unwrap();
        let mut low_output = Vec::new();
        low.process_into(&sine(1_000.0, 48_000), &mut low_output);

        let mut high = PolyphaseDecimator3::new(48_000).unwrap();
        let mut high_output = Vec::new();
        high.process_into(&sine(10_000.0, 48_000), &mut high_output);

        let settled = 64;
        let rejection_db =
            20.0 * (rms(&high_output[settled..]) / rms(&low_output[settled..])).log10();
        assert!(
            rejection_db < -45.0,
            "alias rejection was {rejection_db} dB"
        );
    }

    #[test]
    fn rejects_non_integer_ratio_requests() {
        assert!(matches!(
            PolyphaseDecimator3::new(44_100),
            Err(ResamplerError::UnsupportedInputRate { actual_hz: 44_100 })
        ));
    }
}
