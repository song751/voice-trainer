use super::pipeline::{
    SeparationError, SeparationProgress, SeparationStage, StereoWaveform, TARGET_SAMPLE_RATE,
};

const SINC_RADIUS: isize = 24;

pub fn resample_to_44k1<C, P>(
    input: &StereoWaveform,
    should_cancel: &mut C,
    on_progress: &mut P,
) -> Result<StereoWaveform, SeparationError>
where
    C: FnMut() -> bool,
    P: FnMut(SeparationProgress),
{
    if input.sample_rate == TARGET_SAMPLE_RATE {
        return Ok(input.clone());
    }
    let source_frames = input.frame_count();
    let output_frames = ((source_frames as u128 * u128::from(TARGET_SAMPLE_RATE)
        + u128::from(input.sample_rate / 2))
        / u128::from(input.sample_rate)) as usize;
    let ratio = f64::from(input.sample_rate) / f64::from(TARGET_SAMPLE_RATE);
    let cutoff = (f64::from(TARGET_SAMPLE_RATE) / f64::from(input.sample_rate)).min(1.0);
    let mut output = Vec::with_capacity(output_frames.saturating_mul(2));
    for output_index in 0..output_frames {
        if output_index % 4096 == 0 {
            if should_cancel() {
                return Err(SeparationError::cancelled("resample_song"));
            }
            on_progress(SeparationProgress::fraction(
                SeparationStage::Resampling,
                output_index,
                output_frames,
            ));
        }
        let source_position = output_index as f64 * ratio;
        let center = source_position.floor() as isize;
        let mut values = [0.0_f64; 2];
        let mut weight_sum = 0.0_f64;
        for offset in -SINC_RADIUS + 1..=SINC_RADIUS {
            let source_index = center + offset;
            if source_index < 0 || source_index >= source_frames as isize {
                continue;
            }
            let distance = source_position - source_index as f64;
            let window = if distance.abs() < SINC_RADIUS as f64 {
                0.5 + 0.5 * (std::f64::consts::PI * distance / SINC_RADIUS as f64).cos()
            } else {
                0.0
            };
            let argument = cutoff * distance;
            let sinc = if argument.abs() < 1.0e-12 {
                1.0
            } else {
                (std::f64::consts::PI * argument).sin() / (std::f64::consts::PI * argument)
            };
            let weight = cutoff * sinc * window;
            let base = source_index as usize * 2;
            values[0] += f64::from(input.samples[base]) * weight;
            values[1] += f64::from(input.samples[base + 1]) * weight;
            weight_sum += weight;
        }
        let normalization = if weight_sum.abs() > 1.0e-12 {
            weight_sum
        } else {
            1.0
        };
        output.push((values[0] / normalization) as f32);
        output.push((values[1] / normalization) as f32);
    }
    on_progress(SeparationProgress::fraction(
        SeparationStage::Resampling,
        output_frames,
        output_frames,
    ));
    StereoWaveform::new(TARGET_SAMPLE_RATE, output)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resampler_preserves_duration_and_stereo_contract() {
        let samples: Vec<f32> = (0..48_000)
            .flat_map(|index| {
                let sample = (std::f32::consts::TAU * 440.0 * index as f32 / 48_000.0).sin();
                [sample, -sample]
            })
            .collect();
        let input = StereoWaveform::new(48_000, samples).expect("valid stereo input");
        let output = resample_to_44k1(&input, &mut || false, &mut |_| {})
            .expect("resampling should complete");
        assert_eq!(output.sample_rate, 44_100);
        assert_eq!(output.frame_count(), 44_100);
        assert_eq!(output.samples.len(), 88_200);
        assert!(output.samples.iter().all(|sample| sample.is_finite()));
    }
}
