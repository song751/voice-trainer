use super::pipeline::{SeparationError, SeparationFailureReason, StereoWaveform};
use std::fs::File;
use std::path::Path;
use symphonia::core::{
    audio::SampleBuffer,
    codecs::DecoderOptions,
    errors::Error as SymphoniaError,
    formats::FormatOptions,
    io::{MediaSourceStream, MediaSourceStreamOptions},
    meta::MetadataOptions,
    probe::Hint,
};

#[derive(Clone, Debug, PartialEq)]
pub struct DecodedAudio {
    pub waveform: StereoWaveform,
    pub source_sample_rate: u32,
    pub source_channels: u16,
}

pub fn decode_audio_file<C>(
    path: &Path,
    mut should_cancel: C,
) -> Result<DecodedAudio, SeparationError>
where
    C: FnMut() -> bool,
{
    if !path.is_file() {
        return Err(SeparationError::new(
            SeparationFailureReason::InputNotFound,
            "open_song",
            "the selected song file does not exist",
        ));
    }
    let file = File::open(path).map_err(|error| {
        SeparationError::io("open_song", "the selected song could not be opened", error)
    })?;
    let stream = MediaSourceStream::new(Box::new(file), MediaSourceStreamOptions::default());
    let mut hint = Hint::new();
    if let Some(extension) = path.extension().and_then(|value| value.to_str()) {
        hint.with_extension(extension);
    }
    let probed = symphonia::default::get_probe()
        .format(
            &hint,
            stream,
            &FormatOptions::default(),
            &MetadataOptions::default(),
        )
        .map_err(|_| unsupported("the selected container is not supported"))?;
    let mut format = probed.format;
    let track = format
        .default_track()
        .or_else(|| {
            format
                .tracks()
                .iter()
                .find(|track| track.codec_params.sample_rate.is_some())
        })
        .ok_or_else(|| unsupported("the selected file has no decodable audio track"))?;
    let track_id = track.id;
    let source_sample_rate = track
        .codec_params
        .sample_rate
        .ok_or_else(|| unsupported("the song sample rate is not declared"))?;
    let source_channels = track
        .codec_params
        .channels
        .map(|channels| channels.count())
        .ok_or_else(|| unsupported("the song channel layout is not declared"))?;
    if !(1..=2).contains(&source_channels) {
        return Err(unsupported("only mono and stereo songs are supported"));
    }
    let mut decoder = symphonia::default::get_codecs()
        .make(&track.codec_params, &DecoderOptions::default())
        .map_err(|_| unsupported("the song codec is not enabled in this build"))?;
    let mut interleaved = Vec::new();
    loop {
        check_cancelled(&mut should_cancel)?;
        let packet = match format.next_packet() {
            Ok(packet) => packet,
            Err(SymphoniaError::IoError(error))
                if error.kind() == std::io::ErrorKind::UnexpectedEof =>
            {
                break;
            }
            Err(_) => {
                return Err(SeparationError::new(
                    SeparationFailureReason::DecodeFailed,
                    "read_song_packet",
                    "the song container could not be read",
                ));
            }
        };
        if packet.track_id() != track_id {
            continue;
        }
        let decoded = match decoder.decode(&packet) {
            Ok(decoded) => decoded,
            Err(SymphoniaError::DecodeError(_)) => continue,
            Err(_) => {
                return Err(SeparationError::new(
                    SeparationFailureReason::DecodeFailed,
                    "decode_song_packet",
                    "the song codec failed while decoding",
                ));
            }
        };
        let specification = *decoded.spec();
        if specification.rate != source_sample_rate
            || specification.channels.count() != source_channels
        {
            return Err(SeparationError::new(
                SeparationFailureReason::FormatChanged,
                "decode_song_packet",
                "the song format changed during decoding",
            ));
        }
        let mut buffer = SampleBuffer::<f32>::new(decoded.capacity() as u64, specification);
        buffer.copy_interleaved_ref(decoded);
        interleaved.extend_from_slice(buffer.samples());
    }
    if interleaved.is_empty() {
        return Err(unsupported("the selected song contains no audio samples"));
    }
    let stereo = if source_channels == 1 {
        let mut output = Vec::with_capacity(interleaved.len() * 2);
        for sample in interleaved {
            output.extend([sample, sample]);
        }
        output
    } else {
        interleaved
    };
    let waveform = StereoWaveform::new(source_sample_rate, stereo)?;
    Ok(DecodedAudio {
        waveform,
        source_sample_rate,
        source_channels: source_channels as u16,
    })
}

fn unsupported(detail: &'static str) -> SeparationError {
    SeparationError::new(
        SeparationFailureReason::UnsupportedFormat,
        "decode_song",
        detail,
    )
}

fn check_cancelled<C>(should_cancel: &mut C) -> Result<(), SeparationError>
where
    C: FnMut() -> bool,
{
    if should_cancel() {
        Err(SeparationError::cancelled("decode_song"))
    } else {
        Ok(())
    }
}
