use super::{resample::resample_to_44k1, stft};
use rustfft::num_complex::Complex32;
use std::fmt;

pub const TARGET_SAMPLE_RATE: u32 = 44_100;
const MODEL_CHUNK_FRAMES: usize = 300;
const MODEL_OVERLAP_FRAMES: usize = 64;
const MODEL_MINIMUM_FRAMES: usize = 32;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum SeparationFailureReason {
    RightsAcknowledgementRequired,
    InputNotFound,
    UnsupportedFormat,
    FormatChanged,
    DecodeFailed,
    ModelNotFound,
    ModelHashMismatch,
    RuntimeUnavailable,
    BackendIncompatible,
    ContractMismatch,
    NumericalFailure,
    ResourceLimitExceeded,
    Cancelled,
    IoFailure,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SeparationError {
    pub reason: SeparationFailureReason,
    pub operation: &'static str,
    pub detail: String,
}

impl SeparationError {
    pub fn new(
        reason: SeparationFailureReason,
        operation: &'static str,
        detail: impl Into<String>,
    ) -> Self {
        Self {
            reason,
            operation,
            detail: detail.into(),
        }
    }

    pub fn cancelled(operation: &'static str) -> Self {
        Self::new(
            SeparationFailureReason::Cancelled,
            operation,
            "song separation was cancelled before completion",
        )
    }

    pub fn io(operation: &'static str, detail: &'static str, error: std::io::Error) -> Self {
        Self::new(
            SeparationFailureReason::IoFailure,
            operation,
            format!("{detail}: {}", error.kind()),
        )
    }
}

impl fmt::Display for SeparationError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}: {}", self.operation, self.detail)
    }
}

impl std::error::Error for SeparationError {}

#[derive(Clone, Debug, PartialEq)]
pub struct StereoWaveform {
    pub sample_rate: u32,
    pub samples: Vec<f32>,
}

impl StereoWaveform {
    pub fn new(sample_rate: u32, samples: Vec<f32>) -> Result<Self, SeparationError> {
        if sample_rate == 0 || samples.is_empty() || !samples.len().is_multiple_of(2) {
            return Err(SeparationError::new(
                SeparationFailureReason::ContractMismatch,
                "validate_waveform",
                "stereo waveform must have a sample rate and complete non-empty frames",
            ));
        }
        if samples.iter().any(|sample| !sample.is_finite()) {
            return Err(SeparationError::new(
                SeparationFailureReason::NumericalFailure,
                "validate_waveform",
                "waveform contains non-finite samples",
            ));
        }
        Ok(Self {
            sample_rate,
            samples,
        })
    }

