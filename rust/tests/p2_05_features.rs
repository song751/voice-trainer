use rust_lib_voice_trainer::{
    features::{FeatureInput, QualityConfig, QualityFlags, SegmentAggregator, SegmentConfig},
    golden::{generate_case, manifest_cases},
    signal::pcm::pcm16_to_f32,
};

fn case(id: &str) -> rust_lib_voice_trainer::golden::GoldenCase {
    manifest_cases()
        .into_iter()
        .find(|case| case.id == id)
        .expect("known P2-01 case")
}

fn valid_frame(start_sample: u64, frequency_hz: f32, rms_dbfs: f32) -> FeatureInput {
    FeatureInput {
        start_sample,
        hop_samples: 480,
        rms_dbfs,
        peak_dbfs: rms_dbfs + 3.0,
        clipped_ratio: 0.0,
        dropped_samples: 0,
        discontinuity: false,
        frequency_hz: Some(frequency_hz),
        voiced: true,
    }
}

#[test]
fn p2_01_inputs_set_physical_input_quality_flags() {
    let pure = generate_case(&case("pure_tone_a3"));
    let pure: Vec<_> = pure.into_iter().map(pcm16_to_f32).collect();
    let pure_features = FeatureInput::from_samples(0, 480, &pure, Some(220.0), true);
    assert_eq!(
        pure_features.quality_flags(QualityConfig::default()),
        QualityFlags::NONE
    );

    let clipped = generate_case(&case("clipped_sine_a3"));
    let clipped: Vec<_> = clipped.into_iter().map(pcm16_to_f32).collect();
    assert!(
        FeatureInput::from_samples(0, 480, &clipped, Some(220.0), true)
            .quality_flags(QualityConfig::default())
            .contains(QualityFlags::CLIPPING)
    );

    let silence = generate_case(&case("silence"));
    let silence: Vec<_> = silence.into_iter().map(pcm16_to_f32).collect();
    assert!(FeatureInput::from_samples(0, 480, &silence, None, false)
        .quality_flags(QualityConfig::default())
        .contains(QualityFlags::INPUT_TOO_LOW));
}

#[test]
fn segment_summary_reports_robust_stability_and_onset() {
    let config = SegmentConfig {
        minimum_valid_frames: 3,
        ..SegmentConfig::default()
    };
    let mut aggregator = SegmentAggregator::new(config);
    for (index, frequency_hz) in [220.0, 220.1, 219.9, 440.0, 220.0].into_iter().enumerate() {
        aggregator.push(valid_frame(index as u64 * 480, frequency_hz, -30.0));
    }
    let summary = aggregator.finish();
    assert_eq!(summary.valid_frame_count, 5);
    assert!(!summary
        .quality_flags
        .contains(QualityFlags::INSUFFICIENT_VALID_FRAMES));
    assert!(summary.pitch_stability.unwrap().median_absolute_deviation < 2.0);
    assert_eq!(summary.onset_delay_samples, Some(960));
}

#[test]
fn sample_index_gap_marks_discontinuity_drops_and_insufficient_frames() {
    let config = SegmentConfig {
        minimum_valid_frames: 3,
        ..SegmentConfig::default()
    };
    let mut aggregator = SegmentAggregator::new(config);
    aggregator.push(valid_frame(0, 220.0, -30.0));
    aggregator.push(valid_frame(480, 220.0, -30.0));
    aggregator.push(valid_frame(1_440, 220.0, -30.0));
    let summary = aggregator.finish();
    assert_eq!(summary.dropped_samples, 480);
    assert!(summary
        .quality_flags
        .contains(QualityFlags::DROPPED_SAMPLES));
    assert!(summary.quality_flags.contains(QualityFlags::DISCONTINUITY));
    assert!(summary
        .quality_flags
        .contains(QualityFlags::INSUFFICIENT_VALID_FRAMES));
}
