use super::{
    decode_audio_file,
    pipeline::{
        separate_waveform, MagnitudeModel, SeparationError, SeparationFailureReason,
        SeparationProgress, SeparationStage, StereoWaveform,
    },
    tract_backend::TractUmxHqModel,
};
use sha2::{Digest, Sha256};
use std::fs::{self, File};
use std::io::{BufReader, BufWriter, Read, Write};
use std::path::{Path, PathBuf};

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct FileSeparationRequest {
    pub rights_acknowledged: bool,
    pub input_path: PathBuf,
    pub model_path: PathBuf,
    pub expected_model_sha256: String,
    pub output_directory: PathBuf,
    pub job_id: String,
    pub cancel_marker: PathBuf,
    pub maximum_decoded_frames: u64,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct StemFileMetadata {
    pub path: PathBuf,
    pub sha256: String,
    pub byte_length: u64,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct FileSeparationReport {
    pub model_id: String,
    pub algorithm_version: String,
    pub source_sample_rate: u32,
    pub source_channels: u16,
    pub output_sample_rate: u32,
    pub output_channels: u16,
    pub output_frames: u64,
    pub chunk_count: u32,
    pub vocals: StemFileMetadata,
    pub accompaniment: StemFileMetadata,
}

pub fn separate_song_file<P>(
    request: &FileSeparationRequest,
    on_progress: P,
) -> Result<FileSeparationReport, SeparationError>
where
    P: FnMut(SeparationProgress),
{
    if !request.rights_acknowledged {
        return Err(SeparationError::new(
            SeparationFailureReason::RightsAcknowledgementRequired,
            "validate_song_rights",
            "explicit local-processing rights acknowledgement is required",
        ));
    }
    validate_job_id(&request.job_id)?;
    if request.cancel_marker.exists() {
        return Err(SeparationError::cancelled("prepare_song_job"));
    }
    let model = TractUmxHqModel::load(&request.model_path, &request.expected_model_sha256)?;
    run_file_job_with_model(request, model, on_progress)
}

fn run_file_job_with_model<M, P>(
    request: &FileSeparationRequest,
    mut model: M,
    mut on_progress: P,
) -> Result<FileSeparationReport, SeparationError>
where
    M: MagnitudeModel,
    P: FnMut(SeparationProgress),
{
    let is_cancelled = || request.cancel_marker.exists();
    on_progress(SeparationProgress::fraction(
        SeparationStage::Decoding,
        0,
        1,
    ));
    let decoded = decode_audio_file(
        &request.input_path,
        request.maximum_decoded_frames,
        is_cancelled,
    )?;
    on_progress(SeparationProgress::fraction(
        SeparationStage::Decoding,
        1,
        1,
    ));
    let separation = separate_waveform(
        &decoded.waveform,
        &mut model,
        is_cancelled,
        &mut on_progress,
    )?;
    if is_cancelled() {
        return Err(SeparationError::cancelled("write_song_stems"));
    }
    fs::create_dir_all(&request.output_directory).map_err(|error| {
        SeparationError::io(
            "create_stem_directory",
            "the stem output directory could not be created",
            error,
        )
    })?;
    let vocals_path = request
        .output_directory
        .join(format!("{}-vocals.wav", request.job_id));
    let accompaniment_path = request
        .output_directory
        .join(format!("{}-accompaniment.wav", request.job_id));
    let vocals_partial = partial_path(&vocals_path);
    let accompaniment_partial = partial_path(&accompaniment_path);
    let write_result = write_outputs(
        &separation.vocals,
        &separation.accompaniment,
        &vocals_partial,
        &accompaniment_partial,
        is_cancelled,
        &mut on_progress,
    );
    if let Err(error) = write_result {
        remove_if_present(&vocals_partial);
        remove_if_present(&accompaniment_partial);
        return Err(error);
    }
    if is_cancelled() {
        remove_if_present(&vocals_partial);
        remove_if_present(&accompaniment_partial);
        return Err(SeparationError::cancelled("commit_song_stems"));
    }
    if vocals_path.exists() || accompaniment_path.exists() {
        remove_if_present(&vocals_partial);
        remove_if_present(&accompaniment_partial);
        return Err(SeparationError::new(
            SeparationFailureReason::IoFailure,
            "commit_song_stems",
            "a completed stem file already exists for this job id",
        ));
    }
    fs::rename(&vocals_partial, &vocals_path).map_err(|error| {
        remove_if_present(&vocals_partial);
        remove_if_present(&accompaniment_partial);
        SeparationError::io(
            "commit_song_stems",
            "the vocals stem could not be atomically committed",
            error,
        )
    })?;
    if let Err(error) = fs::rename(&accompaniment_partial, &accompaniment_path) {
        remove_if_present(&vocals_path);
        remove_if_present(&accompaniment_partial);
        return Err(SeparationError::io(
            "commit_song_stems",
            "the accompaniment stem could not be atomically committed",
            error,
        ));
    }
    let result = (|| {
        Ok(FileSeparationReport {
            model_id: separation.model_id,
            algorithm_version: separation.algorithm_version.to_owned(),
            source_sample_rate: decoded.source_sample_rate,
            source_channels: decoded.source_channels,
            output_sample_rate: separation.vocals.sample_rate,
            output_channels: 2,
            output_frames: separation.vocals.frame_count() as u64,
            chunk_count: separation.chunk_count.try_into().unwrap_or(u32::MAX),
            vocals: stem_metadata(&vocals_path)?,
            accompaniment: stem_metadata(&accompaniment_path)?,
        })
    })();
    if result.is_err() {
        remove_if_present(&vocals_path);
        remove_if_present(&accompaniment_path);
    }
    on_progress(SeparationProgress::fraction(
        SeparationStage::Completed,
        1,
        1,
    ));
    result
}

fn write_outputs<C, P>(
    vocals: &StereoWaveform,
    accompaniment: &StereoWaveform,
    vocals_partial: &Path,
    accompaniment_partial: &Path,
    mut should_cancel: C,
    on_progress: &mut P,
) -> Result<(), SeparationError>
where
    C: FnMut() -> bool,
    P: FnMut(SeparationProgress),
{
    if vocals.sample_rate != accompaniment.sample_rate
        || vocals.frame_count() != accompaniment.frame_count()
    {
        return Err(SeparationError::new(
            SeparationFailureReason::ContractMismatch,
            "write_song_stems",
            "vocals and accompaniment output contracts differ",
        ));
    }
    on_progress(SeparationProgress::fraction(SeparationStage::Writing, 0, 2));
    write_pcm16_wav(vocals_partial, vocals, &mut should_cancel)?;
    on_progress(SeparationProgress::fraction(SeparationStage::Writing, 1, 2));
    write_pcm16_wav(accompaniment_partial, accompaniment, &mut should_cancel)?;
    on_progress(SeparationProgress::fraction(SeparationStage::Writing, 2, 2));
    Ok(())
}

fn write_pcm16_wav<C>(
    path: &Path,
    waveform: &StereoWaveform,
    should_cancel: &mut C,
) -> Result<(), SeparationError>
where
    C: FnMut() -> bool,
{
    let data_length = waveform
        .samples
        .len()
        .checked_mul(2)
        .and_then(|length| u32::try_from(length).ok())
        .ok_or_else(|| {
            SeparationError::new(
                SeparationFailureReason::ContractMismatch,
                "write_song_stems",
                "a stem exceeds the canonical RIFF/WAV size limit",
            )
        })?;
    let mut writer = BufWriter::new(File::create(path).map_err(|error| {
        SeparationError::io(
            "write_song_stems",
            "a partial stem could not be created",
            error,
        )
    })?);
    let byte_rate = waveform.sample_rate * 4;
    writer
        .write_all(b"RIFF")
        .and_then(|_| writer.write_all(&(36 + data_length).to_le_bytes()))
        .and_then(|_| writer.write_all(b"WAVEfmt "))
        .and_then(|_| writer.write_all(&16_u32.to_le_bytes()))
        .and_then(|_| writer.write_all(&1_u16.to_le_bytes()))
        .and_then(|_| writer.write_all(&2_u16.to_le_bytes()))
        .and_then(|_| writer.write_all(&waveform.sample_rate.to_le_bytes()))
        .and_then(|_| writer.write_all(&byte_rate.to_le_bytes()))
        .and_then(|_| writer.write_all(&4_u16.to_le_bytes()))
        .and_then(|_| writer.write_all(&16_u16.to_le_bytes()))
        .and_then(|_| writer.write_all(b"data"))
        .and_then(|_| writer.write_all(&data_length.to_le_bytes()))
        .map_err(|error| {
            SeparationError::io(
                "write_song_stems",
                "a partial stem header could not be written",
                error,
            )
        })?;
    for (index, sample) in waveform.samples.iter().copied().enumerate() {
        if index % (64 * 1024) == 0 && should_cancel() {
            return Err(SeparationError::cancelled("write_song_stems"));
        }
        let pcm = (sample.clamp(-1.0, 1.0 - 1.0 / 32_768.0) * 32_768.0).round() as i16;
        writer.write_all(&pcm.to_le_bytes()).map_err(|error| {
            SeparationError::io(
                "write_song_stems",
                "partial stem samples could not be written",
                error,
            )
        })?;
    }
    writer.flush().map_err(|error| {
        SeparationError::io(
            "write_song_stems",
            "a partial stem could not be flushed",
            error,
        )
    })?;
    writer.get_ref().sync_all().map_err(|error| {
        SeparationError::io(
            "write_song_stems",
            "a partial stem could not be synchronized",
            error,
        )
    })
}

fn stem_metadata(path: &Path) -> Result<StemFileMetadata, SeparationError> {
    let byte_length = path
        .metadata()
        .map_err(|error| {
            SeparationError::io(
                "verify_song_stem",
                "a committed stem could not be inspected",
                error,
            )
        })?
        .len();
    Ok(StemFileMetadata {
        path: path.to_path_buf(),
        sha256: hash_file(path)?,
        byte_length,
    })
}

fn hash_file(path: &Path) -> Result<String, SeparationError> {
    let mut reader = BufReader::new(File::open(path).map_err(|error| {
        SeparationError::io(
            "hash_song_stem",
            "a committed stem could not be opened",
            error,
        )
    })?);
    let mut hasher = Sha256::new();
    let mut buffer = [0_u8; 64 * 1024];
    loop {
        let count = reader.read(&mut buffer).map_err(|error| {
            SeparationError::io(
                "hash_song_stem",
                "a committed stem could not be read",
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

fn validate_job_id(job_id: &str) -> Result<(), SeparationError> {
    if job_id.is_empty()
        || job_id.len() > 80
        || !job_id
            .bytes()
            .all(|value| value.is_ascii_alphanumeric() || matches!(value, b'-' | b'_'))
    {
        return Err(SeparationError::new(
            SeparationFailureReason::ContractMismatch,
            "validate_song_job",
            "job id must contain only ASCII letters, digits, hyphen, or underscore",
        ));
    }
    Ok(())
}

fn partial_path(final_path: &Path) -> PathBuf {
    let mut value = final_path.as_os_str().to_owned();
    value.push(".partial");
    PathBuf::from(value)
}

fn remove_if_present(path: &Path) {
    if path.is_file() {
        let _ = fs::remove_file(path);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU64, Ordering};

    static NEXT_DIRECTORY: AtomicU64 = AtomicU64::new(0);

    struct IdentityModel;

    impl MagnitudeModel for IdentityModel {
        fn model_id(&self) -> &str {
            "identity-test-only"
        }

        fn infer(&mut self, input: &[f32], _frames: usize) -> Result<Vec<f32>, SeparationError> {
            Ok(input.to_vec())
        }
    }

    #[test]
    fn file_job_commits_two_hashed_stems_without_partials() {
        let directory = temporary_directory("commit");
        let input_path = directory.join("input.wav");
        let waveform = fixture();
        write_pcm16_wav(&input_path, &waveform, &mut || false).expect("write input fixture");
        let request = request(&directory, &input_path, "commit-job");
        let report = run_file_job_with_model(&request, IdentityModel, |_| {})
            .expect("file job should complete");
        assert_eq!(report.output_frames, waveform.frame_count() as u64);
        assert_eq!(report.vocals.sha256.len(), 64);
        assert_eq!(report.accompaniment.sha256.len(), 64);
        assert!(report.vocals.path.is_file());
        assert!(report.accompaniment.path.is_file());
        assert!(!partial_path(&report.vocals.path).exists());
        assert!(!partial_path(&report.accompaniment.path).exists());
        fs::remove_dir_all(directory).expect("remove temporary directory");
    }

    #[test]
    fn cancellation_removes_partial_outputs() {
        let directory = temporary_directory("cancel");
        let input_path = directory.join("input.wav");
        write_pcm16_wav(&input_path, &fixture(), &mut || false).expect("write input fixture");
        let request = request(&directory, &input_path, "cancel-job");
        fs::write(&request.cancel_marker, b"cancel").expect("write cancel marker");
        let failure = run_file_job_with_model(&request, IdentityModel, |_| {})
            .expect_err("cancelled file job must fail");
        assert_eq!(failure.reason, SeparationFailureReason::Cancelled);
        assert!(!directory.join("cancel-job-vocals.wav.partial").exists());
        assert!(!directory
            .join("cancel-job-accompaniment.wav.partial")
            .exists());
        fs::remove_dir_all(directory).expect("remove temporary directory");
    }

    #[test]
    fn invalid_job_id_cannot_escape_output_directory() {
        let directory = temporary_directory("job-id");
        let input_path = directory.join("input.wav");
        let mut request = request(&directory, &input_path, "safe");
        request.job_id = "../escape".to_owned();
        let failure = validate_job_id(&request.job_id).expect_err("traversal must fail");
        assert_eq!(failure.reason, SeparationFailureReason::ContractMismatch);
        fs::remove_dir_all(directory).expect("remove temporary directory");
    }

    #[test]
    fn decoded_frame_limit_fails_before_waveform_processing() {
        let directory = temporary_directory("frame-limit");
        let input_path = directory.join("input.wav");
        write_pcm16_wav(&input_path, &fixture(), &mut || false).expect("write input fixture");
        let mut request = request(&directory, &input_path, "limited-job");
        request.maximum_decoded_frames = 128;
        let failure = run_file_job_with_model(&request, IdentityModel, |_| {})
            .expect_err("oversized decoded input must fail");
        assert_eq!(
            failure.reason,
            SeparationFailureReason::ResourceLimitExceeded
        );
        assert!(!directory.join("limited-job-vocals.wav").exists());
        fs::remove_dir_all(directory).expect("remove temporary directory");
    }

    fn request(directory: &Path, input_path: &Path, job_id: &str) -> FileSeparationRequest {
        FileSeparationRequest {
            rights_acknowledged: true,
            input_path: input_path.to_path_buf(),
            model_path: directory.join("unused.onnx"),
            expected_model_sha256: "unused".to_owned(),
            output_directory: directory.to_path_buf(),
            job_id: job_id.to_owned(),
            cancel_marker: directory.join("cancel.marker"),
            maximum_decoded_frames: 44_100 * 60 * 5,
        }
    }

    fn fixture() -> StereoWaveform {
        StereoWaveform::new(
            44_100,
            (0..4096)
                .flat_map(|index| {
                    let sample =
                        0.2 * (std::f32::consts::TAU * 220.0 * index as f32 / 44_100.0).sin();
                    [sample, sample]
                })
                .collect(),
        )
        .expect("valid fixture")
    }

    fn temporary_directory(label: &str) -> PathBuf {
        let id = NEXT_DIRECTORY.fetch_add(1, Ordering::Relaxed);
        let path = std::env::temp_dir().join(format!(
            "voice-trainer-srd04-{}-{label}-{id}",
            std::process::id()
        ));
        fs::create_dir_all(&path).expect("create temporary directory");
        path
    }
}