    pub fn frame_count(&self) -> usize {
        self.samples.len() / 2
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum SeparationStage {
    Decoding,
    Resampling,
    Transforming,
    Inference,
    Reconstructing,
    Writing,
    Completed,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct SeparationProgress {
    pub stage: SeparationStage,
    pub completed_units: u64,
    pub total_units: u64,
}

impl SeparationProgress {
    pub fn fraction(stage: SeparationStage, completed: usize, total: usize) -> Self {
        Self {
            stage,
            completed_units: completed as u64,
            total_units: total.max(1) as u64,
        }
    }
}

pub trait MagnitudeModel {
    fn model_id(&self) -> &str;

    /// Input/output layout is contiguous `[1, 2, 2049, frames]` f32.
    fn infer(&mut self, input: &[f32], frames: usize) -> Result<Vec<f32>, SeparationError>;
}

#[derive(Clone, Debug, PartialEq)]
pub struct WaveformSeparation {
    pub model_id: String,
    pub vocals: StereoWaveform,
    pub accompaniment: StereoWaveform,
    pub chunk_count: usize,
    pub algorithm_version: &'static str,
}

pub fn separate_waveform<M, C, P>(
    input: &StereoWaveform,
    model: &mut M,
    mut should_cancel: C,
    mut on_progress: P,
) -> Result<WaveformSeparation, SeparationError>
where
    M: MagnitudeModel,
    C: FnMut() -> bool,
    P: FnMut(SeparationProgress),
{
    if should_cancel() {
        return Err(SeparationError::cancelled("prepare_song"));
    }
    let normalized = resample_to_44k1(input, &mut should_cancel, &mut on_progress)?;
    on_progress(SeparationProgress::fraction(
        SeparationStage::Transforming,
        0,
        1,
    ));
    let mixture = stft::stft(&normalized);
    let magnitudes = mixture.magnitudes_onnx_layout();
    if should_cancel() {
        return Err(SeparationError::cancelled("transform_song"));
    }
    on_progress(SeparationProgress::fraction(
        SeparationStage::Transforming,
        1,
        1,
    ));
    let (estimated_magnitudes, chunk_count) = infer_chunked(
        model,
        &magnitudes,
        mixture.frames,
        &mut should_cancel,
        &mut on_progress,
    )?;
    let mut vocal_spectrum = mixture.clone();
    let mut accompaniment_spectrum = mixture.clone();
    for index in 0..mixture.values.len() {
        let mix = mixture.values[index];
        let mix_magnitude = magnitudes[index];
        let estimated_magnitude = estimated_magnitudes[index].max(0.0);
        let vocal = if mix_magnitude > 1.0e-12 {
            mix * (estimated_magnitude / mix_magnitude)
        } else {
            Complex32::default()
        };
        if !vocal.re.is_finite() || !vocal.im.is_finite() {
            return Err(SeparationError::new(
                SeparationFailureReason::NumericalFailure,
                "compose_stems",
                "model output produced a non-finite complex stem",
            ));
        }
        vocal_spectrum.values[index] = vocal;
        accompaniment_spectrum.values[index] = mix - vocal;
    }
    if should_cancel() {
        return Err(SeparationError::cancelled("compose_stems"));
    }
    on_progress(SeparationProgress::fraction(
        SeparationStage::Reconstructing,
        0,
        2,
    ));
    let vocals = stft::istft(&vocal_spectrum, normalized.frame_count())?;
    on_progress(SeparationProgress::fraction(
        SeparationStage::Reconstructing,
        1,
        2,
    ));
    let accompaniment = stft::istft(&accompaniment_spectrum, normalized.frame_count())?;
    on_progress(SeparationProgress::fraction(
        SeparationStage::Reconstructing,
        2,
        2,
    ));
    Ok(WaveformSeparation {
        model_id: model.model_id().to_owned(),
        vocals,
        accompaniment,
        chunk_count,
        algorithm_version: "umxhq-stft4096-hop1024-mixphase-residual-v1",
    })
}

fn infer_chunked<M, C, P>(
    model: &mut M,
    magnitudes: &[f32],
    total_frames: usize,
    should_cancel: &mut C,
    on_progress: &mut P,
) -> Result<(Vec<f32>, usize), SeparationError>
where
    M: MagnitudeModel,
    C: FnMut() -> bool,
    P: FnMut(SeparationProgress),
{
    let stride = MODEL_CHUNK_FRAMES - MODEL_OVERLAP_FRAMES;
    let starts: Vec<usize> = if total_frames <= MODEL_CHUNK_FRAMES {
        vec![0]
    } else {
        let mut starts: Vec<usize> = (0..total_frames).step_by(stride).collect();
        let last_start = total_frames - MODEL_CHUNK_FRAMES;
        if starts.last().copied().unwrap_or(0) != last_start {
            starts.push(last_start);
        }
        starts.sort_unstable();
        starts.dedup();
        starts
    };
    let mut accumulated = vec![0.0_f32; magnitudes.len()];
    let mut weights = vec![0.0_f32; total_frames];
    for (chunk_index, start) in starts.iter().copied().enumerate() {
        if should_cancel() {
            return Err(SeparationError::cancelled("run_song_model"));
        }
        let actual_frames = (total_frames - start).min(MODEL_CHUNK_FRAMES);
        let model_frames = actual_frames.max(MODEL_MINIMUM_FRAMES);
        let mut input = vec![0.0_f32; 2 * stft::BIN_COUNT * model_frames];
        for channel in 0..2 {
            for bin in 0..stft::BIN_COUNT {
                let source_base = (channel * stft::BIN_COUNT + bin) * total_frames + start;
                let target_base = (channel * stft::BIN_COUNT + bin) * model_frames;
                input[target_base..target_base + actual_frames]
                    .copy_from_slice(&magnitudes[source_base..source_base + actual_frames]);
            }
        }
        let output = model.infer(&input, model_frames)?;
        if output.len() != input.len() || output.iter().any(|value| !value.is_finite()) {
            return Err(SeparationError::new(
                SeparationFailureReason::ContractMismatch,
                "run_song_model",
                "model output differs from the finite [1,2,2049,frames] contract",
            ));
        }
        for frame in 0..actual_frames {
            let global_frame = start + frame;
            let fade_in = if chunk_index > 0 {
                (frame + 1) as f32 / (MODEL_OVERLAP_FRAMES + 1) as f32
            } else {
                1.0
            };
            let fade_out = if chunk_index + 1 < starts.len() {
                (actual_frames - frame) as f32 / (MODEL_OVERLAP_FRAMES + 1) as f32
            } else {
                1.0
            };
            let weight = fade_in.min(1.0).min(fade_out.min(1.0));
            weights[global_frame] += weight;
            for channel in 0..2 {
                for bin in 0..stft::BIN_COUNT {
                    let global = (channel * stft::BIN_COUNT + bin) * total_frames + global_frame;
                    let local = (channel * stft::BIN_COUNT + bin) * model_frames + frame;
                    accumulated[global] += output[local] * weight;
                }
            }
        }
        on_progress(SeparationProgress::fraction(
            SeparationStage::Inference,
            chunk_index + 1,
            starts.len(),
        ));
    }
    for channel in 0..2 {
        for bin in 0..stft::BIN_COUNT {
            for (frame, weight) in weights.iter().copied().enumerate() {
                if weight <= 0.0 {
                    return Err(SeparationError::new(
                        SeparationFailureReason::ContractMismatch,
                        "crossfade_model_chunks",
                        "model chunks left an uncovered spectrogram frame",
                    ));
                }
                let index = (channel * stft::BIN_COUNT + bin) * total_frames + frame;
                accumulated[index] /= weight;
            }
        }
    }
    Ok((accumulated, starts.len()))
}

#[cfg(test)]
mod tests {
    use super::*;

    struct IdentityModel;

    impl MagnitudeModel for IdentityModel {
        fn model_id(&self) -> &str {
            "identity-test-only"
        }

        fn infer(&mut self, input: &[f32], _frames: usize) -> Result<Vec<f32>, SeparationError> {
            Ok(input.to_vec())
        }
    }

    struct InvalidModel;

    impl MagnitudeModel for InvalidModel {
        fn model_id(&self) -> &str {
            "invalid-test-only"
        }

        fn infer(&mut self, input: &[f32], _frames: usize) -> Result<Vec<f32>, SeparationError> {
            Ok(vec![f32::NAN; input.len()])
        }
    }

    fn fixture(frames: usize) -> StereoWaveform {
        StereoWaveform::new(
            44_100,
            (0..frames)
                .flat_map(|index| {
                    let left =
                        0.2 * (std::f32::consts::TAU * 220.0 * index as f32 / 44_100.0).sin();
                    let right =
                        0.15 * (std::f32::consts::TAU * 330.0 * index as f32 / 44_100.0).sin();
                    [left, right]
                })
                .collect(),
        )
        .expect("valid fixture")
    }

    #[test]
    fn identity_model_reconstructs_vocals_and_exact_residual() {
        let input = fixture(44_100);
        let result = separate_waveform(&input, &mut IdentityModel, || false, |_| {})
            .expect("identity separation should complete");
        assert_eq!(result.vocals.frame_count(), input.frame_count());
        assert_eq!(result.accompaniment.frame_count(), input.frame_count());
        let vocal_error = result
            .vocals
            .samples
            .iter()
            .zip(&input.samples)
            .map(|(actual, expected)| (actual - expected).abs())
            .fold(0.0_f32, f32::max);
        let residual_peak = result
            .accompaniment
            .samples
            .iter()
            .copied()
            .map(f32::abs)
            .fold(0.0_f32, f32::max);
        assert!(vocal_error < 1.0e-5, "vocal max abs {vocal_error}");
        assert!(residual_peak < 1.0e-5, "residual peak {residual_peak}");
    }

    #[test]
    fn long_input_crosses_model_chunk_boundaries_without_seams() {
        let input = fixture(400 * stft::HOP_SIZE);
        let result = separate_waveform(&input, &mut IdentityModel, || false, |_| {})
            .expect("chunked identity separation should complete");
        assert!(result.chunk_count >= 2);
        let max_abs = result
            .vocals
            .samples
            .iter()
            .zip(&input.samples)
            .map(|(actual, expected)| (actual - expected).abs())
            .fold(0.0_f32, f32::max);
        assert!(max_abs < 2.0e-5, "chunk boundary max abs {max_abs}");
    }

    #[test]
    fn cancellation_and_non_finite_model_output_are_typed() {
        let input = fixture(44_100);
        let cancelled = separate_waveform(&input, &mut IdentityModel, || true, |_| {})
            .expect_err("cancelled work must not produce stems");
        assert_eq!(cancelled.reason, SeparationFailureReason::Cancelled);

        let invalid = separate_waveform(&input, &mut InvalidModel, || false, |_| {})
            .expect_err("non-finite model output must fail");
        assert_eq!(invalid.reason, SeparationFailureReason::ContractMismatch);
    }
}
