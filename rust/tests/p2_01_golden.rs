use rust_lib_voice_trainer::golden::{
    generate_case, manifest_cases, pcm16_sha256, BreakpointKind, GoldenCase, GoldenSignal,
    PCM16_LE_ENCODING,
};
use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct GoldenManifest {
    #[serde(rename = "$schema")]
    schema: String,
    schema_version: u32,
    pcm_encoding: String,
    cases: Vec<ManifestCase>,
}

#[derive(Debug, Deserialize)]
struct ManifestCase {
    #[serde(flatten)]
    specification: GoldenCase,
    sha256_pcm16le: String,
}

fn manifest() -> GoldenManifest {
    serde_json::from_str(include_str!("../test_assets/p2_01_manifest.json"))
        .expect("P2-01 manifest must be valid JSON")
}

#[test]
fn manifest_matches_the_generator_and_pcm_hashes() {
    let manifest = manifest();
    assert_eq!(manifest.schema, "p2_01_manifest.schema.json");
    assert_eq!(manifest.schema_version, 1);
    assert_eq!(manifest.pcm_encoding, PCM16_LE_ENCODING);

    let generated_cases = manifest_cases();
    assert_eq!(manifest.cases.len(), generated_cases.len());
    for (recorded, generated) in manifest.cases.iter().zip(generated_cases) {
        assert_eq!(
            recorded.specification, generated,
            "case {} drifted",
            recorded.specification.id
        );
        let pcm = generate_case(&recorded.specification);
        assert_eq!(pcm.len(), recorded.specification.sample_count);
        assert_eq!(
            pcm16_sha256(&pcm),
            recorded.sha256_pcm16le,
            "case {} hash drifted",
            recorded.specification.id
        );
        if let Some([minimum, maximum]) = recorded.specification.expected.rms_range {
            let rms = (pcm
                .iter()
                .map(|sample| (*sample as f64 / 32_768.0).powi(2))
                .sum::<f64>()
                / pcm.len() as f64)
                .sqrt();
            assert!(
                (minimum..=maximum).contains(&rms),
                "case {} RMS {rms} is outside its truth range",
                recorded.specification.id
            );
        }
        if let Some(expected_clipped_samples) = recorded.specification.expected.clipped_samples {
            let clipped_samples = pcm
                .iter()
                .filter(|sample| **sample == i16::MIN || **sample == i16::MAX)
                .count();
            assert_eq!(
                clipped_samples, expected_clipped_samples,
                "case {} clipping truth drifted",
                recorded.specification.id
            );
        }
    }
}

#[test]
fn fixed_seed_noise_is_bit_exact() {
    let case = manifest_cases()
        .into_iter()
        .find(|case| case.id == "seeded_noise_7")
        .expect("seeded noise case");
    assert_eq!(generate_case(&case), generate_case(&case));
}

#[test]
fn breakpoint_is_a_real_and_explicit_sample_index_discontinuity() {
    let case = manifest_cases()
        .into_iter()
        .find(|case| case.id == "phase_reset_breakpoint_a3")
        .expect("breakpoint case");
    assert_eq!(case.breakpoints.len(), 1);
    let breakpoint = &case.breakpoints[0];
    assert_eq!(breakpoint.kind, BreakpointKind::Discontinuity);
    assert!(breakpoint.sample_index > 0 && breakpoint.sample_index < case.sample_count);

    let GoldenSignal::PhaseResetSine {
        reset_at_sample, ..
    } = &case.signal
    else {
        panic!("breakpoint case must have phase reset signal");
    };
    assert_eq!(breakpoint.sample_index, *reset_at_sample);
    let pcm = generate_case(&case);
    assert_eq!(
        pcm[*reset_at_sample], 0,
        "the reset begins at its declared sample index"
    );
    assert!(
        pcm[*reset_at_sample - 1].abs() > 1_000,
        "the boundary must not be an accidental continuous phase"
    );
}

#[test]
fn manifest_cases_are_well_formed_input_truth() {
    for case in manifest_cases() {
        assert!(case.sample_rate_hz > 0);
        assert!(case.sample_count > 0);
        assert_eq!(case.encoding, PCM16_LE_ENCODING);
        for breakpoint in case.breakpoints {
            assert!(breakpoint.sample_index > 0 && breakpoint.sample_index < case.sample_count);
        }
        match case.signal {
            GoldenSignal::SeededNoise { .. } => assert!(case.seed.is_some()),
            _ => assert!(case.seed.is_none()),
        }
    }
}
