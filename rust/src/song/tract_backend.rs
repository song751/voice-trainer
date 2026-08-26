use super::pipeline::{MagnitudeModel, SeparationError, SeparationFailureReason};
use sha2::{Digest, Sha256};
use std::fs::File;
use std::io::{BufReader, Read};
use std::path::Path;
use std::sync::Arc;
use tract_onnx::prelude::*;

pub const EXPECTED_UMXHQ_ONNX_SHA256: &str =
    "1dd15a2be2f15ba035205f866a035df38d85b27824ad67fe53566e80ec1f4258";

type RunnableModel = Arc<TypedRunnableModel>;

pub struct TractUmxHqModel {
    model: RunnableModel,
    model_id: String,
}

impl TractUmxHqModel {
    pub fn load(path: &Path, expected_sha256: &str) -> Result<Self, SeparationError> {
        if !path.is_file() {
            return Err(SeparationError::new(
                SeparationFailureReason::ModelNotFound,
                "load_song_model",
                "the UMX-HQ ONNX model is not installed",
            ));
        }
        let actual_hash = hash_file(path)?;
        if !actual_hash.eq_ignore_ascii_case(expected_sha256)
            || !actual_hash.eq_ignore_ascii_case(EXPECTED_UMXHQ_ONNX_SHA256)
        {
            return Err(SeparationError::new(
                SeparationFailureReason::ModelHashMismatch,
                "load_song_model",
                "the installed model does not match the reviewed UMX-HQ ONNX hash",
            ));
        }
        let model = tract_onnx::onnx()
            .model_for_path(path)
            .and_then(|model| model.into_optimized())
            .and_then(|model| model.into_runnable())
            .map_err(|_| {
                SeparationError::new(
                    SeparationFailureReason::BackendIncompatible,
                    "load_song_model",
                    "tract could not load or compile the reviewed UMX-HQ ONNX graph",
                )
            })?;
        Ok(Self {
            model,
            model_id: format!("umxhq-vocals-onnx-{actual_hash}"),
        })
    }
}

impl MagnitudeModel for TractUmxHqModel {
    fn model_id(&self) -> &str {
        &self.model_id
    }

    fn infer(&mut self, input: &[f32], frames: usize) -> Result<Vec<f32>, SeparationError> {
        let expected = 2 * 2049 * frames;
        if input.len() != expected {
            return Err(SeparationError::new(
                SeparationFailureReason::ContractMismatch,
                "run_song_model",
                "input differs from the [1,2,2049,frames] UMX-HQ contract",
            ));
        }
        let tensor = Tensor::from_shape(&[1, 2, 2049, frames], input).map_err(|_| {
            SeparationError::new(
                SeparationFailureReason::ContractMismatch,
                "run_song_model",
                "input could not form the UMX-HQ tensor",
            )
        })?;
        let outputs = self.model.run(tvec!(tensor.into())).map_err(|_| {
            SeparationError::new(
                SeparationFailureReason::BackendIncompatible,
                "run_song_model",
                "tract failed while executing UMX-HQ",
            )
        })?;
        let output = outputs
            .first()
            .ok_or_else(|| {
                SeparationError::new(
                    SeparationFailureReason::ContractMismatch,
                    "run_song_model",
                    "tract returned no UMX-HQ output",
                )
            })?
            .to_plain_array_view::<f32>()
            .map_err(|_| {
                SeparationError::new(
                    SeparationFailureReason::ContractMismatch,
                    "run_song_model",
                    "tract UMX-HQ output is not f32",
                )
            })?;
        if output.shape() != [1, 2, 2049, frames] {
            return Err(SeparationError::new(
                SeparationFailureReason::ContractMismatch,
                "run_song_model",
                "tract UMX-HQ output shape changed",
            ));
        }
        Ok(output.iter().copied().collect())
    }
}

fn hash_file(path: &Path) -> Result<String, SeparationError> {
    let mut reader = BufReader::new(File::open(path).map_err(|error| {
        SeparationError::io(
            "hash_song_model",
            "the UMX-HQ ONNX model could not be opened",
            error,
        )
    })?);
    let mut hasher = Sha256::new();
    let mut buffer = [0_u8; 64 * 1024];
    loop {
        let count = reader.read(&mut buffer).map_err(|error| {
            SeparationError::io(
                "hash_song_model",
                "the UMX-HQ ONNX model could not be read",
                error,
            )
        })?;
        if count == 0 {
            break;
        }
        hasher.update(&buffer[..count]);
    }
    Ok(format!("{:x}", hasher.finalize()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_model_is_a_typed_failure() {
        let failure = TractUmxHqModel::load(
            Path::new("definitely-missing-umxhq.onnx"),
            EXPECTED_UMXHQ_ONNX_SHA256,
        )
        .err()
        .expect("missing model must fail");
        assert_eq!(failure.reason, SeparationFailureReason::ModelNotFound);
    }
}
