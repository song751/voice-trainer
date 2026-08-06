use rust_lib_voice_trainer::{
    golden::{generate_case, manifest_cases, GoldenSignal},
    pitch::{
        MpmEstimator, PitchAlgorithm, PitchEstimator, PitchFrame, PitchTracker,
        VoicedDecisionConfig, YinEstimator, DEFAULT_PITCH_ALGORITHM,
    },
    signal::pcm::pcm16_to_f32,
};

fn estimate<E: PitchEstimator>(estimator: E, pcm: &[i16]) -> Vec<PitchFrame> {
    estimate_with_chunks(estimator, pcm, &[1_024])
}

fn estimate_with_chunks<E: PitchEstimator>(
    estimator: E,
    pcm: &[i16],
    chunk_pattern: &[usize],
) -> Vec<PitchFrame> {
    let mut tracker = PitchTracker::new(estimator, VoicedDecisionConfig::default());
    let input: Vec<f32> = pcm.iter().copied().map(pcm16_to_f32).collect();
    let mut frames = Vec::new();
    let mut offset = 0;
    let mut pattern_index = 0;
    while offset < input.len() {
        let end = (offset + chunk_pattern[pattern_index % chunk_pattern.len()]).min(input.len());
        frames.extend(tracker.push(&input[offset..end]));
        offset = end;
        pattern_index += 1;
    }
    frames
}

fn cents_error(actual_hz: f32, expected_hz: f32) -> f32 {
    1_200.0 * (actual_hz / expected_hz).log2()
}

fn percentile(values: &mut [f32], percentile: f32) -> f32 {
    values.sort_by(|left, right| left.total_cmp(right));
    let index = ((values.len() - 1) as f32 * percentile).round() as usize;
    values[index]
}

fn default_errors(case_id: &str) -> Vec<f32> {
    let case = manifest_cases()
        .into_iter()
        .find(|case| case.id == case_id)
        .expect("known P2-01 case");
    let frames = estimate(YinEstimator, &generate_case(&case));
    match case.signal {
        GoldenSignal::LinearGlide {
            start_frequency_hz,
            end_frequency_hz,
            ..
        } => frames
            .into_iter()
            .filter_map(|frame| {
                frame.frequency_hz.map(|actual| {
                    let centre_seconds = (frame.start_sample + 1_536) as f32 / 48_000.0;
                    let expected = start_frequency_hz as f32
                        + (end_frequency_hz as f32 - start_frequency_hz as f32) * centre_seconds
                            / 2.0;
                    cents_error(actual, expected).abs()
                })
            })
            .collect(),
        _ => {
            let expected = case.expected.fundamental_hz.expect("pitched case") as f32;
            frames
                .into_iter()
                .filter_map(|frame| {
                    frame
                        .frequency_hz
                        .map(|actual| cents_error(actual, expected).abs())
                })
                .collect()
        }
    }
}

#[test]
fn yin_is_the_default_after_the_golden_comparison() {
    assert_eq!(DEFAULT_PITCH_ALGORITHM, PitchAlgorithm::Yin);
    for case_id in [
        "pure_tone_a3",
        "harmonic_series_g3",
        "missing_fundamental_g3",
    ] {
        let case = manifest_cases()
            .into_iter()
            .find(|case| case.id == case_id)
            .expect("known P2-01 case");
        let expected = case.expected.fundamental_hz.expect("pitched case") as f32;
        let yin = estimate(YinEstimator, &generate_case(&case));
        let mpm = estimate(MpmEstimator, &generate_case(&case));
        let mut yin_errors: Vec<_> = yin
            .into_iter()
            .filter_map(|frame| {
                frame
                    .frequency_hz
                    .map(|actual| cents_error(actual, expected).abs())
            })
            .collect();
        let mut mpm_errors: Vec<_> = mpm
            .into_iter()
            .filter_map(|frame| {
                frame
                    .frequency_hz
                    .map(|actual| cents_error(actual, expected).abs())
            })
            .collect();
        assert!(
            yin_errors.len() > mpm_errors.len(),
            "{case_id} has more voiced YIN frames"
        );
        assert!(
            percentile(&mut yin_errors, 0.50) < percentile(&mut mpm_errors, 0.50),
            "{case_id} did not favour YIN"
        );
    }
}

#[test]
fn default_yin_meets_the_p2_03_synthetic_pitch_gates() {
    let mut pure = default_errors("pure_tone_a3");
    assert!(percentile(&mut pure, 0.50) < 1.0);

    for case_id in ["harmonic_series_g3", "missing_fundamental_g3"] {
        let mut errors = default_errors(case_id);
        assert!(percentile(&mut errors, 0.95) < 5.0, "{case_id}");
        assert!(
            errors.iter().all(|error| *error < 600.0),
            "{case_id} octave error"
        );
    }

    let mut glide = default_errors("linear_glide_a2_to_a4");
    assert!(percentile(&mut glide, 0.95) < 10.0);
}

#[test]
fn default_yin_rejects_silence_and_low_energy_noise() {
    for case_id in ["silence", "seeded_noise_7"] {
        let case = manifest_cases()
            .into_iter()
            .find(|case| case.id == case_id)
            .expect("known P2-01 unvoiced case");
        let frames = estimate(YinEstimator, &generate_case(&case));
        assert!(frames.iter().all(|frame| !frame.voiced), "{case_id}");
    }
}

#[test]
fn continuity_rejects_an_implausible_octave_jump() {
    let input: Vec<f32> = (0..48_000)
        .map(|index| {
            let frequency_hz = if index < 24_000 { 220.0 } else { 880.0 };
            (std::f32::consts::TAU * frequency_hz * index as f32 / 48_000.0).sin() * 0.5
        })
        .collect();
    let mut tracker = PitchTracker::new(YinEstimator, VoicedDecisionConfig::default());
    let mut frames = Vec::new();
    for chunk in input.chunks(1_024) {
        frames.extend(tracker.push(chunk));
    }
    assert!(frames.iter().any(|frame| frame.voiced));
    assert!(
        frames
            .iter()
            .filter(|frame| frame.start_sample > 24_000)
            .all(|frame| !frame.voiced),
        "the continuity gate accepted a 2-octave jump"
    );
}

#[test]
fn default_tracker_is_chunk_invariant_on_the_glide_golden() {
    let case = manifest_cases()
        .into_iter()
        .find(|case| case.id == "linear_glide_a2_to_a4")
        .expect("P2-01 glide case");
    let pcm = generate_case(&case);
    assert_eq!(
        estimate_with_chunks(YinEstimator, &pcm, &[pcm.len()]),
        estimate_with_chunks(YinEstimator, &pcm, &[1, 17, 511, 1_024, 37, 2_048, 3, 777])
    );
}
