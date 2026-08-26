use song_separation_rd::{
    synthesize_fixture, validate_manual_stems, JobFailureReason, ManualStemRequest, ProgressStage,
};
use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};

static NEXT_DIR: AtomicU64 = AtomicU64::new(0);

fn temporary_directory(test_name: &str) -> PathBuf {
    let id = NEXT_DIR.fetch_add(1, Ordering::Relaxed);
    let path = std::env::temp_dir().join(format!(
        "voice-trainer-song-rd-{}-{}-{id}",
        std::process::id(),
        test_name
    ));
    fs::create_dir_all(&path).expect("create temporary test directory");
    path
}

fn request(paths: &[PathBuf; 3], rights_acknowledged: bool) -> ManualStemRequest {
    ManualStemRequest {
        rights_acknowledged,
        mixture: paths[0].clone(),
        vocals: paths[1].clone(),
        accompaniment: paths[2].clone(),
    }
}

#[test]
fn deterministic_fixture_validates_as_manual_not_model_evidence() {
    let directory = temporary_directory("valid");
    let paths = synthesize_fixture(&directory).expect("generate deterministic fixture");
    let mut progress = Vec::new();
    let report =
        validate_manual_stems(&request(&paths, true), || false, |item| progress.push(item))
            .expect("manual stem contract should pass");

    assert_eq!(report.evidence_type, "manual_stem_fallback");
    assert!(!report.generated_by_model);
    assert_eq!(report.contract.sample_rate_hz, 44_100);
    assert_eq!(report.contract.channels, 2);
    assert_eq!(report.contract.frame_count, 44_100);
    assert_eq!(report.stems.len(), 3);
    assert_eq!(
        progress.last().map(|item| item.stage),
        Some(ProgressStage::Completed)
    );
    assert!(report
        .stems
        .iter()
        .all(|item| item.sha256.len() == 64 && !item.sha256.contains(['\\', '/'])));

    fs::remove_dir_all(directory).expect("remove temporary test directory");
}

#[test]
fn missing_rights_acknowledgement_is_a_typed_failure() {
    let paths = [PathBuf::from("a"), PathBuf::from("b"), PathBuf::from("c")];
    let failure = validate_manual_stems(&request(&paths, false), || false, |_| {})
        .expect_err("rights gate must run before filesystem access");
    assert_eq!(
        failure.reason,
        JobFailureReason::RightsAcknowledgementRequired
    );
}

#[test]
fn cancellation_never_returns_completed_evidence() {
    let directory = temporary_directory("cancel");
    let paths = synthesize_fixture(&directory).expect("generate deterministic fixture");
    let mut checks = 0;
    let failure = validate_manual_stems(
        &request(&paths, true),
        || {
            checks += 1;
            checks >= 3
        },
        |_| {},
    )
    .expect_err("cancelled job must fail with a typed reason");
    assert_eq!(failure.reason, JobFailureReason::Cancelled);
    fs::remove_dir_all(directory).expect("remove temporary test directory");
}

#[test]
fn mismatched_stem_length_is_rejected() {
    let first = temporary_directory("mismatch-first");
    let second = temporary_directory("mismatch-second");
    let mut paths = synthesize_fixture(&first).expect("generate first fixture");
    let other = synthesize_fixture(&second).expect("generate second fixture");
    let file = fs::OpenOptions::new()
        .write(true)
        .open(&other[1])
        .expect("open alternate vocals");
    file.set_len(44 + 8_000).expect("truncate alternate vocals");
    paths[1] = other[1].clone();

    let failure = validate_manual_stems(&request(&paths, true), || false, |_| {})
        .expect_err("different frame counts must be rejected");
    assert!(matches!(
        failure.reason,
        JobFailureReason::ContractMismatch | JobFailureReason::UnsupportedFormat
    ));
    fs::remove_dir_all(first).expect("remove first temporary directory");
    fs::remove_dir_all(second).expect("remove second temporary directory");
}
