use serde_json::json;
use sha2::{Digest, Sha256};
use song_separation_rd::{
    evaluate_quality_dataset, synthesize_fixture, JobFailureReason, QualityDatasetRequest,
    QualityFlag, QualityProgressStage,
};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

static NEXT_DIR: AtomicU64 = AtomicU64::new(0);

fn temporary_directory(test_name: &str) -> PathBuf {
    let id = NEXT_DIR.fetch_add(1, Ordering::Relaxed);
    let path = std::env::temp_dir().join(format!(
        "voice-trainer-song-quality-{}-{}-{id}",
        std::process::id(),
        test_name
    ));
    fs::create_dir_all(&path).expect("create temporary test directory");
    path
}

fn sha256(path: &Path) -> String {
    format!(
        "{:x}",
        Sha256::digest(fs::read(path).expect("read fixture for hash"))
    )
}

fn prepare_case(directory: &Path) -> PathBuf {
    let paths = synthesize_fixture(directory).expect("generate deterministic fixture");
    fs::copy(&paths[1], directory.join("estimated-vocals.wav"))
        .expect("copy perfect vocals estimate");
    fs::copy(&paths[2], directory.join("estimated-accompaniment.wav"))
        .expect("copy perfect accompaniment estimate");
    let manifest = directory.join("quality-manifest.json");
    fs::write(
        &manifest,
        serde_json::to_vec_pretty(&json!({
            "schema_version": 1,
            "dataset_id": "deterministic-synthetic-contract",
            "model_id": "identity-test-only",
            "estimate_provenance": "synthetic_identity",
            "cases": [{
                "id": "synthetic-220hz",
                "license": {
                    "license_id": "CC0-1.0",
                    "rights_basis": "deterministically generated test fixture",
                    "source_url": "https://creativecommons.org/publicdomain/zero/1.0/",
                    "verified_by": "automated-test",
                    "verified_on": "2026-08-26"
                },
                "pitch_reference": {
                    "scope": "monophonic_lead",
                    "reviewed_by": "automated-test",
                    "reviewed_on": "2026-08-26"
                },
                "files": {
                    "mixture": "mixture.wav",
                    "reference_vocals": "vocals.wav",
                    "estimated_vocals": "estimated-vocals.wav",
                    "estimated_accompaniment": "estimated-accompaniment.wav"
                },
                "sha256": {
                    "mixture": sha256(&paths[0]),
                    "reference_vocals": sha256(&paths[1]),
                    "estimated_vocals": sha256(&directory.join("estimated-vocals.wav")),
                    "estimated_accompaniment": sha256(&directory.join("estimated-accompaniment.wav"))
                }
            }]
        }))
        .expect("serialize quality manifest"),
    )
    .expect("write quality manifest");
    manifest
}

fn request(
    directory: &Path,
    manifest: PathBuf,
    rights_acknowledged: bool,
) -> QualityDatasetRequest {
    QualityDatasetRequest {
        rights_acknowledged,
        manifest,
        dataset_root: directory.to_path_buf(),
    }
}

#[test]
fn identical_estimate_has_deterministic_waveform_and_pitch_evidence() {
    let directory = temporary_directory("perfect");
    let manifest = prepare_case(&directory);
    let mut progress = Vec::new();
    let report = evaluate_quality_dataset(
        &request(&directory, manifest, true),
        || false,
        |item| progress.push(item),
    )
    .expect("quality evaluation should complete");

    assert_eq!(report.algorithm_version, "srd03-quality-v1");
    assert!(!report.generated_by_model);
    assert_eq!(report.summary.case_count, 1);
    assert_eq!(report.summary.interpretable_case_count, 1);
    assert!(report.cases[0].waveform.vocals_si_sdr_db >= 119.0);
    assert!(report.cases[0].waveform.si_sdr_improvement_db > 5.0);
    assert!(report.cases[0].waveform.residual_error_dbfs < -80.0);
    assert!(report.cases[0]
        .pitch
        .median_absolute_cents
        .is_some_and(|value| value < 0.01));
    assert!(report.cases[0].confidence >= 0.95);
    assert!(!report.cases[0].interpretation_suppressed);
    assert!(!report.cases[0].pitch_interpretation_suppressed);
    assert_eq!(
        progress.last().map(|item| item.stage),
        Some(QualityProgressStage::Completed)
    );
    let serialized = serde_json::to_string(&report).expect("serialize report");
    assert!(!serialized.contains(directory.to_string_lossy().as_ref()));
    assert!(!serialized.contains(".wav"));
    fs::remove_dir_all(directory).expect("remove fixture directory");
}

