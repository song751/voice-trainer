use super::{parabolic_offset, PitchAlgorithm, PitchConfig, PitchEstimate, PitchEstimator};

const YIN_THRESHOLD: f32 = 0.12;

/// YIN's cumulative mean normalized difference function estimator.
#[flutter_rust_bridge::frb(opaque)]
#[derive(Default)]
pub struct YinEstimator;

impl PitchEstimator for YinEstimator {
    fn algorithm(&self) -> PitchAlgorithm {
        PitchAlgorithm::Yin
    }

    fn estimate(&self, samples: &[f32], config: PitchConfig) -> Option<PitchEstimate> {
        let (min_lag, max_lag) = config.lag_bounds(samples.len());
        if max_lag <= min_lag || max_lag >= 1_024 {
            return None;
        }

        let mut cmndf_values = [0.0_f32; 1024];
        let mut running_sum = 0.0;
        let mut candidate = None;
        for (lag, cmndf_slot) in cmndf_values
            .iter_mut()
            .enumerate()
            .skip(1)
            .take(max_lag + 1)
        {
            let difference = difference(samples, lag);
            running_sum += difference;
            let cmndf = difference * lag as f32 / running_sum.max(f32::EPSILON);
            *cmndf_slot = cmndf;
            if lag >= min_lag && candidate.is_none() && cmndf < YIN_THRESHOLD {
                candidate = Some(lag);
            }
        }
        let mut lag = candidate?;
        while lag < max_lag && cmndf_values[lag + 1] < cmndf_values[lag] {
            lag += 1;
        }
        let centre = cmndf_values[lag];
        let offset = parabolic_offset(cmndf_values[lag - 1], centre, cmndf_values[lag + 1]);
        let refined_lag = lag as f32 + offset;
        (refined_lag > 0.0).then_some(PitchEstimate {
            frequency_hz: config.sample_rate_hz as f32 / refined_lag,
            clarity: (1.0 - centre).clamp(0.0, 1.0),
        })
    }
}

fn difference(samples: &[f32], lag: usize) -> f32 {
    samples
        .iter()
        .zip(&samples[lag..])
        .map(|(&left, &right)| {
            let difference = left - right;
            difference * difference
        })
        .sum()
}
