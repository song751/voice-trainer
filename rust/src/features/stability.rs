#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RobustStability {
    pub median: f32,
    pub median_absolute_deviation: f32,
    pub slope_per_second: f32,
    pub frame_count: usize,
}

pub fn pitch_stability(values: &[(u64, f32)], sample_rate_hz: u32) -> Option<RobustStability> {
    let cents: Vec<_> = values
        .iter()
        .filter_map(|(sample, frequency_hz)| {
            (*frequency_hz > 0.0).then_some((*sample, 1_200.0 * frequency_hz.log2()))
        })
        .collect();
    robust_stability(&cents, sample_rate_hz)
}

pub fn level_stability(values: &[(u64, f32)], sample_rate_hz: u32) -> Option<RobustStability> {
    robust_stability(values, sample_rate_hz)
}

fn robust_stability(values: &[(u64, f32)], sample_rate_hz: u32) -> Option<RobustStability> {
    if values.len() < 2 || sample_rate_hz == 0 {
        return None;
    }
    let first_sample = values[0].0;
    let points: Vec<_> = values
        .iter()
        .map(|(sample, value)| {
            (
                (*sample - first_sample) as f32 / sample_rate_hz as f32,
                *value,
            )
        })
        .collect();
    // Median adjacent-frame slope resists isolated octave/level outliers while
    // still removing the slow drift that should not count as instability.
    let slopes: Vec<_> = points
        .windows(2)
        .filter_map(|pair| {
            let delta_time = pair[1].0 - pair[0].0;
            (delta_time > f32::EPSILON).then_some((pair[1].1 - pair[0].1) / delta_time)
        })
        .collect();
    let slope_per_second = if slopes.is_empty() {
        0.0
    } else {
        median(&slopes)
    };
    let intercept = median(
        &points
            .iter()
            .map(|(time, value)| value - slope_per_second * time)
            .collect::<Vec<_>>(),
    );
    let residuals: Vec<_> = points
        .iter()
        .map(|(time, value)| value - (intercept + slope_per_second * time))
        .collect();
    let median_value = median(&residuals);
    let deviations: Vec<_> = residuals
        .iter()
        .map(|value| (value - median_value).abs())
        .collect();
    Some(RobustStability {
        median: median_value,
        median_absolute_deviation: median(&deviations),
        slope_per_second,
        frame_count: values.len(),
    })
}

fn median(values: &[f32]) -> f32 {
    let mut sorted = values.to_vec();
    sorted.sort_by(|left, right| left.total_cmp(right));
    let midpoint = sorted.len() / 2;
    if sorted.len().is_multiple_of(2) {
        (sorted[midpoint - 1] + sorted[midpoint]) / 2.0
    } else {
        sorted[midpoint]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pitch_stability_uses_mad_not_an_outlier_sensitive_spread() {
        let values = [
            (0, 220.0),
            (480, 220.1),
            (960, 219.9),
            (1_440, 440.0),
            (1_920, 220.0),
        ];
        let stability = pitch_stability(&values, 48_000).unwrap();
        assert!(stability.median_absolute_deviation < 2.0);
    }
}
