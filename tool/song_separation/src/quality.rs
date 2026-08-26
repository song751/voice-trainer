use crate::{JobFailure, JobFailureReason, WavContract};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::cmp::Ordering;
use std::fs::File;
use std::io::{BufReader, Read, Seek, SeekFrom};
use std::path::{Component, Path, PathBuf};

const QUALITY_SCHEMA_VERSION: u32 = 1;
const QUALITY_ALGORITHM_VERSION: &str = "srd03-quality-v1";
const REQUIRED_SAMPLE_RATE: u32 = 44_100;
const REQUIRED_CHANNELS: u16 = 2;
const PITCH_SAMPLE_RATE: usize = 14_700;
const PITCH_WINDOW: usize = 1024;
const PITCH_HOP: usize = 147;
const MIN_F0_HZ: f64 = 60.0;
const MAX_F0_HZ: f64 = 1000.0;

#[derive(Clone, Debug)]
pub struct QualityDatasetRequest {
    pub rights_acknowledged: bool,
    pub manifest: PathBuf,
    pub dataset_root: PathBuf,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum QualityProgressStage {
    ParsingManifest,
    VerifyingDataset,
    AnalyzingWaveforms,
    AligningPitch,
    Completed,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
pub struct QualityProgress {
    pub stage: QualityProgressStage,
    pub completed_units: u64,
    pub total_units: u64,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum QualityFlag {
    ReferenceLevelTooLow,
    EstimatedVocalsLevelTooLow,
    ReferenceClipping,
    EstimatedVocalsClipping,
    InsufficientReferencePitch,
    InsufficientEstimatedPitch,
    ReferencePitchNotEligible,
    LowPitchAgreement,
    ResidualMismatch,
    LowConfidence,
}

#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct PitchAlignmentMetrics {
    pub reference_voiced_fraction: f64,
    pub estimated_voiced_fraction: f64,
    pub aligned_frame_count: u64,
    pub median_absolute_cents: Option<f64>,
    pub p90_absolute_cents: Option<f64>,
    pub within_50_cents_fraction: Option<f64>,
    pub mean_dtw_cost_cents: Option<f64>,
}

#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct WaveformQualityMetrics {
    pub reference_vocals_rms_dbfs: f64,
    pub estimated_vocals_rms_dbfs: f64,
    pub reference_clipped_fraction: f64,
    pub estimated_vocals_clipped_fraction: f64,
    pub vocals_si_sdr_db: f64,
    pub mixture_baseline_si_sdr_db: f64,
    pub si_sdr_improvement_db: f64,
    pub residual_error_dbfs: f64,
}

#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct QualityCaseReport {
    pub case_id: String,
    pub license_id: String,
    pub rights_basis: String,
    pub pitch_reference_scope: PitchReferenceScope,
    pub contract: WavContract,
    pub waveform: WaveformQualityMetrics,
    pub pitch: PitchAlignmentMetrics,
    pub waveform_confidence: f64,
    pub pitch_confidence: Option<f64>,
    pub confidence: f64,
    pub interpretation_suppressed: bool,
    pub pitch_interpretation_suppressed: bool,
    pub quality_flags: Vec<QualityFlag>,
}

#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct DatasetQualitySummary {
    pub case_count: u64,
    pub interpretable_case_count: u64,
    pub median_vocals_si_sdr_db: f64,
    pub median_si_sdr_improvement_db: f64,
    pub median_pitch_error_cents: Option<f64>,
    pub minimum_confidence: f64,
}

