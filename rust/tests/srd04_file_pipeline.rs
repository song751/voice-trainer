#![cfg(not(target_family = "wasm"))]

use rust_lib_voice_trainer::song::{separate_song_file, FileSeparationRequest};
use std::path::PathBuf;

#[test]
#[ignore = "requires Git-outside reviewed ONNX, licensed audio, and output directory"]
fn reviewed_model_separates_a_licensed_local_file() {
    let output_root = required_environment_path("VOICE_TRAINER_SRD04_OUTPUT")
        .join(format!("file-smoke-{}", std::process::id()));
    let request = FileSeparationRequest {
        rights_acknowledged: true,
        input_path: required_environment_path("VOICE_TRAINER_SRD04_INPUT"),
        model_path: required_environment_path("VOICE_TRAINER_UMXHQ_ONNX"),
        expected_model_sha256: "1dd15a2be2f15ba035205f866a035df38d85b27824ad67fe53566e80ec1f4258"
            .to_owned(),
        output_directory: output_root.clone(),
        job_id: "licensed-smoke".to_owned(),
        cancel_marker: output_root.join("cancel.marker"),
        maximum_decoded_frames: 44_100 * 60 * 5,
    };
    let report = separate_song_file(&request, |_| {}).expect("file separation should complete");
    assert_eq!(report.output_sample_rate, 44_100);
    assert_eq!(report.output_channels, 2);
    assert!(report.output_frames > 0);
    assert_eq!(report.vocals.sha256.len(), 64);
    assert_eq!(report.accompaniment.sha256.len(), 64);
    println!(
        "frames={} chunks={} vocals_sha256={} accompaniment_sha256={} output={}",
        report.output_frames,
        report.chunk_count,
        report.vocals.sha256,
        report.accompaniment.sha256,
        output_root.display()
    );
}

fn required_environment_path(name: &str) -> PathBuf {
    std::env::var_os(name)
        .map(PathBuf::from)
        .unwrap_or_else(|| panic!("{name} is required for this ignored integration test"))
}
