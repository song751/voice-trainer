use rust_lib_voice_trainer::{
    golden::{generate_case, manifest_cases},
    pipeline::realtime_analyzer::RealtimeAnalyzerCore,
    pitch::{PitchFrame, PitchTracker, VoicedDecisionConfig, YinEstimator},
    signal::pcm::pcm16_to_f32,
    spectrum::{SpectrumAnalyzer, SpectrumFrame},
};

const CHUNK_PATTERN: [usize; 8] = [1, 17, 511, 1_024, 37, 2_048, 3, 777];

fn realtime(input: &[i16], chunks: &[usize]) -> Vec<rust_lib_voice_trainer::model::AnalysisFrame> {
    let mut analyzer = RealtimeAnalyzerCore::new(48_000);
    let mut frames = Vec::new();
    let mut offset = 0;
    let mut index = 0;
    while offset < input.len() {
        let end = (offset + chunks[index % chunks.len()]).min(input.len());
        frames.extend(analyzer.push_pcm16(&input[offset..end]));
        offset = end;
        index += 1;
    }
    frames
}

fn spectrum(input: &[f32], chunks: &[usize]) -> Vec<SpectrumFrame> {
    let mut analyzer = SpectrumAnalyzer::new();
    let mut frames = Vec::new();
    let mut offset = 0;
    let mut index = 0;
    while offset < input.len() {
        let end = (offset + chunks[index % chunks.len()]).min(input.len());
        frames.extend(analyzer.push(&input[offset..end]));
        offset = end;
        index += 1;
    }
    frames
}

fn pitch(input: &[f32], chunks: &[usize]) -> Vec<PitchFrame> {
    let mut tracker = PitchTracker::new(YinEstimator, VoicedDecisionConfig::default());
    let mut frames = Vec::new();
    let mut offset = 0;
    let mut index = 0;
    while offset < input.len() {
        let end = (offset + chunks[index % chunks.len()]).min(input.len());
        frames.extend(tracker.push(&input[offset..end]));
        offset = end;
        index += 1;
    }
    frames
}

#[test]
fn all_realtime_branches_are_invariant_to_capture_chunking() {
    for case in manifest_cases() {
        let pcm = generate_case(&case);
        let samples: Vec<f32> = pcm.iter().copied().map(pcm16_to_f32).collect();
        assert_eq!(
            realtime(&pcm, &[pcm.len()]),
            realtime(&pcm, &CHUNK_PATTERN),
            "realtime core changed for {}",
            case.id
        );
        assert_eq!(
            spectrum(&samples, &[samples.len()]),
            spectrum(&samples, &CHUNK_PATTERN),
            "spectrum changed for {}",
            case.id
        );
        assert_eq!(
            pitch(&samples, &[samples.len()]),
            pitch(&samples, &CHUNK_PATTERN),
            "pitch changed for {}",
            case.id
        );
    }
}