#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct DatasetQualityReport {
    pub status: &'static str,
    pub evidence_type: &'static str,
    pub generated_by_model: bool,
    pub estimate_provenance: EstimateProvenance,
    pub algorithm_version: &'static str,
    pub dataset_id: String,
    pub model_id: String,
    pub cases: Vec<QualityCaseReport>,
    pub summary: DatasetQualitySummary,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct QualityManifest {
    schema_version: u32,
    dataset_id: String,
    model_id: String,
    estimate_provenance: EstimateProvenance,
    cases: Vec<QualityCase>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct QualityCase {
    id: String,
    license: LicenseEvidence,
    pitch_reference: PitchReferenceEvidence,
    files: QualityFiles,
    sha256: QualityHashes,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct LicenseEvidence {
    license_id: String,
    rights_basis: String,
    source_url: String,
    verified_by: String,
    verified_on: String,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum EstimateProvenance {
    ModelOutput,
    SyntheticIdentity,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum PitchReferenceScope {
    MonophonicLead,
    NotEligible,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct PitchReferenceEvidence {
    scope: PitchReferenceScope,
    reviewed_by: String,
    reviewed_on: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct QualityFiles {
    mixture: String,
    reference_vocals: String,
    estimated_vocals: String,
    estimated_accompaniment: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct QualityHashes {
    mixture: String,
    reference_vocals: String,
    estimated_vocals: String,
    estimated_accompaniment: String,
}

#[derive(Debug)]
struct Pcm16Wav {
    contract: WavContract,
    samples: Vec<f64>,
}

pub fn evaluate_quality_dataset<C, P>(
    request: &QualityDatasetRequest,
    mut should_cancel: C,
    mut on_progress: P,
) -> Result<DatasetQualityReport, JobFailure>
where
    C: FnMut() -> bool,
    P: FnMut(QualityProgress),
{
    if !request.rights_acknowledged {
        return Err(failure(
            JobFailureReason::RightsAcknowledgementRequired,
            "evaluate_rights",
            "explicit rights acknowledgement is required",
        ));
    }
    check_cancelled(&mut should_cancel)?;
    on_progress(QualityProgress {
        stage: QualityProgressStage::ParsingManifest,
        completed_units: 0,
        total_units: 1,
    });
    let manifest = parse_manifest(&request.manifest)?;
    validate_manifest(&manifest)?;
    on_progress(QualityProgress {
        stage: QualityProgressStage::ParsingManifest,
        completed_units: 1,
        total_units: 1,
    });

    let total_cases = manifest.cases.len() as u64;
    let mut reports = Vec::with_capacity(manifest.cases.len());
    for (index, case) in manifest.cases.iter().enumerate() {
        check_cancelled(&mut should_cancel)?;
        on_progress(QualityProgress {
            stage: QualityProgressStage::VerifyingDataset,
            completed_units: index as u64,
            total_units: total_cases,
        });
        let paths = resolve_paths(&request.dataset_root, &case.files)?;
        verify_hashes(&paths, &case.sha256, &mut should_cancel)?;
        let audio = load_case(&paths)?;
        let contract = validate_contracts(&audio)?;

        check_cancelled(&mut should_cancel)?;
        on_progress(QualityProgress {
            stage: QualityProgressStage::AnalyzingWaveforms,
            completed_units: index as u64,
            total_units: total_cases,
        });
        let waveform = waveform_metrics(&audio);

        check_cancelled(&mut should_cancel)?;
        on_progress(QualityProgress {
            stage: QualityProgressStage::AligningPitch,
            completed_units: index as u64,
            total_units: total_cases,
        });
        let pitch = if case.pitch_reference.scope == PitchReferenceScope::MonophonicLead {
            pitch_metrics(
                &audio.reference_vocals.samples,
                &audio.estimated_vocals.samples,
                &mut should_cancel,
            )?
        } else {
            PitchAlignmentMetrics {
                reference_voiced_fraction: 0.0,
                estimated_voiced_fraction: 0.0,
                aligned_frame_count: 0,
                median_absolute_cents: None,
                p90_absolute_cents: None,
                within_50_cents_fraction: None,
                mean_dtw_cost_cents: None,
            }
        };
        let quality = assess_quality(&waveform, &pitch, case.pitch_reference.scope);
        reports.push(QualityCaseReport {
            case_id: case.id.clone(),
            license_id: case.license.license_id.clone(),
            rights_basis: case.license.rights_basis.clone(),
            pitch_reference_scope: case.pitch_reference.scope,
            contract,
            waveform,
            pitch,
            waveform_confidence: quality.waveform_confidence,
            pitch_confidence: quality.pitch_confidence,
            confidence: quality.confidence,
            interpretation_suppressed: quality.interpretation_suppressed,
            pitch_interpretation_suppressed: quality.pitch_interpretation_suppressed,
            quality_flags: quality.flags,
        });
    }
    let summary = summarize(&reports);
    on_progress(QualityProgress {
        stage: QualityProgressStage::Completed,
        completed_units: total_cases,
        total_units: total_cases,
    });
    Ok(DatasetQualityReport {
        status: "completed",
        evidence_type: "licensed_stem_quality_evaluation",
        generated_by_model: manifest.estimate_provenance == EstimateProvenance::ModelOutput,
        estimate_provenance: manifest.estimate_provenance,
        algorithm_version: QUALITY_ALGORITHM_VERSION,
        dataset_id: manifest.dataset_id,
        model_id: manifest.model_id,
        cases: reports,
        summary,
    })
}

#[derive(Debug)]
struct CasePaths {
    mixture: PathBuf,
    reference_vocals: PathBuf,
    estimated_vocals: PathBuf,
    estimated_accompaniment: PathBuf,
}

#[derive(Debug)]
struct CaseAudio {
    mixture: Pcm16Wav,
    reference_vocals: Pcm16Wav,
    estimated_vocals: Pcm16Wav,
    estimated_accompaniment: Pcm16Wav,
}

fn parse_manifest(path: &Path) -> Result<QualityManifest, JobFailure> {
    let reader = File::open(path).map_err(|error| {
        failure(
            JobFailureReason::InputNotFound,
            "open_quality_manifest",
            format!("quality manifest cannot be opened: {}", error.kind()),
        )
    })?;
    serde_json::from_reader(BufReader::new(reader)).map_err(|error| {
        failure(
            JobFailureReason::DatasetManifestInvalid,
            "parse_quality_manifest",
            format!("quality manifest is invalid JSON: {error}"),
        )
    })
}

fn validate_manifest(manifest: &QualityManifest) -> Result<(), JobFailure> {
    if manifest.schema_version != QUALITY_SCHEMA_VERSION {
        return Err(manifest_invalid(
            "unsupported quality manifest schema_version",
        ));
    }
    if manifest.dataset_id.trim().is_empty() || manifest.model_id.trim().is_empty() {
        return Err(manifest_invalid("dataset_id and model_id are required"));
    }
    if manifest.cases.is_empty() {
        return Err(manifest_invalid(
            "at least one licensed quality case is required",
        ));
    }
    let mut ids = std::collections::HashSet::new();
    for case in &manifest.cases {
        if case.id.trim().is_empty() || !ids.insert(&case.id) {
            return Err(manifest_invalid("case ids must be non-empty and unique"));
        }
        let license = &case.license;
        if license.license_id.trim().is_empty()
            || license.rights_basis.trim().is_empty()
            || license.source_url.trim().is_empty()
            || license.verified_by.trim().is_empty()
            || license.verified_on.trim().is_empty()
        {
            return Err(manifest_invalid(
                "each case requires license, source, verifier, and verification date",
            ));
        }
        if case.pitch_reference.reviewed_by.trim().is_empty()
            || case.pitch_reference.reviewed_on.trim().is_empty()
        {
            return Err(manifest_invalid(
                "each case requires a reviewer and date for pitch-reference scope",
            ));
        }
        for hash in [
            &case.sha256.mixture,
            &case.sha256.reference_vocals,
            &case.sha256.estimated_vocals,
            &case.sha256.estimated_accompaniment,
        ] {
            if hash.len() != 64 || !hash.bytes().all(|byte| byte.is_ascii_hexdigit()) {
                return Err(manifest_invalid("each sha256 must contain 64 hex digits"));
            }
        }
    }
    Ok(())
}

fn resolve_paths(root: &Path, files: &QualityFiles) -> Result<CasePaths, JobFailure> {
    fn resolve(root: &Path, value: &str) -> Result<PathBuf, JobFailure> {
        let relative = Path::new(value);
        if value.trim().is_empty()
            || relative.is_absolute()
            || relative.components().any(|component| {
                matches!(
                    component,
                    Component::ParentDir | Component::RootDir | Component::Prefix(_)
                )
            })
        {
            return Err(manifest_invalid(
                "audio filenames must be non-empty relative paths without parent traversal",
            ));
        }
        Ok(root.join(relative))
    }
    Ok(CasePaths {
        mixture: resolve(root, &files.mixture)?,
        reference_vocals: resolve(root, &files.reference_vocals)?,
        estimated_vocals: resolve(root, &files.estimated_vocals)?,
        estimated_accompaniment: resolve(root, &files.estimated_accompaniment)?,
    })
}

fn verify_hashes<C>(
    paths: &CasePaths,
    hashes: &QualityHashes,
    should_cancel: &mut C,
) -> Result<(), JobFailure>
where
    C: FnMut() -> bool,
{
    for (path, expected) in [
        (&paths.mixture, &hashes.mixture),
        (&paths.reference_vocals, &hashes.reference_vocals),
        (&paths.estimated_vocals, &hashes.estimated_vocals),
        (
            &paths.estimated_accompaniment,
            &hashes.estimated_accompaniment,
        ),
    ] {
        let actual = hash(path, should_cancel)?;
        if !actual.eq_ignore_ascii_case(expected) {
            return Err(failure(
                JobFailureReason::IntegrityMismatch,
                "verify_quality_input",
                "one quality input does not match its declared sha256",
            ));
        }
    }
    Ok(())
}

fn hash<C>(path: &Path, should_cancel: &mut C) -> Result<String, JobFailure>
where
    C: FnMut() -> bool,
{
    let mut reader = BufReader::new(File::open(path).map_err(|error| {
        failure(
            JobFailureReason::InputNotFound,
            "open_quality_input",
            format!("one quality input cannot be opened: {}", error.kind()),
        )
    })?);
    let mut hasher = Sha256::new();
    let mut buffer = [0_u8; 64 * 1024];
    loop {
        check_cancelled(should_cancel)?;
        let count = reader.read(&mut buffer).map_err(|error| {
            failure(
                JobFailureReason::IoFailure,
                "hash_quality_input",
                format!("quality input cannot be read: {}", error.kind()),
            )
        })?;
        if count == 0 {
            break;
        }
        hasher.update(&buffer[..count]);
    }
    Ok(format!("{:x}", hasher.finalize()))
}

fn load_case(paths: &CasePaths) -> Result<CaseAudio, JobFailure> {
    Ok(CaseAudio {
        mixture: read_pcm16_wav(&paths.mixture)?,
        reference_vocals: read_pcm16_wav(&paths.reference_vocals)?,
        estimated_vocals: read_pcm16_wav(&paths.estimated_vocals)?,
        estimated_accompaniment: read_pcm16_wav(&paths.estimated_accompaniment)?,
    })
}

fn read_pcm16_wav(path: &Path) -> Result<Pcm16Wav, JobFailure> {
    let file = File::open(path).map_err(|error| {
        failure(
            JobFailureReason::InputNotFound,
            "open_quality_input",
            format!("one quality input cannot be opened: {}", error.kind()),
        )
    })?;
    let file_length = file
        .metadata()
        .map_err(|error| io_failure("read_quality_input", error))?
        .len();
    let mut reader = BufReader::new(file);
    let mut riff = [0_u8; 12];
    reader
        .read_exact(&mut riff)
        .map_err(|error| unsupported("read_quality_header", error))?;
    if &riff[0..4] != b"RIFF" || &riff[8..12] != b"WAVE" {
        return Err(unsupported_detail("quality input is not RIFF/WAVE"));
    }
    let mut format = None;
    let mut data = None;
    loop {
        let mut header = [0_u8; 8];
        if reader.read_exact(&mut header).is_err() {
            break;
        }
        let size = u32::from_le_bytes(header[4..8].try_into().expect("four bytes"));
        match &header[0..4] {
            b"fmt " => {
                if size < 16 {
                    return Err(unsupported_detail("quality WAV fmt chunk is too short"));
                }
                let mut fields = [0_u8; 16];
                reader
                    .read_exact(&mut fields)
                    .map_err(|error| unsupported("read_quality_header", error))?;
                format = Some((
                    u16::from_le_bytes(fields[0..2].try_into().expect("two bytes")),
                    u16::from_le_bytes(fields[2..4].try_into().expect("two bytes")),
                    u32::from_le_bytes(fields[4..8].try_into().expect("four bytes")),
                    u16::from_le_bytes(fields[14..16].try_into().expect("two bytes")),
                ));
                reader
                    .seek(SeekFrom::Current(i64::from(size - 16)))
                    .map_err(|error| unsupported("read_quality_header", error))?;
            }
            b"data" => {
                let start = reader
                    .stream_position()
                    .map_err(|error| unsupported("read_quality_header", error))?;
                if start.saturating_add(u64::from(size)) > file_length {
                    return Err(unsupported_detail("quality WAV data extends past EOF"));
                }
                data = Some((start, size));
                reader
                    .seek(SeekFrom::Current(i64::from(size)))
                    .map_err(|error| unsupported("read_quality_header", error))?;
            }
            _ => {
                reader
                    .seek(SeekFrom::Current(i64::from(size)))
                    .map_err(|error| unsupported("read_quality_header", error))?;
            }
        }
        if size % 2 == 1 {
            reader
                .seek(SeekFrom::Current(1))
                .map_err(|error| unsupported("read_quality_header", error))?;
        }
        if format.is_some() && data.is_some() {
            break;
        }
    }
    let Some((encoding, channels, sample_rate_hz, bits_per_sample)) = format else {
        return Err(unsupported_detail("quality WAV fmt chunk is missing"));
    };
    let Some((data_start, data_length)) = data else {
        return Err(unsupported_detail("quality WAV data chunk is missing"));
    };
    if encoding != 1 || bits_per_sample != 16 || channels == 0 || data_length == 0 {
        return Err(unsupported_detail(
            "quality input must be non-empty interleaved PCM16 WAV",
        ));
    }
    let bytes_per_frame = u32::from(channels) * 2;
    if data_length % bytes_per_frame != 0 {
        return Err(unsupported_detail(
            "quality WAV contains an incomplete frame",
        ));
    }
    reader
        .seek(SeekFrom::Start(data_start))
        .map_err(|error| unsupported("read_quality_data", error))?;
    let mut bytes = vec![0_u8; data_length as usize];
    reader
        .read_exact(&mut bytes)
        .map_err(|error| unsupported("read_quality_data", error))?;
    let samples = bytes
        .chunks_exact(2)
        .map(|pair| f64::from(i16::from_le_bytes([pair[0], pair[1]])) / 32_768.0)
        .collect();
    Ok(Pcm16Wav {
        contract: WavContract {
            sample_rate_hz,
            channels,
            bits_per_sample,
            frame_count: u64::from(data_length / bytes_per_frame),
        },
        samples,
    })
}

fn validate_contracts(audio: &CaseAudio) -> Result<WavContract, JobFailure> {
    let expected = audio.mixture.contract.clone();
    for item in [
        &audio.reference_vocals,
        &audio.estimated_vocals,
        &audio.estimated_accompaniment,
    ] {
        if item.contract != expected {
            return Err(failure(
                JobFailureReason::ContractMismatch,
                "validate_quality_contract",
                "quality WAV formats or frame counts differ",
            ));
        }
    }
    if expected.sample_rate_hz != REQUIRED_SAMPLE_RATE || expected.channels != REQUIRED_CHANNELS {
        return Err(failure(
            JobFailureReason::UnsupportedFormat,
            "validate_quality_contract",
            "SRD-03 quality evidence requires 44.1 kHz stereo PCM16 WAV",
        ));
    }
    Ok(expected)
}

fn waveform_metrics(audio: &CaseAudio) -> WaveformQualityMetrics {
    let reference = &audio.reference_vocals.samples;
    let estimated = &audio.estimated_vocals.samples;
    let mixture = &audio.mixture.samples;
    let accompaniment = &audio.estimated_accompaniment.samples;
    let residual_error = mixture
        .iter()
        .zip(estimated)
        .zip(accompaniment)
        .map(|((mix, voice), backing)| mix - voice - backing);
    let vocals_si_sdr_db = si_sdr(reference, estimated);
    let baseline = si_sdr(reference, mixture);
    WaveformQualityMetrics {
        reference_vocals_rms_dbfs: rms_dbfs(reference.iter().copied()),
        estimated_vocals_rms_dbfs: rms_dbfs(estimated.iter().copied()),
        reference_clipped_fraction: clipped_fraction(reference),
        estimated_vocals_clipped_fraction: clipped_fraction(estimated),
        vocals_si_sdr_db,
        mixture_baseline_si_sdr_db: baseline,
        si_sdr_improvement_db: vocals_si_sdr_db - baseline,
        residual_error_dbfs: rms_dbfs(residual_error),
    }
}

fn rms_dbfs<I>(samples: I) -> f64
where
    I: Iterator<Item = f64>,
{
    let (sum, count) = samples.fold((0.0, 0_u64), |(sum, count), sample| {
        (sum + sample * sample, count + 1)
    });
    if count == 0 || sum <= f64::EPSILON {
        -120.0
    } else {
        10.0 * (sum / count as f64).log10()
    }
}

fn clipped_fraction(samples: &[f64]) -> f64 {
    samples
        .iter()
        .filter(|sample| sample.abs() >= 0.999)
        .count() as f64
        / samples.len().max(1) as f64
}

fn si_sdr(reference: &[f64], estimate: &[f64]) -> f64 {
    let reference_mean = reference.iter().sum::<f64>() / reference.len().max(1) as f64;
    let estimate_mean = estimate.iter().sum::<f64>() / estimate.len().max(1) as f64;
    let reference_energy = reference
        .iter()
        .map(|sample| (sample - reference_mean).powi(2))
        .sum::<f64>();
    if reference_energy <= f64::EPSILON {
        return -120.0;
    }
    let scale = reference
        .iter()
        .zip(estimate)
        .map(|(reference, estimate)| (reference - reference_mean) * (estimate - estimate_mean))
        .sum::<f64>()
        / reference_energy;
    let (target_energy, noise_energy) = reference.iter().zip(estimate).fold(
        (0.0, 0.0),
        |(target_energy, noise_energy), (reference, estimate)| {
            let target = scale * (reference - reference_mean);
            let noise = estimate - estimate_mean - target;
            (
                target_energy + target * target,
                noise_energy + noise * noise,
            )
        },
    );
    if noise_energy <= 1.0e-20 {
        120.0
    } else if target_energy <= 1.0e-20 {
        -120.0
    } else {
        (10.0 * (target_energy / noise_energy).log10()).clamp(-120.0, 120.0)
    }
}

fn pitch_metrics<C>(
    reference: &[f64],
    estimate: &[f64],
    should_cancel: &mut C,
) -> Result<PitchAlignmentMetrics, JobFailure>
where
    C: FnMut() -> bool,
{
    let reference_track = estimate_pitch_track(reference, should_cancel)?;
    let estimated_track = estimate_pitch_track(estimate, should_cancel)?;
    let reference_voiced = reference_track.iter().flatten().count();
    let estimated_voiced = estimated_track.iter().flatten().count();
    let reference_fraction = reference_voiced as f64 / reference_track.len().max(1) as f64;
    let estimated_fraction = estimated_voiced as f64 / estimated_track.len().max(1) as f64;
    let reference_cents: Vec<f64> = reference_track.into_iter().flatten().collect();
    let estimated_cents: Vec<f64> = estimated_track.into_iter().flatten().collect();
    if reference_cents.is_empty() || estimated_cents.is_empty() {
        return Ok(PitchAlignmentMetrics {
            reference_voiced_fraction: reference_fraction,
            estimated_voiced_fraction: estimated_fraction,
            aligned_frame_count: 0,
            median_absolute_cents: None,
            p90_absolute_cents: None,
            within_50_cents_fraction: None,
            mean_dtw_cost_cents: None,
        });
    }
    let aligned = dtw_align(&reference_cents, &estimated_cents, should_cancel)?;
    let mut errors: Vec<f64> = aligned
        .iter()
        .map(|(left, right)| (reference_cents[*left] - estimated_cents[*right]).abs())
        .collect();
    let within_50 =
        errors.iter().filter(|error| **error <= 50.0).count() as f64 / errors.len().max(1) as f64;
    let mean_cost =
        errors.iter().map(|value| value.min(1200.0)).sum::<f64>() / errors.len().max(1) as f64;
    let median = percentile(&mut errors.clone(), 0.5);
    let p90 = percentile(&mut errors, 0.9);
    Ok(PitchAlignmentMetrics {
        reference_voiced_fraction: reference_fraction,
        estimated_voiced_fraction: estimated_fraction,
        aligned_frame_count: aligned.len() as u64,
        median_absolute_cents: Some(median),
        p90_absolute_cents: Some(p90),
        within_50_cents_fraction: Some(within_50),
        mean_dtw_cost_cents: Some(mean_cost),
    })
}

fn estimate_pitch_track<C>(
    stereo: &[f64],
    should_cancel: &mut C,
) -> Result<Vec<Option<f64>>, JobFailure>
where
    C: FnMut() -> bool,
{
    let mono: Vec<f64> = stereo
        .chunks_exact(2)
        .map(|frame| (frame[0] + frame[1]) * 0.5)
        .collect();
    let downsampled: Vec<f64> = mono
        .chunks_exact(3)
        .map(|chunk| (chunk[0] + chunk[1] + chunk[2]) / 3.0)
        .collect();
    if downsampled.len() < PITCH_WINDOW {
        return Ok(Vec::new());
    }
    let min_lag = (PITCH_SAMPLE_RATE as f64 / MAX_F0_HZ).floor() as usize;
    let max_lag = (PITCH_SAMPLE_RATE as f64 / MIN_F0_HZ).ceil() as usize;
    let mut track = Vec::with_capacity((downsampled.len() - PITCH_WINDOW) / PITCH_HOP + 1);
    for start in (0..=downsampled.len() - PITCH_WINDOW).step_by(PITCH_HOP) {
        check_cancelled(should_cancel)?;
        let frame = &downsampled[start..start + PITCH_WINDOW];
        let mean = frame.iter().sum::<f64>() / frame.len() as f64;
        let energy = frame
            .iter()
            .map(|sample| (sample - mean).powi(2))
            .sum::<f64>()
            / frame.len() as f64;
        if energy <= 10_f64.powf(-55.0 / 10.0) {
            track.push(None);
            continue;
        }
        let mut correlations = Vec::with_capacity(max_lag - min_lag + 1);
        for lag in min_lag..=max_lag {
            let mut numerator = 0.0;
            let mut left_energy = 0.0;
            let mut right_energy = 0.0;
            for index in 0..PITCH_WINDOW - lag {
                let left = frame[index] - mean;
                let right = frame[index + lag] - mean;
                numerator += left * right;
                left_energy += left * left;
                right_energy += right * right;
            }
            correlations.push(numerator / (left_energy * right_energy).sqrt().max(1.0e-12));
        }
        let local_peak = correlations
            .windows(3)
            .enumerate()
            .filter(|(_, values)| values[1] >= values[0] && values[1] >= values[2])
            .map(|(index, values)| (index + 1, values[1]))
            .find(|(_, value)| *value >= 0.72)
            .or_else(|| {
                correlations
                    .iter()
                    .copied()
                    .enumerate()
                    .max_by(|left, right| left.1.total_cmp(&right.1))
            });
        let Some((offset, clarity)) = local_peak else {
            track.push(None);
            continue;
        };
        if clarity < 0.55 {
            track.push(None);
            continue;
        }
        let lag = min_lag + offset;
        let refined_lag = if offset > 0 && offset + 1 < correlations.len() {
            let left = correlations[offset - 1];
            let center = correlations[offset];
            let right = correlations[offset + 1];
            let denominator = left - 2.0 * center + right;
            if denominator.abs() > 1.0e-12 {
                lag as f64 + 0.5 * (left - right) / denominator
            } else {
                lag as f64
            }
        } else {
            lag as f64
        };
        let frequency = PITCH_SAMPLE_RATE as f64 / refined_lag;
        track.push(Some(1200.0 * (frequency / 440.0).log2()));
    }
    Ok(track)
}

fn dtw_align<C>(
    reference: &[f64],
    estimate: &[f64],
    should_cancel: &mut C,
) -> Result<Vec<(usize, usize)>, JobFailure>
where
    C: FnMut() -> bool,
{
    let rows = reference.len();
    let columns = estimate.len();
    let mut costs = vec![f64::INFINITY; (rows + 1) * (columns + 1)];
    let mut parent = vec![0_u8; (rows + 1) * (columns + 1)];
    costs[0] = 0.0;
    let band = rows.abs_diff(columns).max(rows.max(columns) / 5).max(10);
    for row in 1..=rows {
        check_cancelled(should_cancel)?;
        let expected_column = row * columns / rows;
        let start = expected_column.saturating_sub(band).max(1);
        let end = (expected_column + band).min(columns);
        for column in start..=end {
            let diagonal = costs[(row - 1) * (columns + 1) + column - 1];
            let up = costs[(row - 1) * (columns + 1) + column];
            let left = costs[row * (columns + 1) + column - 1];
            let (prior, direction) = if diagonal <= up && diagonal <= left {
                (diagonal, 1)
            } else if up <= left {
                (up, 2)
            } else {
                (left, 3)
            };
            let index = row * (columns + 1) + column;
            costs[index] = prior
                + (reference[row - 1] - estimate[column - 1])
                    .abs()
                    .min(1200.0);
            parent[index] = direction;
        }
    }
    if !costs[rows * (columns + 1) + columns].is_finite() {
        return Err(failure(
            JobFailureReason::ContractMismatch,
            "align_reference_pitch",
            "pitch tracks exceed the bounded DTW alignment window",
        ));
    }
    let (mut row, mut column) = (rows, columns);
    let mut aligned = Vec::with_capacity(rows.max(columns));
    while row > 0 && column > 0 {
        aligned.push((row - 1, column - 1));
        match parent[row * (columns + 1) + column] {
            1 => {
                row -= 1;
                column -= 1;
            }
            2 => row -= 1,
            3 => column -= 1,
            _ => break,
        }
    }
    aligned.reverse();
    Ok(aligned)
}

struct QualityAssessment {
    waveform_confidence: f64,
    pitch_confidence: Option<f64>,
    confidence: f64,
    interpretation_suppressed: bool,
    pitch_interpretation_suppressed: bool,
    flags: Vec<QualityFlag>,
}

fn assess_quality(
    waveform: &WaveformQualityMetrics,
    pitch: &PitchAlignmentMetrics,
    pitch_scope: PitchReferenceScope,
) -> QualityAssessment {
    let mut flags = Vec::new();
    if waveform.reference_vocals_rms_dbfs < -45.0 {
        flags.push(QualityFlag::ReferenceLevelTooLow);
    }
    if waveform.estimated_vocals_rms_dbfs < -55.0 {
        flags.push(QualityFlag::EstimatedVocalsLevelTooLow);
    }
    if waveform.reference_clipped_fraction > 0.001 {
        flags.push(QualityFlag::ReferenceClipping);
    }
    if waveform.estimated_vocals_clipped_fraction > 0.001 {
        flags.push(QualityFlag::EstimatedVocalsClipping);
    }
    if pitch_scope == PitchReferenceScope::NotEligible {
        flags.push(QualityFlag::ReferencePitchNotEligible);
    } else {
        if pitch.reference_voiced_fraction < 0.25 {
            flags.push(QualityFlag::InsufficientReferencePitch);
        }
        if pitch.estimated_voiced_fraction < 0.25 {
            flags.push(QualityFlag::InsufficientEstimatedPitch);
        }
        if pitch
            .within_50_cents_fraction
            .is_some_and(|value| value < 0.6)
        {
            flags.push(QualityFlag::LowPitchAgreement);
        }
    }
    if waveform.residual_error_dbfs > -45.0 {
        flags.push(QualityFlag::ResidualMismatch);
    }
    let level_confidence = ((waveform.reference_vocals_rms_dbfs + 60.0) / 30.0).clamp(0.0, 1.0);
    let pitch_confidence = if pitch_scope == PitchReferenceScope::MonophonicLead {
        Some(
            pitch
                .reference_voiced_fraction
                .min(pitch.estimated_voiced_fraction)
                .clamp(0.0, 1.0),
        )
    } else {
        None
    };
    let residual_confidence = ((-waveform.residual_error_dbfs - 25.0) / 35.0).clamp(0.0, 1.0);
    let clipping_confidence = if waveform.reference_clipped_fraction > 0.001
        || waveform.estimated_vocals_clipped_fraction > 0.001
    {
        0.4
    } else {
        1.0
    };
    let waveform_confidence = level_confidence
        .min(residual_confidence)
        .min(clipping_confidence);
    let confidence = pitch_confidence
        .map(|pitch_value| waveform_confidence.min(pitch_value))
        .unwrap_or(waveform_confidence);
    let pitch_suppressed = pitch_scope == PitchReferenceScope::NotEligible
        || pitch.median_absolute_cents.is_none()
        || flags.contains(&QualityFlag::InsufficientReferencePitch);
    let suppressed = waveform_confidence < 0.6
        || (pitch_scope == PitchReferenceScope::MonophonicLead && pitch_suppressed);
    if suppressed {
        flags.push(QualityFlag::LowConfidence);
    }
    QualityAssessment {
        waveform_confidence,
        pitch_confidence,
        confidence,
        interpretation_suppressed: suppressed,
        pitch_interpretation_suppressed: pitch_suppressed,
        flags,
    }
}

fn summarize(reports: &[QualityCaseReport]) -> DatasetQualitySummary {
    let mut sdr: Vec<f64> = reports
        .iter()
        .map(|report| report.waveform.vocals_si_sdr_db)
        .collect();
    let mut improvement: Vec<f64> = reports
        .iter()
        .map(|report| report.waveform.si_sdr_improvement_db)
        .collect();
    let mut pitch: Vec<f64> = reports
        .iter()
        .filter_map(|report| report.pitch.median_absolute_cents)
        .collect();
    DatasetQualitySummary {
        case_count: reports.len() as u64,
        interpretable_case_count: reports
            .iter()
            .filter(|report| !report.interpretation_suppressed)
            .count() as u64,
        median_vocals_si_sdr_db: percentile(&mut sdr, 0.5),
        median_si_sdr_improvement_db: percentile(&mut improvement, 0.5),
        median_pitch_error_cents: (!pitch.is_empty()).then(|| percentile(&mut pitch, 0.5)),
        minimum_confidence: reports
            .iter()
            .map(|report| report.confidence)
            .min_by(|left, right| left.total_cmp(right))
            .unwrap_or(0.0),
    }
}

fn percentile(values: &mut [f64], quantile: f64) -> f64 {
    if values.is_empty() {
        return f64::NAN;
    }
    values.sort_by(|left, right| left.partial_cmp(right).unwrap_or(Ordering::Equal));
    let position = quantile.clamp(0.0, 1.0) * (values.len() - 1) as f64;
    let lower = position.floor() as usize;
    let upper = position.ceil() as usize;
    if lower == upper {
        values[lower]
    } else {
        let weight = position - lower as f64;
        values[lower] * (1.0 - weight) + values[upper] * weight
    }
}

fn check_cancelled<C>(should_cancel: &mut C) -> Result<(), JobFailure>
where
    C: FnMut() -> bool,
{
    if should_cancel() {
        Err(failure(
            JobFailureReason::Cancelled,
            "evaluate_quality",
            "quality evaluation cancelled before completion",
        ))
    } else {
        Ok(())
    }
}

fn manifest_invalid(detail: impl Into<String>) -> JobFailure {
    failure(
        JobFailureReason::DatasetManifestInvalid,
        "validate_quality_manifest",
        detail,
    )
}

fn unsupported_detail(detail: impl Into<String>) -> JobFailure {
    failure(
        JobFailureReason::UnsupportedFormat,
        "read_quality_input",
        detail,
    )
}

fn unsupported(operation: &'static str, error: std::io::Error) -> JobFailure {
    failure(
        JobFailureReason::UnsupportedFormat,
        operation,
        format!("invalid or truncated WAV: {}", error.kind()),
    )
}

fn io_failure(operation: &'static str, error: std::io::Error) -> JobFailure {
    failure(
        JobFailureReason::IoFailure,
        operation,
        format!("filesystem operation failed: {}", error.kind()),
    )
}

fn failure(
    reason: JobFailureReason,
    operation: &'static str,
    detail: impl Into<String>,
) -> JobFailure {
    JobFailure::new(reason, operation, detail)
}
