use crate::frb_generated::StreamSink;

#[derive(Clone, Debug)]
pub struct ReferenceAnalysisRequestDto {
    pub vocals_path: String,
    pub maximum_decoded_frames: u64,
    pub cancel_marker: String,
}

#[derive(Clone, Debug)]
pub struct ReferenceFeatureFrameDto {
    pub sample_index: u64,
    pub pitch_cents: Option<f64>,
    pub rms_dbfs: f64,
    pub periodicity: f64,
    pub voiced: bool,
    pub clipping: bool,
}

#[derive(Clone, Debug)]
pub struct ReferenceAnalysisReportDto {
    pub sample_rate: u32,
    pub frame_rate_hz: u32,
    pub algorithm_version: String,
    pub frames: Vec<ReferenceFeatureFrameDto>,
}

#[derive(Clone, Debug)]
pub struct ReferenceAnalysisFailureDto {
    pub reason: String,
    pub detail: String,
}

#[derive(Clone, Debug)]
pub struct ReferenceAnalysisEventDto {
    pub kind: String,
    pub progress: Option<f64>,
    pub report: Option<ReferenceAnalysisReportDto>,
    pub failure: Option<ReferenceAnalysisFailureDto>,
}

/// Analyzes a local separated-vocals WAV on a native worker. Web has no
/// reviewed separator/reference file pipeline and returns typed unavailable.
#[flutter_rust_bridge::frb(sync)]
pub fn start_reference_analysis(
    request: ReferenceAnalysisRequestDto,
    sink: StreamSink<ReferenceAnalysisEventDto>,
) {
    spawn_platform_analysis(request, sink);
}

#[cfg(not(target_family = "wasm"))]
fn spawn_platform_analysis(
    request: ReferenceAnalysisRequestDto,
    sink: StreamSink<ReferenceAnalysisEventDto>,
) {
    std::thread::spawn(move || run_native_analysis(request, sink));
}

#[cfg(target_family = "wasm")]
fn spawn_platform_analysis(
    _request: ReferenceAnalysisRequestDto,
    sink: StreamSink<ReferenceAnalysisEventDto>,
) {
    let _ = sink.add(ReferenceAnalysisEventDto {
        kind: "failed".to_owned(),
        progress: None,
        report: None,
        failure: Some(ReferenceAnalysisFailureDto {
            reason: "runtime_unavailable".to_owned(),
            detail: "reference file analysis is unavailable in this Web build".to_owned(),
        }),
    });
}

#[cfg(not(target_family = "wasm"))]
fn run_native_analysis(
    request: ReferenceAnalysisRequestDto,
    sink: StreamSink<ReferenceAnalysisEventDto>,
) {
    let cancel_marker = std::path::Path::new(&request.cancel_marker);
    let result = analyze_reference_file(
        std::path::Path::new(&request.vocals_path),
        request.maximum_decoded_frames,
        || cancel_marker.exists(),
        |progress| {
            let _ = sink.add(ReferenceAnalysisEventDto {
                kind: "progress".to_owned(),
                progress: Some(progress),
                report: None,
                failure: None,
            });
        },
    );
    let event = match result {
        Ok(report) => ReferenceAnalysisEventDto {
            kind: "completed".to_owned(),
            progress: Some(1.0),
            report: Some(report),
            failure: None,
        },
        Err((reason, detail)) => ReferenceAnalysisEventDto {
            kind: "failed".to_owned(),
            progress: None,
            report: None,
            failure: Some(ReferenceAnalysisFailureDto { reason, detail }),
        },
    };
    let _ = sink.add(event);
}

#[cfg(not(target_family = "wasm"))]
fn analyze_reference_file<C, P>(
    path: &std::path::Path,
    maximum_decoded_frames: u64,
    mut should_cancel: C,
    mut on_progress: P,
) -> Result<ReferenceAnalysisReportDto, (String, String)>
where
    C: FnMut() -> bool,
    P: FnMut(f64),
{
    use crate::pitch::{PitchConfig, PitchEstimator, YinEstimator};
    use crate::song::decode_audio_file;

    let decoded = decode_audio_file(path, maximum_decoded_frames, &mut should_cancel)
        .map_err(|error| (failure_reason(error.reason).to_owned(), error.detail))?;
    on_progress(0.15);
    if should_cancel() {
        return Err((
            "cancelled".to_owned(),
            "reference analysis was cancelled".to_owned(),
        ));
    }

    // Separator output is 44.1 kHz stereo. The three-sample box average is
    // intentionally the documented SRD-03 14.7 kHz reference-F0 path, kept
    // separate from the 48 kHz realtime production pitch algorithm.
    if decoded.waveform.sample_rate != 44_100 {
        return Err((
            "unsupported_format".to_owned(),
            "separated vocals must be 44.1 kHz".to_owned(),
        ));
    }
    let mono: Vec<f32> = decoded
        .waveform
        .samples
        .chunks_exact(2)
        .map(|frame| (frame[0] + frame[1]) * 0.5)
        .collect();
    let downsampled: Vec<f32> = mono
        .chunks_exact(3)
        .map(|samples| (samples[0] + samples[1] + samples[2]) / 3.0)
        .collect();
    if downsampled.len() < 1_024 {
        return Err((
            "insufficient_audio".to_owned(),
            "reference phrase is shorter than the analysis window".to_owned(),
        ));
    }

    const WINDOW: usize = 1_024;
    const HOP: usize = 147;
    const DOWNSAMPLED_RATE: u32 = 14_700;
    let config = PitchConfig {
        sample_rate_hz: DOWNSAMPLED_RATE,
        min_frequency_hz: 60.0,
        max_frequency_hz: 1_000.0,
    };
    let estimator = YinEstimator;
    let total = 1 + (downsampled.len() - WINDOW) / HOP;
    let mut frames = Vec::with_capacity(total);
    for (index, start) in (0..=downsampled.len() - WINDOW).step_by(HOP).enumerate() {
        if index.is_multiple_of(64) {
            if should_cancel() {
                return Err((
                    "cancelled".to_owned(),
                    "reference analysis was cancelled".to_owned(),
                ));
            }
            on_progress(0.15 + 0.84 * index as f64 / total.max(1) as f64);
        }
        let window = &downsampled[start..start + WINDOW];
        let mean_square = window.iter().map(|sample| sample * sample).sum::<f32>() / WINDOW as f32;
        let rms_dbfs = 20.0 * mean_square.sqrt().max(1.0e-6).log10();
        let clipping = raw_stereo_window_clips(&decoded.waveform.samples, start, WINDOW);
        let estimate = estimator.estimate(window, config);
        let periodicity = estimate.map_or(0.0, |value| value.clarity);
        let voiced = rms_dbfs >= -55.0 && periodicity >= 0.60;
        let pitch_cents = (voiced && estimate.is_some()).then(|| {
            let frequency = estimate.expect("checked above").frequency_hz as f64;
            6900.0 + 1200.0 * (frequency / 440.0).log2()
        });
        frames.push(ReferenceFeatureFrameDto {
            sample_index: (start * 3) as u64,
            pitch_cents,
            rms_dbfs: rms_dbfs as f64,
            periodicity: periodicity as f64,
            voiced,
            clipping,
        });
    }
    Ok(ReferenceAnalysisReportDto {
        sample_rate: 44_100,
        frame_rate_hz: 100,
        algorithm_version: "reference-yin-14k7-v1".to_owned(),
        frames,
    })
}

