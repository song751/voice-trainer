use rust_lib_voice_trainer::features::{
    FeatureInput, QualityFlags, SegmentAggregator, SegmentConfig,
};

fn frame(start_sample: u64, dropped_samples: u32) -> FeatureInput {
    FeatureInput {
        start_sample,
        hop_samples: 480,
        rms_dbfs: -30.0,
        peak_dbfs: -27.0,
        clipped_ratio: 0.0,
        dropped_samples,
        discontinuity: false,
        frequency_hz: Some(220.0),
        voiced: true,
    }
}

#[test]
fn a_gap_excludes_the_frame_and_accumulates_missing_samples() {
    let mut aggregator = SegmentAggregator::new(SegmentConfig {
        minimum_valid_frames: 3,
        ..SegmentConfig::default()
    });
    aggregator.push(frame(0, 0));
    aggregator.push(frame(480, 0));
    aggregator.push(frame(1_920, 0));
    let summary = aggregator.finish();
    assert_eq!(summary.dropped_samples, 960);
    assert_eq!(summary.valid_frame_count, 2);
    assert!(summary
        .quality_flags
        .contains(QualityFlags::DROPPED_SAMPLES));
    assert!(summary.quality_flags.contains(QualityFlags::DISCONTINUITY));
    assert!(summary
        .quality_flags
        .contains(QualityFlags::INSUFFICIENT_VALID_FRAMES));
}

#[test]
fn explicit_dropped_samples_are_preserved_without_a_timeline_gap() {
    let mut aggregator = SegmentAggregator::new(SegmentConfig {
        minimum_valid_frames: 1,
        ..SegmentConfig::default()
    });
    aggregator.push(frame(0, 0));
    aggregator.push(frame(480, 32));
    let summary = aggregator.finish();
    assert_eq!(summary.dropped_samples, 32);
    assert!(summary
        .quality_flags
        .contains(QualityFlags::DROPPED_SAMPLES));
    assert_eq!(summary.valid_frame_count, 1);
}
