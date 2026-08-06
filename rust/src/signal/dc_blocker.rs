//! A one-pole DC blocker with a documented 20 Hz default cutoff.

#[derive(Clone, Debug)]
pub struct DcBlocker {
    pole: f32,
    previous_input: f32,
    previous_output: f32,
}

impl DcBlocker {
    pub fn new(sample_rate_hz: u32, cutoff_hz: f32) -> Self {
        assert!(sample_rate_hz > 0, "sample rate must be positive");
        assert!(cutoff_hz > 0.0 && cutoff_hz < sample_rate_hz as f32 / 2.0);
        let pole = (-std::f32::consts::TAU * cutoff_hz / sample_rate_hz as f32).exp();
        Self {
            pole,
            previous_input: 0.0,
            previous_output: 0.0,
        }
    }

    pub fn process(&mut self, input: f32) -> f32 {
        let output = input - self.previous_input + self.pole * self.previous_output;
        self.previous_input = input;
        self.previous_output = output;
        output
    }

    pub fn reset(&mut self) {
        self.previous_input = 0.0;
        self.previous_output = 0.0;
    }
}

#[cfg(test)]
mod tests {
    use super::DcBlocker;

    #[test]
    fn suppresses_a_constant_offset_after_settling() {
        let mut blocker = DcBlocker::new(48_000, 20.0);
        let tail = (0..48_000)
            .map(|_| blocker.process(0.25))
            .last()
            .expect("non-empty iterator");
        assert!(tail.abs() < 0.001, "tail was {tail}");
    }

    #[test]
    fn reset_restarts_the_filter_state() {
        let mut blocker = DcBlocker::new(48_000, 20.0);
        blocker.process(0.5);
        blocker.reset();
        assert_eq!(blocker.process(0.5), 0.5);
    }
}
