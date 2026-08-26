mod decode;
#[cfg(not(target_family = "wasm"))]
mod file_job;
mod pipeline;
mod resample;
mod stft;

#[cfg(not(target_family = "wasm"))]
mod tract_backend;

pub use decode::{decode_audio_file, DecodedAudio};
pub use pipeline::{
    separate_waveform, MagnitudeModel, SeparationError, SeparationFailureReason,
    SeparationProgress, SeparationStage, StereoWaveform, WaveformSeparation,
};
pub use resample::resample_to_44k1;

#[cfg(not(target_family = "wasm"))]
pub use file_job::{
    separate_song_file, FileSeparationReport, FileSeparationRequest, StemFileMetadata,
};

#[cfg(not(target_family = "wasm"))]
pub use tract_backend::TractUmxHqModel;