#[cfg(not(target_family = "wasm"))]
fn raw_stereo_window_clips(
    interleaved_stereo: &[f32],
    downsampled_start: usize,
    downsampled_window: usize,
) -> bool {
    const ORIGINAL_FRAMES_PER_DOWNSAMPLED_SAMPLE: usize = 3;
    const CHANNELS: usize = 2;
    let start = downsampled_start
        .saturating_mul(ORIGINAL_FRAMES_PER_DOWNSAMPLED_SAMPLE)
        .saturating_mul(CHANNELS);
    let end = downsampled_start
        .saturating_add(downsampled_window)
        .saturating_mul(ORIGINAL_FRAMES_PER_DOWNSAMPLED_SAMPLE)
        .saturating_mul(CHANNELS)
        .min(interleaved_stereo.len());
    interleaved_stereo.get(start..end).is_some_and(|samples| {
        if samples.is_empty() {
            return false;
        }
        let clipped = samples
            .iter()
            .filter(|sample| sample.abs() >= 0.999)
            .count();
        clipped.saturating_mul(1_000) >= samples.len()
    })
}

#[cfg(not(target_family = "wasm"))]
fn failure_reason(reason: crate::song::SeparationFailureReason) -> &'static str {
    use crate::song::SeparationFailureReason;
    match reason {
        SeparationFailureReason::InputNotFound => "input_not_found",
        SeparationFailureReason::UnsupportedFormat | SeparationFailureReason::FormatChanged => {
            "unsupported_format"
        }
        SeparationFailureReason::DecodeFailed => "decode_failed",
        SeparationFailureReason::ResourceLimitExceeded => "resource_limit_exceeded",
        SeparationFailureReason::Cancelled => "cancelled",
        SeparationFailureReason::IoFailure => "io_failure",
        _ => "processing_failed",
    }
}

#[cfg(all(test, not(target_family = "wasm")))]
mod tests {
    use super::raw_stereo_window_clips;
    use crate::song::StereoWaveform;

    #[test]
    fn reference_feature_math_reports_pitch_level_and_periodicity() {
        use crate::pitch::{PitchConfig, PitchEstimator, YinEstimator};
        let samples: Vec<f32> = (0..1_024)
            .map(|index| (std::f32::consts::TAU * 220.0 * index as f32 / 14_700.0).sin() * 0.25)
            .collect();
        let estimate = YinEstimator
            .estimate(
                &samples,
                PitchConfig {
                    sample_rate_hz: 14_700,
                    min_frequency_hz: 60.0,
                    max_frequency_hz: 1_000.0,
                },
            )
            .expect("tone should be voiced");
        assert!((estimate.frequency_hz - 220.0).abs() < 0.2);
        assert!(estimate.clarity > 0.95);
        let waveform = StereoWaveform::new(44_100, vec![0.0, 0.0]).expect("valid");
        assert_eq!(waveform.frame_count(), 1);
    }

    #[test]
    fn clipping_is_detected_before_channel_and_downsampling_averages() {
        let mut stereo = vec![0.0; 1_024 * 3 * 2];
        for frame in stereo.chunks_exact_mut(2).take(8) {
            frame[0] = 1.0;
            frame[1] = -1.0;
        }
        assert!(raw_stereo_window_clips(&stereo, 0, 1_024));

        stereo.fill(0.0);
        for sample in stereo.iter_mut().take(7) {
            *sample = -1.0;
        }
        assert!(raw_stereo_window_clips(&stereo, 0, 1_024));
        stereo.fill(0.0);
        stereo[317] = -1.0;
        assert!(!raw_stereo_window_clips(&stereo, 0, 1_024));
        assert!(!raw_stereo_window_clips(&stereo, 1_024, 1_024));
    }
}
