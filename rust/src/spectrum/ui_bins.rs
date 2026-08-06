pub const UI_BIN_COUNT: usize = 128;
pub const UI_BIN_MIN_HZ: f32 = 20.0;

pub fn ui_bin_for_frequency(frequency_hz: f32, nyquist_hz: f32) -> Option<usize> {
    if !(UI_BIN_MIN_HZ..=nyquist_hz).contains(&frequency_hz) {
        return None;
    }
    let position = (frequency_hz / UI_BIN_MIN_HZ).ln() / (nyquist_hz / UI_BIN_MIN_HZ).ln();
    Some(
        (position * UI_BIN_COUNT as f32)
            .floor()
            .clamp(0.0, (UI_BIN_COUNT - 1) as f32) as usize,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn log_bins_cover_the_documented_range() {
        assert_eq!(ui_bin_for_frequency(19.9, 24_000.0), None);
        assert_eq!(ui_bin_for_frequency(20.0, 24_000.0), Some(0));
        assert_eq!(ui_bin_for_frequency(24_000.0, 24_000.0), Some(127));
    }
}
