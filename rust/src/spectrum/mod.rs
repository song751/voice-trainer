//! Full-band, 48 kHz spectral analysis primitives.

mod bands;
mod stft;
mod ui_bins;

pub use bands::{band_index_for_frequency, BAND_EDGES_HZ, BAND_POWER_COUNT};
pub use stft::{SpectrumAnalyzer, SpectrumFrame, SPECTRUM_HOP_SIZE, SPECTRUM_WINDOW_SIZE};
pub use ui_bins::{ui_bin_for_frequency, UI_BIN_COUNT, UI_BIN_MIN_HZ};
