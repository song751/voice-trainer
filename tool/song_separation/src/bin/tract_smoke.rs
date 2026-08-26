use serde::Serialize;
use sha2::{Digest, Sha256};
use std::fs::File;
use std::io::{BufReader, Read};
use std::path::{Path, PathBuf};
use std::time::Instant;
use tract_onnx::prelude::*;

#[derive(Clone, Copy, Debug, Serialize)]
#[serde(rename_all = "snake_case")]
enum FailureReason {
    RightsAcknowledgementRequired,
    InputNotFound,
    ContractMismatch,
    Cancelled,
    BackendIncompatible,
    NumericalMismatch,
    IoFailure,
}

#[derive(Debug, Serialize)]
struct Failure {
    kind: &'static str,
    reason: FailureReason,
    operation: &'static str,
    detail: &'static str,
}

#[derive(Debug)]
struct Arguments {
    acknowledge_rights: bool,
    onnx: PathBuf,
    input_raw: PathBuf,
    expected_raw: PathBuf,
    frames: usize,
    cancel_file: Option<PathBuf>,
    max_abs_tolerance: f64,
}

fn main() {
    match parse_arguments().and_then(run) {
        Ok(()) => {}
        Err(failure) => {
            println!(
                "{}",
                serde_json::to_string(&failure).expect("failure is serializable")
            );
            std::process::exit(2);
        }
    }
}

fn run(arguments: Arguments) -> Result<(), Failure> {
    if !arguments.acknowledge_rights {
        return Err(failure(
            FailureReason::RightsAcknowledgementRequired,
            "validate_rights",
            "explicit rights acknowledgement is required",
        ));
    }
    for path in [
        &arguments.onnx,
        &arguments.input_raw,
        &arguments.expected_raw,
    ] {
        if !path.is_file() {
            return Err(failure(
                FailureReason::InputNotFound,
                "validate_input",
                "one required input file is missing",
            ));
        }
    }
    check_cancelled(arguments.cancel_file.as_deref())?;
    progress("loading_model", 0, 4);
    let onnx_sha256 = hash_file(&arguments.onnx)?;
    let expected_values = 2_usize
        .checked_mul(2049)
        .and_then(|value| value.checked_mul(arguments.frames))
        .ok_or_else(|| {
            failure(
                FailureReason::ContractMismatch,
                "validate_shape",
                "requested tensor shape overflows",
            )
        })?;
    let input = read_f32(&arguments.input_raw, expected_values)?;
    let expected = read_f32(&arguments.expected_raw, expected_values)?;
    check_cancelled(arguments.cancel_file.as_deref())?;

    let load_started = Instant::now();
    let model = tract_onnx::onnx()
        .model_for_path(&arguments.onnx)
        .and_then(|model| {
            model.with_input_fact(0, f32::fact([1, 2, 2049, arguments.frames]).into())
        })
        .and_then(|model| model.into_optimized())
        .and_then(|model| model.into_runnable())
        .map_err(|_| {
            failure(
                FailureReason::BackendIncompatible,
                "prepare_model",
                "tract could not load, type, optimize, or compile this ONNX graph",
            )
        })?;
    let load_seconds = load_started.elapsed().as_secs_f64();
    progress("running_inference", 1, 4);
    check_cancelled(arguments.cancel_file.as_deref())?;
    let tensor = Tensor::from_shape(&[1, 2, 2049, arguments.frames], &input).map_err(|_| {
        failure(
            FailureReason::ContractMismatch,
            "create_tensor",
            "raw input cannot form the requested tensor",
        )
    })?;
    let inference_started = Instant::now();
    let outputs = model.run(tvec!(tensor.into())).map_err(|_| {
        failure(
            FailureReason::BackendIncompatible,
            "run_model",
            "tract failed while executing this ONNX graph",
        )
    })?;
    let inference_seconds = inference_started.elapsed().as_secs_f64();
    progress("comparing", 2, 4);
    check_cancelled(arguments.cancel_file.as_deref())?;
    let actual = outputs[0].to_plain_array_view::<f32>().map_err(|_| {
        failure(
            FailureReason::ContractMismatch,
            "read_output",
            "tract output is not f32",
        )
    })?;
    if actual.shape() != [1, 2, 2049, arguments.frames] {
        return Err(failure(
            FailureReason::ContractMismatch,
            "read_output",
            "tract output shape differs from the UMX-HQ core contract",
        ));
    }
    let mut max_abs = 0.0_f64;
    let mut sum_squared = 0.0_f64;
    let mut output_hasher = Sha256::new();
    for (actual, expected) in actual.iter().zip(&expected) {
        if !actual.is_finite() {
            return Err(failure(
                FailureReason::NumericalMismatch,
                "compare_output",
                "tract output contains a non-finite value",
            ));
        }
        let delta = f64::from(*actual) - f64::from(*expected);
        max_abs = max_abs.max(delta.abs());
        sum_squared += delta * delta;
        output_hasher.update(actual.to_le_bytes());
    }
    if max_abs > arguments.max_abs_tolerance {
        return Err(failure(
            FailureReason::NumericalMismatch,
            "compare_output",
            "tract output exceeds the configured max-absolute tolerance",
        ));
    }
    let rmse = (sum_squared / actual.len() as f64).sqrt();
    progress("completed", 4, 4);
    println!(
        "{}",
        serde_json::json!({
            "kind": "report",
            "status": "completed",
            "backend": "tract_onnx_0.23.5_cpu",
            "frames": arguments.frames,
            "shape": [1, 2, 2049, arguments.frames],
            "onnx_sha256": onnx_sha256,
            "load_seconds": load_seconds,
            "inference_seconds": inference_seconds,
            "max_abs_tolerance": arguments.max_abs_tolerance,
            "max_abs": max_abs,
            "rmse": rmse,
            "output_sha256": format!("{:x}", output_hasher.finalize()),
        })
    );
    Ok(())
}

