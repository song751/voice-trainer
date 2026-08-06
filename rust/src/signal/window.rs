//! Window functions used by future frame-based DSP stages.

pub fn periodic_hann(length: usize) -> Vec<f32> {
    assert!(length > 0, "window length must be positive");
    (0..length)
        .map(|index| 0.5 - 0.5 * (std::f32::consts::TAU * index as f32 / length as f32).cos())
        .collect()
}

pub fn apply_window(input: &[f32], window: &[f32], output: &mut [f32]) {
    assert_eq!(input.len(), window.len(), "window must match input length");
    assert_eq!(input.len(), output.len(), "output must match input length");
    for ((sample, coefficient), target) in input.iter().zip(window).zip(output.iter_mut()) {
        *target = sample * coefficient;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn periodic_hann_has_expected_quarter_points() {
        assert_eq!(periodic_hann(4), vec![0.0, 0.5, 1.0, 0.5]);
    }

    #[test]
    fn applying_a_window_reuses_the_caller_output() {
        let mut output = [0.0; 4];
        apply_window(&[1.0; 4], &periodic_hann(4), &mut output);
        assert_eq!(output, [0.0, 0.5, 1.0, 0.5]);
    }
}
