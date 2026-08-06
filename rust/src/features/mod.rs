//! Frame-quality gates and bounded segment-level acoustic summaries.

mod onset;
mod quality;
mod segment;
mod stability;

pub use onset::{OnsetDetector, OnsetSettings};
pub use quality::{FeatureInput, QualityConfig, QualityFlags};
pub use segment::{SegmentAggregator, SegmentConfig, SegmentSummary};
pub use stability::{level_stability, pitch_stability, RobustStability};
