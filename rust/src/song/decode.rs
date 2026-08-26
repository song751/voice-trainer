use super::pipeline::{SeparationError, SeparationFailureReason, StereoWaveform};
use std::path::Path;
use std::{fs::File, io::Cursor};
use symphonia::core::{
    audio::SampleBuffer,
    codecs::DecoderOptions,
    errors::Error as SymphoniaError,
    formats::FormatOptions,
    io::{MediaSource, MediaSourceStream, MediaSourceStreamOptions},
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
    maximum_decoded_frames: u64,
    should_cancel: C,
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
    let mut hint = Hint::new();
    if let Some(extension) = path.extension().and_then(|value| value.to_str()) {
        hint.with_extension(extension);
    }
    decode_audio_source(Box::new(file), hint, maximum_decoded_frames, should_cancel)
}

pub fn decode_audio_bytes<C>(
    bytes: Vec<u8>,
    maximum_decoded_frames: u64,
    should_cancel: C,
) -> Result<DecodedAudio, SeparationError>
where
    C: FnMut() -> bool,
{
    let mut hint = Hint::new();
    hint.with_extension("wav");
    decode_audio_source(
        Box::new(Cursor::new(bytes)),
        hint,
        maximum_decoded_frames,
        should_cancel,
    )
}

fn decode_audio_source<C>(
    source: Box<dyn MediaSource>,
    hint: Hint,
    maximum_decoded_frames: u64,
    mut should_cancel: C,
) -> Result<DecodedAudio, SeparationError>
where
    C: FnMut() -> bool,
{
    let stream = MediaSourceStream::new(source, MediaSourceStreamOptions::default());
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
        let decoded_frames = interleaved.len() / source_channels;
        let next_frames = decoded_frames.saturating_add(buffer.samples().len() / source_channels);
        if next_frames as u64 > maximum_decoded_frames {
            return Err(SeparationError::new(
                SeparationFailureReason::ResourceLimitExceeded,
                "decode_song",
                "the decoded song exceeds this platform's configured frame limit",
            ));
        }
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

#[cfg(test)]
mod tests {
    use super::decode_audio_bytes;

    #[test]
    fn verified_wav_bytes_decode_without_a_pathname() {
        let samples = [0_i16, 8_192, -8_192, 16_384];
        let data_length = (samples.len() * std::mem::size_of::<i16>()) as u32;
        let mut wav = Vec::with_capacity(44 + data_length as usize);
        wav.extend_from_slice(b"RIFF");
        wav.extend_from_slice(&(36 + data_length).to_le_bytes());
        wav.extend_from_slice(b"WAVEfmt ");
        wav.extend_from_slice(&16_u32.to_le_bytes());
        wav.extend_from_slice(&1_u16.to_le_bytes());
        wav.extend_from_slice(&1_u16.to_le_bytes());
        wav.extend_from_slice(&44_100_u32.to_le_bytes());
        wav.extend_from_slice(&(44_100_u32 * 2).to_le_bytes());
        wav.extend_from_slice(&2_u16.to_le_bytes());
        wav.extend_from_slice(&16_u16.to_le_bytes());
        wav.extend_from_slice(b"data");
        wav.extend_from_slice(&data_length.to_le_bytes());
        for sample in samples {
            wav.extend_from_slice(&sample.to_le_bytes());
        }

        let decoded = decode_audio_bytes(wav, 4, || false).expect("valid in-memory WAV");
        assert_eq!(decoded.source_sample_rate, 44_100);
        assert_eq!(decoded.source_channels, 1);
        assert_eq!(decoded.waveform.frame_count(), 4);
    }
}
