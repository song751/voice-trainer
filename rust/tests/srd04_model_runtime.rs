#![cfg(not(target_family = "wasm"))]

use rust_lib_voice_trainer::song::{MagnitudeModel, TractUmxHqModel};
use std::fs;
use std::path::PathBuf;

#[test]
#[ignore = "requires Git-outside reviewed ONNX and SRD-02 raw golden paths"]
fn reviewed_onnx_matches_srd02_runtime_golden() {
    let model_path = required_environment_path("VOICE_TRAINER_UMXHQ_ONNX");
    let input_path = required_environment_path("VOICE_TRAINER_UMXHQ_INPUT_47");
    let expected_path = required_environment_path("VOICE_TRAINER_UMXHQ_EXPECTED_47");
    let input = read_f32(&input_path);
    let expected = read_f32(&expected_path);
    let mut model = TractUmxHqModel::load(
        &model_path,
        "1dd15a2be2f15ba035205f866a035df38d85b27824ad67fe53566e80ec1f4258",
    )
    .expect("reviewed ONNX should load");
    let actual = model.infer(&input, 47).expect("tract inference should run");
    assert_eq!(actual.len(), expected.len());
    let max_abs = actual
        .iter()
        .zip(expected)
        .map(|(actual, expected)| (actual - expected).abs())
        .fold(0.0_f32, f32::max);
    assert!(max_abs < 2.0e-5, "model max abs {max_abs}");
}

fn required_environment_path(name: &str) -> PathBuf {
    std::env::var_os(name)
        .map(PathBuf::from)
        .unwrap_or_else(|| panic!("{name} is required for this ignored integration test"))
}

fn read_f32(path: &PathBuf) -> Vec<f32> {
    fs::read(path)
        .expect("read raw f32 golden")
        .chunks_exact(4)
        .map(|chunk| f32::from_le_bytes(chunk.try_into().expect("four bytes")))
        .collect()
}
