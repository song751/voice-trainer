use std::{env, time::Instant};

use rust_lib_voice_trainer::api::realtime::RealtimeAnalyzer;

const SAMPLE_RATE_HZ: u32 = 48_000;
const MAX_BATCH_SAMPLES: usize = 1_024;
const BAND_POWER_COUNT: usize = 8;

fn seconds() -> usize {
    env::args()
        .find_map(|argument| argument.strip_prefix("--seconds=")?.parse().ok())
        .unwrap_or(60)
}

fn main() {
    let seconds = seconds();
    let total_samples = seconds * SAMPLE_RATE_HZ as usize;
    let mut analyzer = RealtimeAnalyzer::new(SAMPLE_RATE_HZ);
    let mut offset = 0;
    let mut max_frames_per_call = 0;
    let mut max_band_powers = 0;
    let mut frame_count = 0;
    let started = Instant::now();
    while offset < total_samples {
        let count = (total_samples - offset).min(MAX_BATCH_SAMPLES);
        let pcm: Vec<i16> = (0..count)
            .map(|index| {
                let phase =
                    std::f32::consts::TAU * 220.0 * (offset + index) as f32 / SAMPLE_RATE_HZ as f32;
                (phase.sin() * 16_000.0) as i16
            })
            .collect();
        let frames = analyzer.push_pcm16(pcm);
        max_frames_per_call = max_frames_per_call.max(frames.len());
        max_band_powers = max_band_powers.max(
            frames
                .iter()
                .map(|frame| frame.band_powers_dbfs.len())
                .max()
                .unwrap_or(0),
        );
        frame_count += frames.len();
        offset += count;
    }
    let elapsed_seconds = started.elapsed().as_secs_f64();
    let realtime_factor = seconds as f64 / elapsed_seconds;
    assert!(
        max_frames_per_call <= 2,
        "too many result frames per bounded batch"
    );
    assert_eq!(max_band_powers, BAND_POWER_COUNT);
    assert!(
        realtime_factor >= 10.0,
        "realtime factor was {realtime_factor:.2}x"
    );
    println!(
        "{{\"benchmark\":\"bridge_payload\",\"sampleRateHz\":{SAMPLE_RATE_HZ},\"seconds\":{seconds},\"maxInputSamples\":{MAX_BATCH_SAMPLES},\"maxInputBytes\":{},\"maxFramesPerCall\":{max_frames_per_call},\"maxBandPowers\":{max_band_powers},\"frameCount\":{frame_count},\"elapsedMs\":{:.3},\"realtimeFactor\":{realtime_factor:.3}}}",
        MAX_BATCH_SAMPLES * std::mem::size_of::<i16>(),
        elapsed_seconds * 1_000.0,
    );
}
