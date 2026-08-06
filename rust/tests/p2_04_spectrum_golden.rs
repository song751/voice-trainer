use rust_lib_voice_trainer::{
    golden::{generate_case, manifest_cases},
    signal::pcm::pcm16_to_f32,
    spectrum::{
        band_index_for_frequency, ui_bin_for_frequency, SpectrumAnalyzer, SPECTRUM_HOP_SIZE,
        SPECTRUM_WINDOW_SIZE, UI_BIN_COUNT,
    },
};

fn analyze(
    input: &[f32],
    chunk_pattern: &[usize],
) -> Vec<rust_lib_voice_trainer::spectrum::SpectrumFrame> {
    let mut analyzer = SpectrumAnalyzer::new();
    let mut frames = Vec::new();
    let mut offset = 0;
    let mut pattern_index = 0;
    while offset < input.len() {
        let end = (offset + chunk_pattern[pattern_index % chunk_pattern.len()]).min(input.len());
        frames.extend(analyzer.push(&input[offset..end]));
        offset = end;
        pattern_index += 1;
    }
    frames
}

#[test]
fn bin_centred_full_scale_sine_has_correct_power_and_centroid() {
    let bin = 80;
    let frequency_hz = bin as f32 * 48_000.0 / SPECTRUM_WINDOW_SIZE as f32;
    let input: Vec<f32> = (0..SPECTRUM_WINDOW_SIZE * 2)
        .map(|index| (std::f32::consts::TAU * frequency_hz * index as f32 / 48_000.0).sin())
        .collect();
    let frame = analyze(&input, &[input.len()])[0].clone();
    assert!(
        (frame.total_power_dbfs + 3.0103).abs() < 0.02,
        "{}",
        frame.total_power_dbfs
    );
    assert!((frame.spectral_centroid_hz - frequency_hz).abs() < 0.1);
    assert!(
        (frame.band_powers_dbfs[band_index_for_frequency(frequency_hz).unwrap()] + 3.0103).abs()
            < 0.02
    );

    let expected_ui_bin = ui_bin_for_frequency(frequency_hz, 24_000.0).unwrap();
    let observed_ui_bin = frame
        .ui_bins_dbfs
        .iter()
        .enumerate()
        .max_by(|(_, left), (_, right)| left.total_cmp(right))
        .map(|(index, _)| index)
        .unwrap();
    assert_eq!(observed_ui_bin, expected_ui_bin);
}

#[test]
fn silence_has_floor_power_zero_centroid_and_complete_ui_shape() {
    let frames = analyze(&vec![0.0; SPECTRUM_WINDOW_SIZE], &[1_024]);
    let frame = &frames[0];
    assert_eq!(frame.total_power_dbfs, -120.0);
    assert_eq!(frame.spectral_centroid_hz, 0.0);
    assert!(frame.band_powers_dbfs.iter().all(|value| *value == -120.0));
    assert_eq!(frame.ui_bins_dbfs.len(), UI_BIN_COUNT);
    assert!(frame.ui_bins_dbfs.iter().all(|value| *value == -120.0));
}

#[test]
fn p2_01_inputs_are_spectrum_chunk_invariant_at_10ms_hops() {
    let pattern = [1, 17, 511, 1_024, 37, 2_048, 3, 777];
    for case in manifest_cases() {
        let input: Vec<f32> = generate_case(&case).into_iter().map(pcm16_to_f32).collect();
        let whole = analyze(&input, &[input.len()]);
        let chunked = analyze(&input, &pattern);
        assert_eq!(chunked, whole, "{} changed with chunking", case.id);
        assert_eq!(
            whole
                .iter()
                .map(|frame| frame.start_sample)
                .collect::<Vec<_>>(),
            (0..whole.len())
                .map(|index| index as u64 * SPECTRUM_HOP_SIZE as u64)
                .collect::<Vec<_>>(),
            "{} did not use 480-sample hops",
            case.id
        );
    }
}
