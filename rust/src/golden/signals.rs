use sha2::{Digest, Sha256};

use serde::{Deserialize, Serialize};

pub const PCM16_LE_ENCODING: &str = "pcm_s16le_interleaved_mono";
const PCM_SCALE: f64 = 32_768.0;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct GoldenCase {
    pub id: String,
    pub sample_rate_hz: u32,
    pub sample_count: usize,
    pub encoding: String,
    pub seed: Option<u64>,
    pub signal: GoldenSignal,
    pub expected: ExpectedMetrics,
    pub breakpoints: Vec<SignalBreakpoint>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum GoldenSignal {
    Sine {
        frequency_hz: f64,
        amplitude: f64,
    },
    HarmonicSeries {
        fundamental_hz: f64,
        amplitudes: Vec<f64>,
        first_harmonic: u32,
    },
    SeededNoise {
        amplitude: f64,
    },
    LinearGlide {
        start_frequency_hz: f64,
        end_frequency_hz: f64,
        amplitude: f64,
    },
    Silence,
    ClippedSine {
        frequency_hz: f64,
        amplitude: f64,
    },
    PhaseResetSine {
        frequency_hz: f64,
        amplitude: f64,
        reset_at_sample: usize,
    },
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ExpectedMetrics {
    pub voiced: Option<bool>,
    pub fundamental_hz: Option<f64>,
    pub start_frequency_hz: Option<f64>,
    pub end_frequency_hz: Option<f64>,
    pub clipped_samples: Option<usize>,
    pub rms_range: Option<[f64; 2]>,
    pub algorithm_gate: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SignalBreakpoint {
    pub sample_index: usize,
    pub kind: BreakpointKind,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum BreakpointKind {
    Discontinuity,
}

/// Returns the complete P2-01 input set in its stable manifest order.
pub fn manifest_cases() -> Vec<GoldenCase> {
    vec![
        GoldenCase {
            id: "pure_tone_a3".into(),
            sample_rate_hz: 48_000,
            sample_count: 48_000,
            encoding: PCM16_LE_ENCODING.into(),
            seed: None,
            signal: GoldenSignal::Sine {
                frequency_hz: 220.0,
                amplitude: 0.5,
            },
            expected: ExpectedMetrics {
                voiced: Some(true),
                fundamental_hz: Some(220.0),
                start_frequency_hz: None,
                end_frequency_hz: None,
                clipped_samples: Some(0),
                rms_range: Some([0.353, 0.355]),
                algorithm_gate: "steady-tone median absolute pitch error < 1 cent".into(),
            },
            breakpoints: vec![],
        },
        GoldenCase {
            id: "harmonic_series_g3".into(),
            sample_rate_hz: 48_000,
            sample_count: 48_000,
            encoding: PCM16_LE_ENCODING.into(),
            seed: None,
            signal: GoldenSignal::HarmonicSeries {
                fundamental_hz: 196.0,
                amplitudes: vec![0.28, 0.14, 0.07, 0.035],
                first_harmonic: 1,
            },
            expected: ExpectedMetrics {
                voiced: Some(true),
                fundamental_hz: Some(196.0),
                start_frequency_hz: None,
                end_frequency_hz: None,
                clipped_samples: Some(0),
                rms_range: Some([0.225, 0.229]),
                algorithm_gate: "harmonic-noise P95 < 5 cents and octave error < 0.5%".into(),
            },
            breakpoints: vec![],
        },
        GoldenCase {
            id: "missing_fundamental_g3".into(),
            sample_rate_hz: 48_000,
            sample_count: 48_000,
            encoding: PCM16_LE_ENCODING.into(),
            seed: None,
            signal: GoldenSignal::HarmonicSeries {
                fundamental_hz: 196.0,
                amplitudes: vec![0.24, 0.12, 0.06, 0.03],
                first_harmonic: 2,
            },
            expected: ExpectedMetrics {
                voiced: Some(true),
                fundamental_hz: Some(196.0),
                start_frequency_hz: None,
                end_frequency_hz: None,
                clipped_samples: Some(0),
                rms_range: Some([0.194, 0.197]),
                algorithm_gate: "must recover the absent 196 Hz fundamental without octave lock"
                    .into(),
            },
            breakpoints: vec![],
        },
        GoldenCase {
            id: "seeded_noise_7".into(),
            sample_rate_hz: 48_000,
            sample_count: 48_000,
            encoding: PCM16_LE_ENCODING.into(),
            seed: Some(7),
            signal: GoldenSignal::SeededNoise { amplitude: 0.02 },
            expected: ExpectedMetrics {
                voiced: Some(false),
                fundamental_hz: None,
                start_frequency_hz: None,
                end_frequency_hz: None,
                clipped_samples: Some(0),
                rms_range: Some([0.011, 0.012]),
                algorithm_gate: "low-energy noise voiced false positive < 1%".into(),
            },
            breakpoints: vec![],
        },
        GoldenCase {
            id: "linear_glide_a2_to_a4".into(),
            sample_rate_hz: 48_000,
            sample_count: 96_000,
            encoding: PCM16_LE_ENCODING.into(),
            seed: None,
            signal: GoldenSignal::LinearGlide {
                start_frequency_hz: 110.0,
                end_frequency_hz: 440.0,
                amplitude: 0.5,
            },
            expected: ExpectedMetrics {
                voiced: Some(true),
                fundamental_hz: None,
                start_frequency_hz: Some(110.0),
                end_frequency_hz: Some(440.0),
                clipped_samples: Some(0),
                rms_range: Some([0.353, 0.355]),
                algorithm_gate: "valid glide frames P95 < 10 cents without staircase smoothing"
                    .into(),
            },
            breakpoints: vec![],
        },
        GoldenCase {
            id: "silence".into(),
            sample_rate_hz: 48_000,
            sample_count: 48_000,
            encoding: PCM16_LE_ENCODING.into(),
            seed: None,
            signal: GoldenSignal::Silence,
            expected: ExpectedMetrics {
                voiced: Some(false),
                fundamental_hz: None,
                start_frequency_hz: None,
                end_frequency_hz: None,
                clipped_samples: Some(0),
                rms_range: Some([0.0, 0.0]),
                algorithm_gate: "silence voiced false positive < 1%".into(),
            },
            breakpoints: vec![],
        },
        GoldenCase {
            id: "clipped_sine_a3".into(),
            sample_rate_hz: 48_000,
            sample_count: 48_000,
            encoding: PCM16_LE_ENCODING.into(),
            seed: None,
            signal: GoldenSignal::ClippedSine {
                frequency_hz: 220.0,
                amplitude: 1.25,
            },
            expected: ExpectedMetrics {
                voiced: Some(true),
                fundamental_hz: Some(220.0),
                start_frequency_hz: None,
                end_frequency_hz: None,
                clipped_samples: Some(19_640),
                rms_range: Some([0.794, 0.796]),
                algorithm_gate: "must raise clipping quality evidence before interpretation".into(),
            },
            breakpoints: vec![],
        },
        GoldenCase {
            id: "phase_reset_breakpoint_a3".into(),
            sample_rate_hz: 48_000,
            sample_count: 48_000,
            encoding: PCM16_LE_ENCODING.into(),
            seed: None,
            signal: GoldenSignal::PhaseResetSine {
                frequency_hz: 220.0,
                amplitude: 0.5,
                reset_at_sample: 24_123,
            },
            expected: ExpectedMetrics {
                voiced: Some(true),
                fundamental_hz: Some(220.0),
                start_frequency_hz: None,
                end_frequency_hz: None,
                clipped_samples: Some(0),
                rms_range: Some([0.353, 0.355]),
                algorithm_gate:
                    "a discontinuity at sample 24123 invalidates cross-breakpoint metrics".into(),
            },
            breakpoints: vec![SignalBreakpoint {
                sample_index: 24_123,
                kind: BreakpointKind::Discontinuity,
            }],
        },
    ]
}

pub fn generate_case(case: &GoldenCase) -> Vec<i16> {
    let sample_rate = case.sample_rate_hz as f64;
    let sample_count = case.sample_count;
    match &case.signal {
        GoldenSignal::Sine {
            frequency_hz,
            amplitude,
        }
        | GoldenSignal::ClippedSine {
            frequency_hz,
            amplitude,
        } => (0..sample_count)
            .map(|index| sine(*frequency_hz, *amplitude, index, sample_rate))
            .collect(),
        GoldenSignal::HarmonicSeries {
            fundamental_hz,
            amplitudes,
            first_harmonic,
        } => (0..sample_count)
            .map(|index| {
                let time = index as f64 / sample_rate;
                let value = amplitudes
                    .iter()
                    .enumerate()
                    .fold(0.0, |sum, (offset, amplitude)| {
                        let harmonic = *first_harmonic as usize + offset;
                        sum + amplitude
                            * (std::f64::consts::TAU * *fundamental_hz * harmonic as f64 * time)
                                .sin()
                    });
                pcm16(value)
            })
            .collect(),
        GoldenSignal::SeededNoise { amplitude } => {
            let mut state = case.seed.expect("seeded noise requires a manifest seed");
            (0..sample_count)
                .map(|_| {
                    state = xorshift64star(state);
                    let unit = ((state >> 11) as f64) * (1.0 / ((1_u64 << 53) as f64));
                    pcm16((unit * 2.0 - 1.0) * amplitude)
                })
                .collect()
        }
        GoldenSignal::LinearGlide {
            start_frequency_hz,
            end_frequency_hz,
            amplitude,
        } => (0..sample_count)
            .map(|index| {
                let time = index as f64 / sample_rate;
                let duration = sample_count as f64 / sample_rate;
                let rate = (end_frequency_hz - start_frequency_hz) / duration;
                let cycles = start_frequency_hz * time + 0.5 * rate * time * time;
                pcm16(amplitude * (std::f64::consts::TAU * cycles).sin())
            })
            .collect(),
        GoldenSignal::Silence => vec![0; sample_count],
        GoldenSignal::PhaseResetSine {
            frequency_hz,
            amplitude,
            reset_at_sample,
        } => (0..sample_count)
            .map(|index| {
                let local_index = if index < *reset_at_sample {
                    index
                } else {
                    index - reset_at_sample
                };
                sine(*frequency_hz, *amplitude, local_index, sample_rate)
            })
            .collect(),
    }
}

pub fn pcm16_sha256(samples: &[i16]) -> String {
    let mut hasher = Sha256::new();
    for sample in samples {
        hasher.update(sample.to_le_bytes());
    }
    format!("{:x}", hasher.finalize())
}

fn sine(frequency_hz: f64, amplitude: f64, index: usize, sample_rate: f64) -> i16 {
    let phase = std::f64::consts::TAU * frequency_hz * index as f64 / sample_rate;
    pcm16(amplitude * phase.sin())
}

fn pcm16(sample: f64) -> i16 {
    let scaled = (sample.clamp(-1.0, 1.0 - 1.0 / PCM_SCALE) * PCM_SCALE).round();
    scaled as i16
}

fn xorshift64star(state: u64) -> u64 {
    assert_ne!(state, 0, "xorshift64* seed must be non-zero");
    let mut next = state;
    next ^= next >> 12;
    next ^= next << 25;
    next ^= next >> 27;
    next.wrapping_mul(0x2545_F491_4F6C_DD1D)
}
