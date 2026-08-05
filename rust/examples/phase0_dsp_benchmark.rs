use std::time::Instant;

use rust_lib_voice_trainer::pipeline::realtime_analyzer::RealtimeAnalyzerCore;

const SAMPLE_RATE: usize = 48_000;
const SIMULATED_SECONDS: usize = 600;

fn main() {
    for batch_size in [512, 1024, 2048] {
        let mut analyzer = RealtimeAnalyzerCore::new(SAMPLE_RATE as u32);
        let mut phase = 0_u64;
        let total_samples = SAMPLE_RATE * SIMULATED_SECONDS;
        let started = Instant::now();
        let mut frame_count = 0;
        for offset in (0..total_samples).step_by(batch_size) {
            let count = batch_size.min(total_samples - offset);
            let batch: Vec<i16> = (0..count)
                .map(|_| {
                    let value =
                        (std::f64::consts::TAU * 220.0 * phase as f64 / SAMPLE_RATE as f64).sin();
                    phase += 1;
                    (value * 16_000.0) as i16
                })
                .collect();
            frame_count += analyzer.push_pcm16(&batch).len();
        }
        let elapsed = started.elapsed();
        println!(
            "batch={batch_size} simulated_seconds={SIMULATED_SECONDS} frames={frame_count} elapsed_ms={} realtime_multiple={:.2}",
            elapsed.as_millis(),
            SIMULATED_SECONDS as f64 / elapsed.as_secs_f64()
        );
    }
}
