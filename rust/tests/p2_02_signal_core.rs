use rust_lib_voice_trainer::{
    golden::{generate_case, manifest_cases},
    signal::{dc_blocker::DcBlocker, pcm::pcm16_to_f32, resampler::PolyphaseDecimator3},
};

fn preprocess_and_decimate(input: &[i16], chunk_pattern: &[usize]) -> Vec<f32> {
    let mut blocker = DcBlocker::new(48_000, 20.0);
    let mut decimator = PolyphaseDecimator3::new(48_000).expect("canonical rate is supported");
    let mut output = Vec::new();
    let mut offset = 0;
    let mut pattern_index = 0;
    while offset < input.len() {
        let end = (offset + chunk_pattern[pattern_index % chunk_pattern.len()]).min(input.len());
        let filtered: Vec<f32> = input[offset..end]
            .iter()
            .copied()
            .map(pcm16_to_f32)
            .map(|sample| blocker.process(sample))
            .collect();
        decimator.process_into(&filtered, &mut output);
        offset = end;
        pattern_index += 1;
    }
    output
}

#[test]
fn every_p2_01_input_is_preprocessed_and_resampled_independently_of_chunking() {
    let pattern = [1, 17, 511, 1024, 37, 2048, 3, 777];
    for case in manifest_cases() {
        let input = generate_case(&case);
        let whole = preprocess_and_decimate(&input, &[input.len()]);
        let chunked = preprocess_and_decimate(&input, &pattern);
        assert_eq!(chunked, whole, "{} changed with chunking", case.id);
        assert_eq!(
            whole.len(),
            input.len() / 3,
            "{} had an unexpected output length",
            case.id
        );
    }
}

#[test]
fn silence_remains_silence_through_the_core() {
    let silence = manifest_cases()
        .into_iter()
        .find(|case| case.id == "silence")
        .expect("P2-01 silence case");
    let output = preprocess_and_decimate(&generate_case(&silence), &[1024]);
    assert!(output.iter().all(|sample| *sample == 0.0));
}
