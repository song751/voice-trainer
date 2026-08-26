use crate::frb_generated::StreamSink;

#[derive(Clone, Debug)]
pub struct SongSeparationRequestDto {
    pub rights_acknowledged: bool,
    pub input_path: String,
    pub model_path: String,
    pub expected_model_sha256: String,
    pub output_directory: String,
    pub job_id: String,
    pub cancel_marker: String,
    pub maximum_decoded_frames: u64,
}

#[derive(Clone, Debug)]
pub struct SongRuntimeStatusDto {
    pub available: bool,
    pub reason: Option<String>,
    pub model_id: Option<String>,
}

#[derive(Clone, Debug)]
pub struct SongStemMetadataDto {
    pub path: String,
    pub sha256: String,
    pub byte_length: u64,
}

#[derive(Clone, Debug)]
pub struct SongSeparationReportDto {
    pub model_id: String,
    pub algorithm_version: String,
    pub source_sample_rate: u32,
    pub source_channels: u16,
    pub output_sample_rate: u32,
    pub output_channels: u16,
    pub output_frames: u64,
    pub chunk_count: u32,
    pub vocals: SongStemMetadataDto,
    pub accompaniment: SongStemMetadataDto,
}

#[derive(Clone, Debug)]
pub struct SongSeparationFailureDto {
    pub reason: String,
    pub operation: String,
    pub detail: String,
}

#[derive(Clone, Debug)]
pub struct SongSeparationProgressDto {
    pub stage: String,
    pub completed_units: u64,
    pub total_units: u64,
}

#[derive(Clone, Debug)]
pub struct SongSeparationEventDto {
    pub kind: String,
    pub progress: Option<SongSeparationProgressDto>,
    pub report: Option<SongSeparationReportDto>,
    pub failure: Option<SongSeparationFailureDto>,
}

/// Checks the reviewed hash and compiles the native model graph. It performs
/// no download and returns unavailable on Web, where no reviewed runtime has
/// passed the SRD-04 gate.
#[flutter_rust_bridge::frb(sync)]
pub fn probe_song_separation_runtime(
    model_path: String,
    expected_model_sha256: String,
    sink: StreamSink<SongRuntimeStatusDto>,
) {
    start_platform_probe(model_path, expected_model_sha256, sink);
}

/// Runs the file-backed offline job on FRB's native worker and emits bounded
/// progress plus exactly one terminal completed/failed event.
#[flutter_rust_bridge::frb(sync)]
pub fn start_song_separation(
    request: SongSeparationRequestDto,
    sink: StreamSink<SongSeparationEventDto>,
) {
    spawn_platform_separation(request, sink);
}

#[cfg(not(target_family = "wasm"))]
fn start_platform_probe(
    model_path: String,
    expected_model_sha256: String,
    sink: StreamSink<SongRuntimeStatusDto>,
) {
    std::thread::spawn(move || {
        let _ = sink.add(probe_runtime_platform(model_path, expected_model_sha256));
    });
}

#[cfg(target_family = "wasm")]
fn start_platform_probe(
    model_path: String,
    expected_model_sha256: String,
    sink: StreamSink<SongRuntimeStatusDto>,
) {
    let _ = sink.add(probe_runtime_platform(model_path, expected_model_sha256));
}

#[cfg(not(target_family = "wasm"))]
fn spawn_platform_separation(
    request: SongSeparationRequestDto,
    sink: StreamSink<SongSeparationEventDto>,
) {
    std::thread::spawn(move || start_platform_separation(request, sink));
}

#[cfg(target_family = "wasm")]
fn spawn_platform_separation(
    request: SongSeparationRequestDto,
    sink: StreamSink<SongSeparationEventDto>,
) {
    start_platform_separation(request, sink);
}

#[cfg(not(target_family = "wasm"))]
fn probe_runtime_platform(
    model_path: String,
    expected_model_sha256: String,
) -> SongRuntimeStatusDto {
    use crate::song::{MagnitudeModel, TractUmxHqModel};
    match TractUmxHqModel::load(std::path::Path::new(&model_path), &expected_model_sha256) {
        Ok(model) => SongRuntimeStatusDto {
            available: true,
            reason: None,
            model_id: Some(model.model_id().to_owned()),
        },
        Err(error) => SongRuntimeStatusDto {
            available: false,
            reason: Some(failure_reason_name(error.reason).to_owned()),
            model_id: None,
        },
    }
}

#[cfg(target_family = "wasm")]
fn probe_runtime_platform(
    _model_path: String,
    _expected_model_sha256: String,
) -> SongRuntimeStatusDto {
    SongRuntimeStatusDto {
        available: false,
        reason: Some("runtime_unavailable".to_owned()),
        model_id: None,
    }
}

