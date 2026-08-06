use rust_lib_voice_trainer::{
    golden::{generate_case, manifest_cases, GoldenSignal},
    pitch::{PitchFrame, PitchTracker, VoicedDecisionConfig, YinEstimator},
    signal::pcm::pcm16_to_f32,
};

fn frames(id: &str) -> Vec<PitchFrame> {
    let case = manifest_cases()
        .into_iter()
        .find(|case| case.id == id)
        .expect("known golden case");
    let input: Vec<f32> = generate_case(&case).into_iter().map(pcm16_to_f32).collect();
    let mut tracker = PitchTracker::new(YinEstimator, VoicedDecisionConfig::default());
    input
        .chunks(1_024)
        .flat_map(|chunk| tracker.push(chunk))
        .collect()
}

fn cents_error(actual_hz: f32, expected_hz: f32) -> f32 {
    1_200.0 * (actual_hz / expected_hz).log2()
}

fn percentile(values: &mut [f32], percentile: f32) -> f32 {
    values.sort_by(|left, right| left.total_cmp(right));
    values[((values.len() - 1) as f32 * percentile).round() as usize]
}

#[test]
fn steady_tone_median_error_is_below_one_cent() {
    let mut errors: Vec<f32> = frames("pure_tone_a3")
        .into_iter()
        .filter_map(|frame| {
            frame
                .frequency_hz
                .map(|frequency| cents_error(frequency, 220.0).abs())
        })
        .collect();
    assert!(percentile(&mut errors, 0.50) < 1.0);
}

#[test]
fn harmonics_meet_p95_and_octave_gates() {
    for id in ["harmonic_series_g3", "missing_fundamental_g3"] {
        let mut errors: Vec<f32> = frames(id)
            .into_iter()
            .filter_map(|frame| {
                frame
                    .frequency_hz
                    .map(|frequency| cents_error(frequency, 196.0).abs())
            })
            .collect();
        assert!(percentile(&mut errors, 0.95) < 5.0, "{id}");
        assert!(errors.iter().all(|error| *error < 600.0), "{id}");
    }
}

#[test]
fn glide_and_unvoiced_golden_cases_meet_the_gate() {
    let glide = manifest_cases()
        .into_iter()
        .find(|case| case.id == "linear_glide_a2_to_a4")
        .expect("glide golden");
    let GoldenSignal::LinearGlide {
        start_frequency_hz,
        end_frequency_hz,
        ..
    } = glide.signal
    else {
        unreachable!();
    };
    let mut glide_errors: Vec<f32> = frames("linear_glide_a2_to_a4")
        .into_iter()
        .filter_map(|frame| {
            frame.frequency_hz.map(|frequency| {
                let midpoint_seconds = (frame.start_sample + 1_536) as f32 / 48_000.0;
                let expected = start_frequency_hz as f32
                    + (end_frequency_hz as f32 - start_frequency_hz as f32) * midpoint_seconds
                        / 2.0;
                cents_error(frequency, expected).abs()
            })
        })
        .collect();
    assert!(percentile(&mut glide_errors, 0.95) < 10.0);
    for id in ["silence", "seeded_noise_7"] {
        assert!(frames(id).iter().all(|frame| !frame.voiced), "{id}");
    }
}
