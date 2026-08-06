use super::{parabolic_offset, PitchAlgorithm, PitchConfig, PitchEstimate, PitchEstimator};

/// McLeod Pitch Method's normalized square difference function estimator.
#[flutter_rust_bridge::frb(opaque)]
#[derive(Default)]
pub struct MpmEstimator;

impl PitchEstimator for MpmEstimator {
    fn algorithm(&self) -> PitchAlgorithm {
        PitchAlgorithm::Mpm
    }

    fn estimate(&self, samples: &[f32], config: PitchConfig) -> Option<PitchEstimate> {
        let (min_lag, max_lag) = config.lag_bounds(samples.len());
        if max_lag <= min_lag {
            return None;
        }

        let mut best_lag = None;
        let mut best_clarity = f32::NEG_INFINITY;
        let mut previous = nsdf(samples, min_lag);
        let mut current = nsdf(samples, min_lag + 1);
        for lag in min_lag + 1..max_lag {
            let next = nsdf(samples, lag + 1);
            if current > 0.0 && current >= previous && current > next && current > best_clarity {
                best_lag = Some(lag);
                best_clarity = current;
            }
            previous = current;
            current = next;
        }
        let lag = best_lag?;
        let offset = parabolic_offset(
            nsdf(samples, lag - 1),
            nsdf(samples, lag),
            nsdf(samples, lag + 1),
        );
        let refined_lag = lag as f32 + offset;
        (refined_lag > 0.0).then_some(PitchEstimate {
            frequency_hz: config.sample_rate_hz as f32 / refined_lag,
            clarity: best_clarity.clamp(0.0, 1.0),
        })
    }
}

fn nsdf(samples: &[f32], lag: usize) -> f32 {
    let mut numerator = 0.0;
    let mut denominator = 0.0;
    for (&left, &right) in samples.iter().zip(&samples[lag..]) {
        numerator += 2.0 * left * right;
        denominator += left * left + right * right;
    }
    if denominator > f32::EPSILON {
        numerator / denominator
    } else {
        0.0
    }
}
