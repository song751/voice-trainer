use std::collections::VecDeque;

use crate::{
    features::{FeatureInput, QualityConfig, SegmentAggregator, SegmentConfig, SegmentSummary},
    model::AnalysisFrame,
    pitch::{PitchFrame, PitchTracker, VoicedDecisionConfig, YinEstimator},
    signal::{pcm::pcm16_to_f32, ring_buffer::RingBuffer},
    spectrum::{SpectrumAnalyzer, SpectrumFrame, SPECTRUM_HOP_SIZE, SPECTRUM_WINDOW_SIZE},
};

/// The only production DSP composition. It deliberately contains no capture,
/// wall-clock, persistence, or UI concerns: callers provide the monotonic PCM
/// sample position and this core derives every analysis timestamp from it.
pub struct RealtimeAnalyzerCore {
    spectrum: SpectrumAnalyzer,
    pitch: PitchTracker<YinEstimator>,
    segment: SegmentAggregator,
    quality_window: RingBuffer<f32>,
    quality_frame_buffer: Vec<f32>,
    sample_scratch: Vec<f32>,
    pending_full_band: VecDeque<PendingFullBandFrame>,
    pending_pitch: VecDeque<PitchFrame>,
    next_full_band_start: u64,
    epoch_start_sample: Option<u64>,
    next_input_sample: Option<u64>,
    pending_dropped_quality: bool,
    pending_discontinuity: bool,
}

#[derive(Clone, Debug)]
struct PendingFullBandFrame {
    spectrum: SpectrumFrame,
    feature: FeatureInput,
}

impl RealtimeAnalyzerCore {
    pub const SAMPLE_RATE_HZ: u32 = 48_000;

    pub fn new(sample_rate: u32) -> Self {
        assert_eq!(
            sample_rate,
            Self::SAMPLE_RATE_HZ,
            "production DSP currently requires 48 kHz PCM16 mono"
        );
        Self {
            spectrum: SpectrumAnalyzer::new(),
            pitch: PitchTracker::new(YinEstimator, VoicedDecisionConfig::default()),
            segment: SegmentAggregator::new(SegmentConfig::default()),
            quality_window: RingBuffer::new(SPECTRUM_WINDOW_SIZE + SPECTRUM_HOP_SIZE),
            quality_frame_buffer: vec![0.0; SPECTRUM_WINDOW_SIZE],
            sample_scratch: Vec::with_capacity(1_024),
            pending_full_band: VecDeque::with_capacity(2),
            pending_pitch: VecDeque::with_capacity(2),
            next_full_band_start: 0,
            epoch_start_sample: None,
            next_input_sample: None,
            pending_dropped_quality: false,
            pending_discontinuity: false,
        }
    }

    /// Push PCM16 at its capture-sample position. A forward index gap restarts
    /// only streaming windows and is carried into quality/segment evidence.
    pub fn push_pcm16_at(&mut self, start_sample: u64, pcm: &[i16]) -> Vec<AnalysisFrame> {
        self.push_pcm16_with_metadata(start_sample, pcm, 0, false)
    }

    pub fn push_pcm16_with_metadata(
        &mut self,
        start_sample: u64,
        pcm: &[i16],
        dropped_samples_before: u32,
        discontinuity_before: bool,
    ) -> Vec<AnalysisFrame> {
        if pcm.is_empty() {
            return Vec::new();
        }
        match self.next_input_sample {
            None => self.epoch_start_sample = Some(start_sample),
            Some(expected) if start_sample == expected && !discontinuity_before && dropped_samples_before == 0 => {}
            Some(expected) if start_sample == expected => {
                self.restart_after_discontinuity(start_sample, dropped_samples_before as u64);
            }
            Some(expected) if start_sample > expected => {
                self.restart_after_discontinuity(
                    start_sample,
                    (start_sample - expected).max(dropped_samples_before as u64),
                );
            }
            Some(expected) => panic!(
                "PCM sample timeline moved backwards: expected at least {expected}, got {start_sample}"
            ),
        }

        self.sample_scratch.clear();
        self.sample_scratch
            .extend(pcm.iter().copied().map(pcm16_to_f32));
        let spectrum_frames = self.spectrum.push(&self.sample_scratch);
        let quality_features = self.push_quality_windows();
        debug_assert_eq!(spectrum_frames.len(), quality_features.len());
        for (spectrum, feature) in spectrum_frames.into_iter().zip(quality_features) {
            debug_assert_eq!(spectrum.start_sample, feature.start_sample);
            self.pending_full_band
                .push_back(PendingFullBandFrame { spectrum, feature });
        }
        self.pending_pitch
            .extend(self.pitch.push(&self.sample_scratch));
        self.next_input_sample = Some(start_sample + pcm.len() as u64);
        self.emit_matched_frames()
    }

    /// Compatibility helper for deterministic unit callers. Production bridge
    /// entries must call [`Self::push_pcm16_at`] so capture positions remain
    /// explicit instead of being reconstructed per batch.
    pub fn push_pcm16(&mut self, pcm: &[i16]) -> Vec<AnalysisFrame> {
        self.push_pcm16_at(self.next_input_sample(), pcm)
    }

    pub fn next_input_sample(&self) -> u64 {
        self.next_input_sample.unwrap_or(0)
    }

    /// Returns the summary for all fully composed 100 Hz frames received so
    /// far. It does not fabricate tail frames by padding incomplete windows.
    pub fn finish(&mut self) -> SegmentSummary {
        std::mem::replace(
            &mut self.segment,
            SegmentAggregator::new(SegmentConfig::default()),
        )
        .finish()
    }