#[test]
fn wrong_pitch_and_inconsistent_residual_are_flagged() {
    let directory = temporary_directory("wrong-pitch");
    let manifest = prepare_case(&directory);
    fs::copy(
        directory.join("accompaniment.wav"),
        directory.join("estimated-vocals.wav"),
    )
    .expect("replace estimate with 330 Hz backing");
    let mut value: serde_json::Value =
        serde_json::from_slice(&fs::read(&manifest).expect("read manifest"))
            .expect("parse manifest");
    value["cases"][0]["sha256"]["estimated_vocals"] =
        json!(sha256(&directory.join("estimated-vocals.wav")));
    fs::write(
        &manifest,
        serde_json::to_vec_pretty(&value).expect("serialize manifest"),
    )
    .expect("update manifest");

    let report = evaluate_quality_dataset(&request(&directory, manifest, true), || false, |_| {})
        .expect("quality evaluation should still report weak evidence");
    let case = &report.cases[0];
    assert!(case
        .pitch
        .median_absolute_cents
        .is_some_and(|value| value > 600.0));
    assert!(case.quality_flags.contains(&QualityFlag::LowPitchAgreement));
    assert!(case.quality_flags.contains(&QualityFlag::ResidualMismatch));
    fs::remove_dir_all(directory).expect("remove fixture directory");
}

#[test]
fn rights_and_hash_checks_fail_before_analysis() {
    let directory = temporary_directory("gates");
    let manifest = prepare_case(&directory);
    let denied = evaluate_quality_dataset(
        &request(&directory, manifest.clone(), false),
        || false,
        |_| {},
    )
    .expect_err("rights acknowledgement is mandatory");
    assert_eq!(
        denied.reason,
        JobFailureReason::RightsAcknowledgementRequired
    );

    fs::write(directory.join("estimated-vocals.wav"), b"tampered").expect("tamper estimate");
    let mismatch = evaluate_quality_dataset(&request(&directory, manifest, true), || false, |_| {})
        .expect_err("hash mismatch must stop before decoding");
    assert_eq!(mismatch.reason, JobFailureReason::IntegrityMismatch);
    fs::remove_dir_all(directory).expect("remove fixture directory");
}

#[test]
fn cancellation_never_emits_a_completed_report() {
    let directory = temporary_directory("cancel");
    let manifest = prepare_case(&directory);
    let mut checks = 0;
    let failure = evaluate_quality_dataset(
        &request(&directory, manifest, true),
        || {
            checks += 1;
            checks > 3
        },
        |_| {},
    )
    .expect_err("cancel should interrupt hashing or analysis");
    assert_eq!(failure.reason, JobFailureReason::Cancelled);
    fs::remove_dir_all(directory).expect("remove fixture directory");
}

#[test]
fn parent_traversal_in_manifest_is_rejected() {
    let directory = temporary_directory("traversal");
    let manifest = prepare_case(&directory);
    let mut value: serde_json::Value =
        serde_json::from_slice(&fs::read(&manifest).expect("read manifest"))
            .expect("parse manifest");
    value["cases"][0]["files"]["mixture"] = json!("../mixture.wav");
    fs::write(
        &manifest,
        serde_json::to_vec_pretty(&value).expect("serialize manifest"),
    )
    .expect("update manifest");
    let failure = evaluate_quality_dataset(&request(&directory, manifest, true), || false, |_| {})
        .expect_err("dataset root must be a hard boundary");
    assert_eq!(failure.reason, JobFailureReason::DatasetManifestInvalid);
    fs::remove_dir_all(directory).expect("remove fixture directory");
}

#[test]
fn pitch_ineligible_case_preserves_waveform_confidence() {
    let directory = temporary_directory("pitch-ineligible");
    let manifest = prepare_case(&directory);
    let mut value: serde_json::Value =
        serde_json::from_slice(&fs::read(&manifest).expect("read manifest"))
            .expect("parse manifest");
    value["cases"][0]["pitch_reference"]["scope"] = json!("not_eligible");
    fs::write(
        &manifest,
        serde_json::to_vec_pretty(&value).expect("serialize manifest"),
    )
    .expect("update manifest");

    let report = evaluate_quality_dataset(&request(&directory, manifest, true), || false, |_| {})
        .expect("waveform evidence remains valid without pitch eligibility");
    let case = &report.cases[0];
    assert!(case.waveform_confidence >= 0.95);
    assert_eq!(case.pitch_confidence, None);
    assert!(!case.interpretation_suppressed);
    assert!(case.pitch_interpretation_suppressed);
    assert!(case
        .quality_flags
        .contains(&QualityFlag::ReferencePitchNotEligible));
    fs::remove_dir_all(directory).expect("remove fixture directory");
}
