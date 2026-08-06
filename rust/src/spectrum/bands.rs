pub const BAND_POWER_COUNT: usize = 8;
pub const BAND_EDGES_HZ: [f32; BAND_POWER_COUNT + 1] = [
    0.0, 250.0, 500.0, 1_000.0, 2_000.0, 4_000.0, 8_000.0, 12_000.0, 24_000.0,
];

pub fn band_index_for_frequency(frequency_hz: f32) -> Option<usize> {
    (BAND_EDGES_HZ[0]..=BAND_EDGES_HZ[BAND_POWER_COUNT])
        .contains(&frequency_hz)
        .then(|| {
            BAND_EDGES_HZ
                .windows(2)
                .position(|edge| frequency_hz >= edge[0] && frequency_hz < edge[1])
                .unwrap_or(BAND_POWER_COUNT - 1)
        })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn frequencies_at_band_edges_have_a_single_owner() {
        assert_eq!(band_index_for_frequency(0.0), Some(0));
        assert_eq!(band_index_for_frequency(250.0), Some(1));
        assert_eq!(band_index_for_frequency(24_000.0), Some(7));
        assert_eq!(band_index_for_frequency(24_000.1), None);
    }
}
