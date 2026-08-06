use std::{env, time::Instant};

use rust_lib_voice_trainer::pipeline::realtime_analyzer::RealtimeAnalyzerCore;

const SAMPLE_RATE_HZ: u32 = 48_000;
const BATCH_SAMPLES: usize = 1_024;

fn seconds() -> usize {
    env::args()
        .find_map(|argument| argument.strip_prefix("--seconds=")?.parse().ok())
        .unwrap_or(60)
}

fn main() {
    let seconds = seconds();
    let total_samples = seconds * SAMPLE_RATE_HZ as usize;
    let mut analyzer = RealtimeAnalyzerCore::new(SAMPLE_RATE_HZ);
    let mut batch = vec![0_i16; BATCH_SAMPLES];
    let mut offset = 0;
    let mut frame_count = 0;
    let started = Instant::now();
    while offset < total_samples {
        let count = (total_samples - offset).min(BATCH_SAMPLES);
        for (index, sample) in batch[..count].iter_mut().enumerate() {
            let phase =
                std::f32::consts::TAU * 220.0 * (offset + index) as f32 / SAMPLE_RATE_HZ as f32;
            *sample = (phase.sin() * 16_000.0) as i16;
        }
        frame_count += analyzer.push_pcm16(&batch[..count]).len();
        offset += count;
    }
    let elapsed_seconds = started.elapsed().as_secs_f64();
    let realtime_factor = seconds as f64 / elapsed_seconds;
    assert!(
        realtime_factor >= 10.0,
        "realtime factor was {realtime_factor:.2}x"
    );
    println!(
        "{{\"benchmark\":\"realtime_pipeline\",\"sampleRateHz\":{SAMPLE_RATE_HZ},\"seconds\":{seconds},\"batchSamples\":{BATCH_SAMPLES},\"frameCount\":{frame_count},\"elapsedMs\":{:.3},\"realtimeFactor\":{realtime_factor:.3}}}",
        elapsed_seconds * 1_000.0
    );
}
