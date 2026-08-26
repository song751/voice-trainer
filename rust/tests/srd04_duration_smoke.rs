#![cfg(not(target_family = "wasm"))]

use rust_lib_voice_trainer::song::{separate_song_file, FileSeparationRequest};
use std::fs::{self, File};
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};
use std::time::Instant;

#[test]
#[ignore = "requires Git-outside reviewed ONNX and an explicit duration"]
fn reviewed_model_reports_duration_smoke() {
    let seconds: u64 = std::env::var("VOICE_TRAINER_SRD04_SECONDS")
        .expect("VOICE_TRAINER_SRD04_SECONDS is required")
        .parse()
        .expect("duration must be an integer number of seconds");
    assert!(matches!(seconds, 30 | 180 | 300));
    let root = required_environment_path("VOICE_TRAINER_SRD04_OUTPUT")
        .join(format!("duration-{seconds}-{}", std::process::id()));
    fs::create_dir_all(&root).expect("create duration smoke directory");
    let input = root.join("deterministic-input.wav");
    write_fixture(&input, seconds);
    let request = FileSeparationRequest {
        rights_acknowledged: true,
        input_path: input,
        model_path: required_environment_path("VOICE_TRAINER_UMXHQ_ONNX"),
        expected_model_sha256: "1dd15a2be2f15ba035205f866a035df38d85b27824ad67fe53566e80ec1f4258"
            .to_owned(),
        output_directory: root.clone(),
        job_id: format!("duration-{seconds}"),
        cancel_marker: root.join("cancel.marker"),
        maximum_decoded_frames: 44_100 * 60 * 5,
    };
    let started = Instant::now();
    let report = separate_song_file(&request, |_| {}).expect("duration smoke should complete");
    let elapsed = started.elapsed().as_secs_f64();
    assert_eq!(report.output_frames, seconds * 44_100);
    println!(
        "seconds={seconds} elapsed_seconds={elapsed:.6} realtime_factor={:.6} chunks={} vocals_sha256={} accompaniment_sha256={}",
        elapsed / seconds as f64,
        report.chunk_count,
        report.vocals.sha256,
        report.accompaniment.sha256,
    );
}

fn write_fixture(path: &Path, seconds: u64) {
    let frames = seconds * 44_100;
    let data_length: u32 = (frames * 4).try_into().expect("fixture fits RIFF");
    let mut writer = BufWriter::new(File::create(path).expect("create fixture"));
    writer.write_all(b"RIFF").unwrap();
    writer.write_all(&(36 + data_length).to_le_bytes()).unwrap();
    writer.write_all(b"WAVEfmt ").unwrap();
    writer.write_all(&16_u32.to_le_bytes()).unwrap();
    writer.write_all(&1_u16.to_le_bytes()).unwrap();
    writer.write_all(&2_u16.to_le_bytes()).unwrap();
    writer.write_all(&44_100_u32.to_le_bytes()).unwrap();
    writer.write_all(&176_400_u32.to_le_bytes()).unwrap();
    writer.write_all(&4_u16.to_le_bytes()).unwrap();
    writer.write_all(&16_u16.to_le_bytes()).unwrap();
    writer.write_all(b"data").unwrap();
    writer.write_all(&data_length.to_le_bytes()).unwrap();
    for frame in 0..frames {
        let time = frame as f32 / 44_100.0;
        let left = (0.18 * (std::f32::consts::TAU * 220.0 * time).sin() * 32_768.0).round() as i16;
        let right = (0.15 * (std::f32::consts::TAU * 330.0 * time).sin() * 32_768.0).round() as i16;
        writer.write_all(&left.to_le_bytes()).unwrap();
        writer.write_all(&right.to_le_bytes()).unwrap();
    }
    writer.flush().unwrap();
}

fn required_environment_path(name: &str) -> PathBuf {
    std::env::var_os(name)
        .map(PathBuf::from)
        .unwrap_or_else(|| panic!("{name} is required for this ignored integration test"))
}
