use serde::Serialize;
use song_separation_rd::{
    synthesize_fixture, validate_manual_stems, JobFailure, ManualStemRequest,
};
use std::collections::HashMap;
use std::path::{Path, PathBuf};

#[derive(Serialize)]
struct FailureEnvelope<'a> {
    status: &'static str,
    failure: &'a JobFailure,
}

fn main() {
    if let Err(failure) = run() {
        println!(
            "{}",
            serde_json::to_string(&FailureEnvelope {
                status: "failed",
                failure: &failure,
            })
            .expect("failure is serializable")
        );
        std::process::exit(2);
    }
}

fn run() -> Result<(), JobFailure> {
    let mut args = std::env::args().skip(1);
    match args.next().as_deref() {
        Some("synthesize") => {
            let options = parse_options(args.collect());
            let output_dir = required_path(&options, "--output-dir")?;
            synthesize_fixture(&output_dir)?;
            println!(
                "{}",
                serde_json::json!({
                    "status": "completed",
                    "evidence_type": "deterministic_synthetic_fixture",
                    "files": ["mixture.wav", "vocals.wav", "accompaniment.wav"],
                    "sample_rate_hz": 44100,
                    "channels": 2,
                    "duration_frames": 44100
                })
            );
            Ok(())
        }
        Some("validate") => {
            let raw: Vec<String> = args.collect();
            let rights_acknowledged = raw.iter().any(|arg| arg == "--acknowledge-rights");
            let options = parse_options(raw);
            let cancel_file = options.get("--cancel-file").map(PathBuf::from);
            let request = ManualStemRequest {
                rights_acknowledged,
                mixture: required_path(&options, "--mixture")?,
                vocals: required_path(&options, "--vocals")?,
                accompaniment: required_path(&options, "--accompaniment")?,
            };
            let report = validate_manual_stems(
                &request,
                || cancel_file.as_deref().is_some_and(Path::exists),
                |progress| {
                    println!(
                        "{}",
                        serde_json::to_string(&progress).expect("progress is serializable")
                    );
                },
            )?;
            println!(
                "{}",
                serde_json::to_string(&report).expect("report is serializable")
            );
            Ok(())
        }
        _ => {
            eprintln!(
                "usage:\n  song_separation_rd synthesize --output-dir DIR\n  song_separation_rd validate --acknowledge-rights --mixture FILE --vocals FILE --accompaniment FILE [--cancel-file FILE]"
            );
            std::process::exit(64);
        }
    }
}

fn parse_options(args: Vec<String>) -> HashMap<String, String> {
    let mut options = HashMap::new();
    let mut index = 0;
    while index < args.len() {
        if args[index] == "--acknowledge-rights" {
            index += 1;
            continue;
        }
        if args[index].starts_with("--") && index + 1 < args.len() {
            options.insert(args[index].clone(), args[index + 1].clone());
            index += 2;
        } else {
            index += 1;
        }
    }
    options
}

fn required_path(
    options: &HashMap<String, String>,
    name: &'static str,
) -> Result<PathBuf, JobFailure> {
    options
        .get(name)
        .map(PathBuf::from)
        .ok_or_else(|| JobFailure {
            reason: song_separation_rd::JobFailureReason::InputNotFound,
            operation: "parse_arguments",
            detail: format!("required option {name} is missing"),
        })
}
