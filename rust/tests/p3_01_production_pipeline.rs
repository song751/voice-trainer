use rust_lib_voice_trainer::{
    api::realtime::{AnalysisFrameDto, RealtimeAnalyzer},
    features::{QualityFlags, SegmentSummary},
    golden::{generate_case, manifest_cases, GoldenCase, GoldenSignal},
    model::AnalysisFrame,
    pipeline::realtime_analyzer::RealtimeAnalyzerCore,
    spectrum::BAND_POWER_COUNT,
};

const START_SAMPLE: u64 = 50_000;
const CHUNK_PATTERN: [usize; 8] = [1, 17, 511, 1_024, 37, 777, 3, 999];

#[derive(Debug, PartialEq)]
struct ProductionResult {
    frames: Vec<AnalysisFrame>,
    summary: SegmentSummary,
}

fn golden_case(id: &str) -> GoldenCase {
    manifest_cases()
        .into_iter()
        .find(|case| case.id == id)
        .expect("known P2-01 golden case")
}

fn run_core(pcm: &[i16], chunks: &[usize]) -> ProductionResult {
    let mut analyzer = RealtimeAnalyzerCore::new(48_000);
    let mut frames = Vec::new();
    let mut offset = 0;
    let mut chunk_index = 0;
    while offset < pcm.len() {
        let end = (offset + chunks[chunk_index % chunks.len()]).min(pcm.len());
        frames.extend(analyzer.push_pcm16_at(START_SAMPLE + offset as u64, &pcm[offset..end]));
        offset = end;
        chunk_index += 1;
    }
    ProductionResult {
        frames,
        summary: analyzer.finish(),
    }
}

fn dto_frames(pcm: &[i16]) -> Vec<AnalysisFrameDto> {
    let mut analyzer = RealtimeAnalyzer::new(48_000);
    let mut frames = Vec::new();
    let mut offset = 0;
    let mut chunk_index = 0;
    while offset < pcm.len() {
        let end = (offset + CHUNK_PATTERN[chunk_index % CHUNK_PATTERN.len()]).min(pcm.len());
        frames.extend(
            analyzer.push_pcm16_at(START_SAMPLE + offset as u64, pcm[offset..end].to_vec()),
        );
        offset = end;
        chunk_index += 1;
    }
    frames
}

fn cents_error(actual_hz: f32, expected_hz: f32) -> f32 {
    1_200.0 * (actual_hz / expected_hz).log2()
}

fn percentile(values: &mut [f32], percentile: f32) -> f32 {
    values.sort_by(|left, right| left.total_cmp(right));
    values[((values.len() - 1) as f32 * percentile).round() as usize]
}

#[test]
fn production_entry_preserves_all_p2_01_golden_outputs_under_arbitrary_chunking() {
    for case in manifest_cases() {
        let pcm = generate_case(&case);
        let whole = run_core(&pcm, &[pcm.len()]);
        let chunked = run_core(&pcm, &CHUNK_PATTERN);
        assert_eq!(chunked, whole, "production result changed for {}", case.id);
        assert!(
            !whole.frames.is_empty(),
            "{} produced no 100 Hz frames",
            case.id
        );
        assert_eq!(whole.frames[0].start_sample, START_SAMPLE, "{}", case.id);
        assert!(
            whole
                .frames
                .windows(2)
                .all(|pair| { pair[1].start_sample - pair[0].start_sample == 480 }),
            "{}",
            case.id
        );
        assert_eq!(
            whole.summary.start_sample,
            Some(START_SAMPLE),
            "{}",
            case.id
        );
        assert_eq!(
            whole.summary.end_sample,
            whole.frames.last().map(|frame| frame.start_sample + 480),
            "{}",
            case.id
        );
        assert_eq!(whole.summary.frame_count, whole.frames.len(), "{}", case.id);
        assert!(
            whole
                .frames
                .iter()
                .all(|frame| frame.band_powers_dbfs.len() == BAND_POWER_COUNT),
            "{}",
            case.id
        );
    }
}

#[test]
fn production_entry_keeps_yin_truth_and_quality_segment_gates() {
    for id in [
        "pure_tone_a3",
        "harmonic_series_g3",
        "missing_fundamental_g3",
    ] {
        let expected_hz = if id == "pure_tone_a3" { 220.0 } else { 196.0 };
        let result = run_core(&generate_case(&golden_case(id)), &CHUNK_PATTERN);
        let mut errors: Vec<f32> = result
            .frames
            .iter()
            .filter_map(|frame| frame.pitch_hz)
            .map(|frequency_hz| cents_error(frequency_hz, expected_hz).abs())
            .collect();
        assert!(percentile(&mut errors, 0.95) < 5.0, "{id}");
        assert_eq!(result.summary.quality_flags, QualityFlags::NONE, "{id}");
        assert!(result.summary.valid_frame_count >= 30, "{id}");
    }

    let glide_case = golden_case("linear_glide_a2_to_a4");
    let GoldenSignal::LinearGlide {
        start_frequency_hz,
        end_frequency_hz,
        ..
    } = glide_case.signal
    else {
        unreachable!()
    };
    let glide = run_core(&generate_case(&glide_case), &CHUNK_PATTERN);
    let mut glide_errors: Vec<f32> = glide
        .frames
        .iter()
        .filter_map(|frame| {
            frame.pitch_hz.map(|frequency_hz| {
                let midpoint_seconds =
                    (frame.start_sample - START_SAMPLE + 1_536) as f32 / 48_000.0;
                let expected_hz = start_frequency_hz as f32
                    + (end_frequency_hz as f32 - start_frequency_hz as f32) * midpoint_seconds
                        / 2.0;
                cents_error(frequency_hz, expected_hz).abs()
            })
        })
        .collect();
    assert!(percentile(&mut glide_errors, 0.95) < 10.0);

    for id in ["silence", "seeded_noise_7"] {
        let result = run_core(&generate_case(&golden_case(id)), &CHUNK_PATTERN);
        assert!(
            result.frames.iter().all(|frame| frame.pitch_hz.is_none()),
            "{id}"
        );
        assert!(
            result
                .summary
                .quality_flags
                .contains(QualityFlags::INSUFFICIENT_VALID_FRAMES),
            "{id}"
        );
    }

    let silence = run_core(&generate_case(&golden_case("silence")), &CHUNK_PATTERN);
    assert!(silence
        .summary
        .quality_flags
        .contains(QualityFlags::INPUT_TOO_LOW));

    let clipped = run_core(
        &generate_case(&golden_case("clipped_sine_a3")),
        &CHUNK_PATTERN,
    );
    assert!(clipped
        .summary
        .quality_flags
        .contains(QualityFlags::CLIPPING));
    assert!(clipped
        .frames
        .iter()
        .all(|frame| frame.quality_flags & QualityFlags::CLIPPING.bits() != 0));
}

#[test]
fn stable_bridge_dto_exposes_the_production_sample_timeline_only() {
    let pcm = generate_case(&golden_case("pure_tone_a3"));
    let core = run_core(&pcm, &CHUNK_PATTERN);
    let dto = dto_frames(&pcm);
    assert_eq!(dto.len(), core.frames.len());
    for (dto, frame) in dto.iter().zip(&core.frames) {
        assert_eq!(dto.start_sample, frame.start_sample);
        assert_eq!(dto.pitch_hz, frame.pitch_hz);
        assert_eq!(dto.voiced, frame.pitch_hz.is_some());
        assert_eq!(dto.quality_flags, frame.quality_flags);
        assert_eq!(dto.band_powers_dbfs.len(), BAND_POWER_COUNT);
    }
}