    pub fn reset(&mut self) {
        self.spectrum.reset();
        self.pitch.reset();
        self.segment = SegmentAggregator::new(SegmentConfig::default());
        self.quality_window.clear();
        self.sample_scratch.clear();
        self.pending_full_band.clear();
        self.pending_pitch.clear();
        self.next_full_band_start = 0;
        self.epoch_start_sample = None;
        self.next_input_sample = None;
        self.pending_dropped_quality = false;
        self.pending_discontinuity = false;
    }

    fn push_quality_windows(&mut self) -> Vec<FeatureInput> {
        let expected_frame_count = (self.quality_window.len() + self.sample_scratch.len())
            .saturating_sub(SPECTRUM_WINDOW_SIZE)
            .checked_div(SPECTRUM_HOP_SIZE)
            .unwrap_or(0)
            + usize::from(
                self.quality_window.len() + self.sample_scratch.len() >= SPECTRUM_WINDOW_SIZE,
            );
        let mut features = Vec::with_capacity(expected_frame_count);
        for &sample in &self.sample_scratch {
            let overwritten = self.quality_window.push(sample);
            debug_assert!(
                overwritten.is_none(),
                "quality windows must keep pace with STFT"
            );
            if self.quality_window.len() >= SPECTRUM_WINDOW_SIZE {
                self.quality_window
                    .copy_oldest_into(&mut self.quality_frame_buffer);
                features.push(FeatureInput::from_samples(
                    self.next_full_band_start,
                    SPECTRUM_HOP_SIZE as u32,
                    &self.quality_frame_buffer,
                    None,
                    false,
                ));
                self.quality_window.discard_oldest(SPECTRUM_HOP_SIZE);
                self.next_full_band_start += SPECTRUM_HOP_SIZE as u64;
            }
        }
        features
    }

    fn emit_matched_frames(&mut self) -> Vec<AnalysisFrame> {
        let mut frames = Vec::with_capacity(self.pending_pitch.len());
        let base = self
            .epoch_start_sample
            .expect("timeline is initialized before output");
        while let (Some(full_band), Some(pitch)) =
            (self.pending_full_band.front(), self.pending_pitch.front())
        {
            assert_eq!(
                full_band.spectrum.start_sample, pitch.start_sample,
                "P2 pitch and spectrum branches must share the 100 Hz sample timeline"
            );
            let full_band = self.pending_full_band.pop_front().expect("front checked");
            let pitch = self.pending_pitch.pop_front().expect("front checked");
            let mut feature = full_band.feature;
            feature.start_sample += base;
            feature.frequency_hz = pitch.frequency_hz;
            feature.voiced = pitch.voiced;
            feature.dropped_samples = 0;
            feature.discontinuity = self.pending_discontinuity;
            let add_dropped_quality = self.pending_dropped_quality;
            self.pending_dropped_quality = false;
            self.pending_discontinuity = false;
            let mut quality_flags = feature.quality_flags(QualityConfig::default()).bits();
            if add_dropped_quality {
                quality_flags |= crate::features::QualityFlags::DROPPED_SAMPLES.bits();
            }
            self.segment.push(feature);
            frames.push(AnalysisFrame {
                start_sample: full_band.spectrum.start_sample + base,
                rms: dbfs_to_amplitude(full_band.feature.rms_dbfs),
                peak: dbfs_to_amplitude(full_band.feature.peak_dbfs),
                spectral_centroid_hz: full_band.spectrum.spectral_centroid_hz,
                pitch_hz: pitch.frequency_hz,
                pitch_clarity: pitch.clarity,
                band_powers_dbfs: full_band.spectrum.band_powers_dbfs,
                quality_flags,
            });
        }
        frames
    }

    fn restart_after_discontinuity(&mut self, start_sample: u64, dropped_samples: u64) {
        self.spectrum.reset();
        self.pitch.reset();
        self.quality_window.clear();
        self.pending_full_band.clear();
        self.pending_pitch.clear();
        self.next_full_band_start = 0;
        self.epoch_start_sample = Some(start_sample);
        self.segment
            .mark_discontinuity(dropped_samples, start_sample);
        self.pending_dropped_quality = dropped_samples > 0;
        self.pending_discontinuity = true;
    }
}

fn dbfs_to_amplitude(dbfs: f32) -> f32 {
    if dbfs <= -120.0 {
        0.0
    } else {
        10.0_f32.powf(dbfs / 20.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sine(sample_count: usize, frequency: f32) -> Vec<i16> {
        (0..sample_count)
            .map(|index| {
                let phase = std::f32::consts::TAU * frequency * index as f32 / 48_000.0;
                (phase.sin() * 16_000.0) as i16
            })
            .collect()
    }

    #[test]
    fn composes_yin_spectrum_and_quality_on_one_timeline() {
        let mut analyzer = RealtimeAnalyzerCore::new(48_000);
        let frames = analyzer.push_pcm16_at(12_000, &sine(48_000, 220.0));
        assert!(frames.iter().all(|frame| frame.pitch_hz.is_some()));
        assert!(frames
            .windows(2)
            .all(|pair| pair[1].start_sample - pair[0].start_sample == 480));
        assert_eq!(frames[0].start_sample, 12_000);
        assert!(frames[0].rms > 0.3);
        assert!(frames[0].peak > 0.45);
        assert!(analyzer.finish().valid_frame_count >= 30);
    }
}