fn read_f32(path: &Path, expected_values: usize) -> Result<Vec<f32>, Failure> {
    let mut bytes = Vec::new();
    BufReader::new(File::open(path).map_err(|_| {
        failure(
            FailureReason::IoFailure,
            "read_tensor",
            "could not open a raw tensor file",
        )
    })?)
    .read_to_end(&mut bytes)
    .map_err(|_| {
        failure(
            FailureReason::IoFailure,
            "read_tensor",
            "could not read a raw tensor file",
        )
    })?;
    if bytes.len() != expected_values * 4 {
        return Err(failure(
            FailureReason::ContractMismatch,
            "read_tensor",
            "raw tensor byte length differs from the requested shape",
        ));
    }
    Ok(bytes
        .chunks_exact(4)
        .map(|chunk| f32::from_le_bytes(chunk.try_into().expect("four-byte chunk")))
        .collect())
}

fn hash_file(path: &Path) -> Result<String, Failure> {
    let mut reader = BufReader::new(File::open(path).map_err(|_| {
        failure(
            FailureReason::IoFailure,
            "hash_model",
            "could not open the ONNX model",
        )
    })?);
    let mut hasher = Sha256::new();
    let mut buffer = [0_u8; 64 * 1024];
    loop {
        let count = reader.read(&mut buffer).map_err(|_| {
            failure(
                FailureReason::IoFailure,
                "hash_model",
                "could not read the ONNX model",
            )
        })?;
        if count == 0 {
            break;
        }
        hasher.update(&buffer[..count]);
    }
    Ok(format!("{:x}", hasher.finalize()))
}

fn progress(stage: &'static str, completed_units: u64, total_units: u64) {
    println!(
        "{}",
        serde_json::json!({
            "kind": "progress",
            "stage": stage,
            "completed_units": completed_units,
            "total_units": total_units,
        })
    );
}

fn check_cancelled(cancel_file: Option<&Path>) -> Result<(), Failure> {
    if cancel_file.is_some_and(Path::exists) {
        Err(failure(
            FailureReason::Cancelled,
            "run_job",
            "cancel marker detected",
        ))
    } else {
        Ok(())
    }
}

fn failure(reason: FailureReason, operation: &'static str, detail: &'static str) -> Failure {
    Failure {
        kind: "failure",
        reason,
        operation,
        detail,
    }
}

fn parse_arguments() -> Result<Arguments, Failure> {
    let mut values = std::env::args().skip(1);
    let mut acknowledge_rights = false;
    let mut onnx = None;
    let mut input_raw = None;
    let mut expected_raw = None;
    let mut frames = None;
    let mut cancel_file = None;
    let mut max_abs_tolerance = 1e-4_f64;
    while let Some(argument) = values.next() {
        match argument.as_str() {
            "--acknowledge-rights" => acknowledge_rights = true,
            "--onnx" => onnx = values.next().map(PathBuf::from),
            "--input-raw" => input_raw = values.next().map(PathBuf::from),
            "--expected-raw" => expected_raw = values.next().map(PathBuf::from),
            "--frames" => frames = values.next().and_then(|value| value.parse().ok()),
            "--cancel-file" => cancel_file = values.next().map(PathBuf::from),
            "--max-abs-tolerance" => {
                max_abs_tolerance = values
                    .next()
                    .and_then(|value| value.parse().ok())
                    .unwrap_or(f64::NAN);
            }
            _ => {}
        }
    }
    let missing = || {
        failure(
            FailureReason::ContractMismatch,
            "parse_arguments",
            "required argument is missing or invalid",
        )
    };
    if !max_abs_tolerance.is_finite() || max_abs_tolerance < 0.0 {
        return Err(missing());
    }
    Ok(Arguments {
        acknowledge_rights,
        onnx: onnx.ok_or_else(missing)?,
        input_raw: input_raw.ok_or_else(missing)?,
        expected_raw: expected_raw.ok_or_else(missing)?,
        frames: frames.filter(|value| *value > 0).ok_or_else(missing)?,
        cancel_file,
        max_abs_tolerance,
    })
}