#[cfg(not(target_family = "wasm"))]
fn start_platform_separation(
    request: SongSeparationRequestDto,
    sink: StreamSink<SongSeparationEventDto>,
) {
    use crate::song::{separate_song_file, FileSeparationRequest};
    let native = FileSeparationRequest {
        rights_acknowledged: request.rights_acknowledged,
        input_path: request.input_path.into(),
        model_path: request.model_path.into(),
        expected_model_sha256: request.expected_model_sha256,
        output_directory: request.output_directory.into(),
        job_id: request.job_id,
        cancel_marker: request.cancel_marker.into(),
        maximum_decoded_frames: request.maximum_decoded_frames,
    };
    let result = separate_song_file(&native, |progress| {
        let _ = sink.add(SongSeparationEventDto {
            kind: "progress".to_owned(),
            progress: Some(SongSeparationProgressDto {
                stage: stage_name(progress.stage).to_owned(),
                completed_units: progress.completed_units,
                total_units: progress.total_units,
            }),
            report: None,
            failure: None,
        });
    });
    let event = match result {
        Ok(report) => SongSeparationEventDto {
            kind: "completed".to_owned(),
            progress: None,
            report: Some(SongSeparationReportDto {
                model_id: report.model_id,
                algorithm_version: report.algorithm_version,
                source_sample_rate: report.source_sample_rate,
                source_channels: report.source_channels,
                output_sample_rate: report.output_sample_rate,
                output_channels: report.output_channels,
                output_frames: report.output_frames,
                chunk_count: report.chunk_count,
                vocals: SongStemMetadataDto {
                    path: report.vocals.path.to_string_lossy().into_owned(),
                    sha256: report.vocals.sha256,
                    byte_length: report.vocals.byte_length,
                },
                accompaniment: SongStemMetadataDto {
                    path: report.accompaniment.path.to_string_lossy().into_owned(),
                    sha256: report.accompaniment.sha256,
                    byte_length: report.accompaniment.byte_length,
                },
            }),
            failure: None,
        },
        Err(error) => SongSeparationEventDto {
            kind: "failed".to_owned(),
            progress: None,
            report: None,
            failure: Some(SongSeparationFailureDto {
                reason: failure_reason_name(error.reason).to_owned(),
                operation: error.operation.to_owned(),
                detail: error.detail,
            }),
        },
    };
    let _ = sink.add(event);
}

#[cfg(target_family = "wasm")]
fn start_platform_separation(
    _request: SongSeparationRequestDto,
    sink: StreamSink<SongSeparationEventDto>,
) {
    let _ = sink.add(SongSeparationEventDto {
        kind: "failed".to_owned(),
        progress: None,
        report: None,
        failure: Some(SongSeparationFailureDto {
            reason: "runtime_unavailable".to_owned(),
            operation: "start_song_separation".to_owned(),
            detail: "this Web build has no reviewed song-separation model runtime".to_owned(),
        }),
    });
}

#[cfg(not(target_family = "wasm"))]
fn failure_reason_name(reason: crate::song::SeparationFailureReason) -> &'static str {
    use crate::song::SeparationFailureReason;
    match reason {
        SeparationFailureReason::RightsAcknowledgementRequired => "rights_acknowledgement_required",
        SeparationFailureReason::InputNotFound => "input_not_found",
        SeparationFailureReason::UnsupportedFormat => "unsupported_format",
        SeparationFailureReason::FormatChanged => "format_changed",
        SeparationFailureReason::DecodeFailed => "decode_failed",
        SeparationFailureReason::ModelNotFound => "model_not_found",
        SeparationFailureReason::ModelHashMismatch => "model_hash_mismatch",
        SeparationFailureReason::RuntimeUnavailable => "runtime_unavailable",
        SeparationFailureReason::BackendIncompatible => "backend_incompatible",
        SeparationFailureReason::ContractMismatch => "contract_mismatch",
        SeparationFailureReason::NumericalFailure => "numerical_failure",
        SeparationFailureReason::ResourceLimitExceeded => "resource_limit_exceeded",
        SeparationFailureReason::Cancelled => "cancelled",
        SeparationFailureReason::IoFailure => "io_failure",
    }
}

#[cfg(not(target_family = "wasm"))]
fn stage_name(stage: crate::song::SeparationStage) -> &'static str {
    use crate::song::SeparationStage;
    match stage {
        SeparationStage::Decoding => "decoding",
        SeparationStage::Resampling => "resampling",
        SeparationStage::Transforming => "transforming",
        SeparationStage::Inference => "inference",
        SeparationStage::Reconstructing => "reconstructing",
        SeparationStage::Writing => "writing",
        SeparationStage::Completed => "completed",
    }
}
