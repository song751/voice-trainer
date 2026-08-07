use rust_lib_voice_trainer::{
    features::QualityFlags, pipeline::realtime_analyzer::RealtimeAnalyzerCore,
};

fn sine(sample_count: usize, frequency_hz: f32) -> Vec<i16> {
    (0..sample_count)
        .map(|index| {
            (0.5 * (std::f32::consts::TAU * frequency_hz * index as f32 / 48_000.0).sin()
                * i16::MAX as f32) as i16
        })
        .collect()
}

#[test]
fn forward_capture_gap_restarts_windows_but_preserves_timeline_and_quality_evidence() {
    let pcm = sine(48_000, 220.0);
    let mut analyzer = RealtimeAnalyzerCore::new(48_000);
    let before = analyzer.push_pcm16_at(10_000, &pcm);
    let gap_samples = 960;
    let resume_at = 10_000 + pcm.len() as u64 + gap_samples;
    let after = analyzer.push_pcm16_at(resume_at, &pcm);
    let summary = analyzer.finish();

    assert!(before
        .windows(2)
        .all(|pair| pair[1].start_sample - pair[0].start_sample == 480));
    assert_eq!(after.first().unwrap().start_sample, resume_at);
    assert!(after
        .windows(2)
        .all(|pair| pair[1].start_sample - pair[0].start_sample == 480));
    assert!(after[0].quality_flags & QualityFlags::DISCONTINUITY.bits() != 0);
    assert!(after[0].quality_flags & QualityFlags::DROPPED_SAMPLES.bits() != 0);
    assert_eq!(summary.dropped_samples, gap_samples);
    assert!(summary.quality_flags.contains(QualityFlags::DISCONTINUITY));
    assert!(summary
        .quality_flags
        .contains(QualityFlags::DROPPED_SAMPLES));
}

#[test]
fn explicit_pause_resume_break_invalidates_cross_breakpoint_statistics_without_rewinding() {
    let pcm = sine(48_000, 220.0);
    let mut analyzer = RealtimeAnalyzerCore::new(48_000);
    let before = analyzer.push_pcm16_at(0, &pcm);
    let after = analyzer.push_pcm16_with_metadata(pcm.len() as u64, &pcm, 0, true);
    let summary = analyzer.finish();

    assert!(after[0].start_sample > before.last().unwrap().start_sample);
    assert!(after[0].quality_flags & QualityFlags::DISCONTINUITY.bits() != 0);
    assert_eq!(summary.dropped_samples, 0);
    assert!(summary.quality_flags.contains(QualityFlags::DISCONTINUITY));
}
