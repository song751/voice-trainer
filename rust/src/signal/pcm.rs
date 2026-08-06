//! Canonical signed little-endian PCM16 conversion.

pub const PCM16_SCALE: f32 = 32_768.0;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PcmError {
    OddByteCount { byte_count: usize },
}

pub fn pcm16_to_f32(sample: i16) -> f32 {
    sample as f32 / PCM16_SCALE
}

pub fn pcm16le_bytes_to_f32(bytes: &[u8]) -> Result<Vec<f32>, PcmError> {
    if !bytes.len().is_multiple_of(2) {
        return Err(PcmError::OddByteCount {
            byte_count: bytes.len(),
        });
    }
    let mut samples = Vec::with_capacity(bytes.len() / 2);
    for pair in bytes.chunks_exact(2) {
        samples.push(pcm16_to_f32(i16::from_le_bytes([pair[0], pair[1]])));
    }
    Ok(samples)
}

pub fn pcm16_to_f32_into(input: &[i16], output: &mut Vec<f32>) {
    output.extend(input.iter().copied().map(pcm16_to_f32));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn conversion_uses_the_documented_half_open_range() {
        assert_eq!(pcm16_to_f32(i16::MIN), -1.0);
        assert_eq!(pcm16_to_f32(0), 0.0);
        assert_eq!(pcm16_to_f32(i16::MAX), 1.0 - 1.0 / PCM16_SCALE);
    }

    #[test]
    fn little_endian_bytes_are_validated_and_converted() {
        assert_eq!(pcm16le_bytes_to_f32(&[0, 0, 0, 128]), Ok(vec![0.0, -1.0]));
        assert_eq!(
            pcm16le_bytes_to_f32(&[0]),
            Err(PcmError::OddByteCount { byte_count: 1 })
        );
    }
}
