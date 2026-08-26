use serde::Serialize;
use sha2::{Digest, Sha256};
use std::fmt;
use std::fs::File;
use std::io::{self, BufReader, BufWriter, Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};

const PCM16_FORMAT: u16 = 1;
const SYNTHETIC_SAMPLE_RATE: u32 = 44_100;
const SYNTHETIC_CHANNELS: u16 = 2;

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum JobFailureReason {
    RightsAcknowledgementRequired,
    InputNotFound,
    UnsupportedFormat,
    ContractMismatch,
    Cancelled,
    IoFailure,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct JobFailure {
    pub reason: JobFailureReason,
    pub operation: &'static str,
    pub detail: String,
}

impl JobFailure {
    fn new(reason: JobFailureReason, operation: &'static str, detail: impl Into<String>) -> Self {
        Self {
            reason,
            operation,
            detail: detail.into(),
        }
    }
}

impl fmt::Display for JobFailure {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}: {}", self.operation, self.detail)
    }
}

impl std::error::Error for JobFailure {}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ProgressStage {
    ValidatingContract,
    HashingInputs,
    Completed,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
pub struct JobProgress {
    pub stage: ProgressStage,
    pub completed_units: u64,
    pub total_units: u64,
}

#[derive(Clone, Debug)]
pub struct ManualStemRequest {
    pub rights_acknowledged: bool,
    pub mixture: PathBuf,
    pub vocals: PathBuf,
    pub accompaniment: PathBuf,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct WavContract {
    pub sample_rate_hz: u32,
    pub channels: u16,
    pub bits_per_sample: u16,
    pub frame_count: u64,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct StemEvidence {
    pub role: &'static str,
    pub byte_length: u64,
    pub sha256: String,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct ManualStemReport {
    pub status: &'static str,
    pub evidence_type: &'static str,
    pub generated_by_model: bool,
    pub contract: WavContract,
    pub stems: Vec<StemEvidence>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
struct WavMetadata {
    contract: WavContract,
    data_length: u64,
}

pub fn validate_manual_stems<C, P>(
    request: &ManualStemRequest,
    mut should_cancel: C,
    mut on_progress: P,
) -> Result<ManualStemReport, JobFailure>
where
    C: FnMut() -> bool,
    P: FnMut(JobProgress),
{
    if !request.rights_acknowledged {
        return Err(JobFailure::new(
            JobFailureReason::RightsAcknowledgementRequired,
            "validate_rights",
            "explicit rights acknowledgement is required",
        ));
    }
    check_cancelled(&mut should_cancel)?;
    on_progress(JobProgress {
        stage: ProgressStage::ValidatingContract,
        completed_units: 0,
        total_units: 3,
    });

    let inputs = [
        ("mixture", &request.mixture),
        ("vocals", &request.vocals),
        ("accompaniment", &request.accompaniment),
    ];
    let mut metadata = Vec::with_capacity(inputs.len());
    for (index, (role, path)) in inputs.iter().enumerate() {
        check_cancelled(&mut should_cancel)?;
        metadata.push((*role, read_wav_metadata(path)?));
        on_progress(JobProgress {
            stage: ProgressStage::ValidatingContract,
            completed_units: (index + 1) as u64,
            total_units: inputs.len() as u64,
        });
    }

    let expected = metadata[0].1.contract.clone();
    for (role, item) in metadata.iter().skip(1) {
        if item.contract != expected {
            return Err(JobFailure::new(
                JobFailureReason::ContractMismatch,
                "validate_contract",
                format!("{role} WAV format or frame count differs from mixture"),
            ));
        }
    }
    let total_bytes = metadata.iter().map(|(_, item)| item.data_length).sum();
    let mut completed_bytes = 0_u64;
    let mut stems = Vec::with_capacity(inputs.len());
    for ((role, path), (_, item)) in inputs.iter().zip(&metadata) {
        check_cancelled(&mut should_cancel)?;
        let (sha256, byte_length) = hash_file(path, &mut should_cancel, |delta| {
            completed_bytes += delta;
            on_progress(JobProgress {
                stage: ProgressStage::HashingInputs,
                completed_units: completed_bytes.min(total_bytes),
                total_units: total_bytes,
            });
        })?;
        debug_assert_eq!(
            byte_length,
            std::fs::metadata(path).map(|m| m.len()).unwrap_or(0)
        );
        debug_assert!(item.data_length <= byte_length);
        stems.push(StemEvidence {
            role,
            byte_length,
            sha256,
        });
    }
    on_progress(JobProgress {
        stage: ProgressStage::Completed,
        completed_units: total_bytes,
        total_units: total_bytes,
    });
    Ok(ManualStemReport {
        status: "completed",
        evidence_type: "manual_stem_fallback",
        generated_by_model: false,
        contract: expected,
        stems,
    })
}

pub fn synthesize_fixture(output_dir: &Path) -> Result<[PathBuf; 3], JobFailure> {
    std::fs::create_dir_all(output_dir).map_err(|error| io_failure("create_fixture", error))?;
    let paths = [
        output_dir.join("mixture.wav"),
        output_dir.join("vocals.wav"),
        output_dir.join("accompaniment.wav"),
    ];
    let sample_count = SYNTHETIC_SAMPLE_RATE as usize;
    let vocals = generate_stereo_sine(sample_count, 220.0, 0.24);
    let accompaniment = generate_stereo_sine(sample_count, 330.0, 0.18);
    let mixture: Vec<i16> = vocals
        .iter()
        .zip(&accompaniment)
        .map(|(voice, backing)| i32::from(*voice).saturating_add(i32::from(*backing)) as i16)
        .collect();
    for (path, samples) in paths.iter().zip([&mixture, &vocals, &accompaniment]) {
        write_pcm16_wav(path, samples)?;
    }
    Ok(paths)
}

fn generate_stereo_sine(frame_count: usize, frequency_hz: f64, amplitude: f64) -> Vec<i16> {
    let mut samples = Vec::with_capacity(frame_count * usize::from(SYNTHETIC_CHANNELS));
    for frame in 0..frame_count {
        let phase =
            std::f64::consts::TAU * frequency_hz * frame as f64 / f64::from(SYNTHETIC_SAMPLE_RATE);
        let sample = (phase.sin() * amplitude * 32_768.0).round() as i16;
        samples.extend([sample, sample]);
    }
    samples
}

fn write_pcm16_wav(path: &Path, samples: &[i16]) -> Result<(), JobFailure> {
    let data_length = samples
        .len()
        .checked_mul(2)
        .and_then(|length| u32::try_from(length).ok())
        .ok_or_else(|| {
            JobFailure::new(
                JobFailureReason::IoFailure,
                "write_fixture",
                "fixture is too large for canonical WAV",
            )
        })?;
    let byte_rate = SYNTHETIC_SAMPLE_RATE * u32::from(SYNTHETIC_CHANNELS) * 2;
    let mut writer =
        BufWriter::new(File::create(path).map_err(|error| io_failure("write_fixture", error))?);
    writer
        .write_all(b"RIFF")
        .and_then(|_| writer.write_all(&(36 + data_length).to_le_bytes()))
        .and_then(|_| writer.write_all(b"WAVEfmt "))
        .and_then(|_| writer.write_all(&16_u32.to_le_bytes()))
        .and_then(|_| writer.write_all(&PCM16_FORMAT.to_le_bytes()))
        .and_then(|_| writer.write_all(&SYNTHETIC_CHANNELS.to_le_bytes()))
        .and_then(|_| writer.write_all(&SYNTHETIC_SAMPLE_RATE.to_le_bytes()))
        .and_then(|_| writer.write_all(&byte_rate.to_le_bytes()))
        .and_then(|_| writer.write_all(&(SYNTHETIC_CHANNELS * 2).to_le_bytes()))
        .and_then(|_| writer.write_all(&16_u16.to_le_bytes()))
        .and_then(|_| writer.write_all(b"data"))
        .and_then(|_| writer.write_all(&data_length.to_le_bytes()))
        .map_err(|error| io_failure("write_fixture", error))?;
    for sample in samples {
        writer
            .write_all(&sample.to_le_bytes())
            .map_err(|error| io_failure("write_fixture", error))?;
    }
    writer
        .flush()
        .map_err(|error| io_failure("write_fixture", error))
}

fn read_wav_metadata(path: &Path) -> Result<WavMetadata, JobFailure> {
    if !path.is_file() {
        return Err(JobFailure::new(
            JobFailureReason::InputNotFound,
            "open_input",
            "one required input file does not exist",
        ));
    }
    let file = File::open(path).map_err(|error| io_failure("open_input", error))?;
    let file_length = file
        .metadata()
        .map_err(|error| io_failure("open_input", error))?
        .len();
    let mut reader = BufReader::new(file);
    let mut riff = [0_u8; 12];
    reader
        .read_exact(&mut riff)
        .map_err(|error| unsupported("read_header", error))?;
    if &riff[0..4] != b"RIFF" || &riff[8..12] != b"WAVE" {
        return Err(JobFailure::new(
            JobFailureReason::UnsupportedFormat,
            "read_header",
            "input is not a RIFF/WAVE file",
        ));
    }
    let mut format = None;
    let mut data_length = None;
    loop {
        let mut chunk_header = [0_u8; 8];
        if reader.read_exact(&mut chunk_header).is_err() {
            break;
        }
        let chunk_size = u32::from_le_bytes(chunk_header[4..8].try_into().expect("four bytes"));
        match &chunk_header[0..4] {
            b"fmt " => {
                if chunk_size < 16 {
                    return Err(JobFailure::new(
                        JobFailureReason::UnsupportedFormat,
                        "read_header",
                        "WAV fmt chunk is shorter than 16 bytes",
                    ));
                }
                let mut fields = [0_u8; 16];
                reader
                    .read_exact(&mut fields)
                    .map_err(|error| unsupported("read_header", error))?;
                format = Some((
                    u16::from_le_bytes(fields[0..2].try_into().expect("two bytes")),
                    u16::from_le_bytes(fields[2..4].try_into().expect("two bytes")),
                    u32::from_le_bytes(fields[4..8].try_into().expect("four bytes")),
                    u16::from_le_bytes(fields[14..16].try_into().expect("two bytes")),
                ));
                reader
                    .seek(SeekFrom::Current(i64::from(chunk_size - 16)))
                    .map_err(|error| unsupported("read_header", error))?;
            }
            b"data" => {
                let data_offset = reader
                    .stream_position()
                    .map_err(|error| unsupported("read_header", error))?;
                if data_offset.saturating_add(u64::from(chunk_size)) > file_length {
                    return Err(JobFailure::new(
                        JobFailureReason::UnsupportedFormat,
                        "read_header",
                        "WAV data chunk extends beyond the end of the file",
                    ));
                }
                data_length = Some(u64::from(chunk_size));
                reader
                    .seek(SeekFrom::Current(i64::from(chunk_size)))
                    .map_err(|error| unsupported("read_header", error))?;
            }
            _ => {
                reader
                    .seek(SeekFrom::Current(i64::from(chunk_size)))
                    .map_err(|error| unsupported("read_header", error))?;
            }
        }
        if chunk_size % 2 == 1 {
            reader
                .seek(SeekFrom::Current(1))
                .map_err(|error| unsupported("read_header", error))?;
        }
        if format.is_some() && data_length.is_some() {
            break;
        }
    }
    let Some((audio_format, channels, sample_rate_hz, bits_per_sample)) = format else {
        return Err(JobFailure::new(
            JobFailureReason::UnsupportedFormat,
            "read_header",
            "WAV fmt chunk is missing",
        ));
    };
    let Some(data_length) = data_length else {
        return Err(JobFailure::new(
            JobFailureReason::UnsupportedFormat,
            "read_header",
            "WAV data chunk is missing",
        ));
    };
    if audio_format != PCM16_FORMAT || bits_per_sample != 16 || channels == 0 {
        return Err(JobFailure::new(
            JobFailureReason::UnsupportedFormat,
            "read_header",
            "only interleaved PCM16 WAV with at least one channel is supported",
        ));
    }
    let bytes_per_frame = u64::from(channels) * 2;
    if data_length % bytes_per_frame != 0 {
        return Err(JobFailure::new(
            JobFailureReason::UnsupportedFormat,
            "read_header",
            "WAV data length is not a complete PCM frame count",
        ));
    }
    Ok(WavMetadata {
        contract: WavContract {
            sample_rate_hz,
            channels,
            bits_per_sample,
            frame_count: data_length / bytes_per_frame,
        },
        data_length,
    })
}

fn hash_file<C, P>(
    path: &Path,
    should_cancel: &mut C,
    mut on_bytes: P,
) -> Result<(String, u64), JobFailure>
where
    C: FnMut() -> bool,
    P: FnMut(u64),
{
    let mut reader =
        BufReader::new(File::open(path).map_err(|error| io_failure("hash_input", error))?);
    let mut hasher = Sha256::new();
    let mut buffer = [0_u8; 64 * 1024];
    let mut byte_length = 0_u64;
    loop {
        check_cancelled(should_cancel)?;
        let count = reader
            .read(&mut buffer)
            .map_err(|error| io_failure("hash_input", error))?;
        if count == 0 {
            break;
        }
        hasher.update(&buffer[..count]);
        let delta = count as u64;
        byte_length += delta;
        on_bytes(delta);
    }
    Ok((format!("{:x}", hasher.finalize()), byte_length))
}

fn check_cancelled<C>(should_cancel: &mut C) -> Result<(), JobFailure>
where
    C: FnMut() -> bool,
{
    if should_cancel() {
        Err(JobFailure::new(
            JobFailureReason::Cancelled,
            "run_job",
            "job cancelled before completion",
        ))
    } else {
        Ok(())
    }
}

fn unsupported(operation: &'static str, error: io::Error) -> JobFailure {
    JobFailure::new(
        JobFailureReason::UnsupportedFormat,
        operation,
        format!("invalid or truncated WAV: {}", error.kind()),
    )
}

fn io_failure(operation: &'static str, error: io::Error) -> JobFailure {
    JobFailure::new(
        JobFailureReason::IoFailure,
        operation,
        format!("filesystem operation failed: {}", error.kind()),
    )
}
