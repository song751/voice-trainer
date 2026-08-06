use rust_lib_voice_trainer::{
    golden::{generate_case, manifest_cases},
    signal::pcm::pcm16_to_f32,
    spectrum::{band_index_for_frequency, SpectrumAnalyzer, SPECTRUM_WINDOW_SIZE, UI_BIN_COUNT},
};

fn spectrum(input: &[f32]) -> Vec<rust_lib_voice_trainer::spectrum::SpectrumFrame> {
    let mut analyzer = SpectrumAnalyzer::new();
    input
        .chunks(1_024)
        .flat_map(|chunk| analyzer.push(chunk))
        .collect()
}

#[test]
fn full_scale_bin_centred_tone_has_physical_power_and_centroid() {
    let bin = 80;
    let frequency_hz = bin as f32 * 48_000.0 / SPECTRUM_WINDOW_SIZE as f32;
    let input: Vec<f32> = (0..SPECTRUM_WINDOW_SIZE * 2)
        .map(|index| (std::f32::consts::TAU * frequency_hz * index as f32 / 48_000.0).sin())
        .collect();
    let frame = spectrum(&input).remove(0);
    assert!((frame.total_power_dbfs + 3.0103).abs() < 0.02);
    assert!((frame.spectral_centroid_hz - frequency_hz).abs() < 0.1);
    assert!(
        (frame.band_powers_dbfs[band_index_for_frequency(frequency_hz).unwrap()] + 3.0103).abs()
            < 0.02
    );
}

#[test]
fn golden_silence_and_ui_shape_are_bounded() {
    let silence = manifest_cases()
        .into_iter()
        .find(|case| case.id == "silence")
        .expect("silence golden");
    let input: Vec<f32> = generate_case(&silence)
        .into_iter()
        .map(pcm16_to_f32)
        .collect();
    for frame in spectrum(&input) {
        assert_eq!(frame.total_power_dbfs, -120.0);
        assert_eq!(frame.spectral_centroid_hz, 0.0);
        assert_eq!(frame.ui_bins_dbfs.len(), UI_BIN_COUNT);
        assert!(frame.ui_bins_dbfs.iter().all(|value| *value == -120.0));
    }
}
