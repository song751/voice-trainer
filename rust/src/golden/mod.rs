//! Deterministic input signals used by the Phase 2 golden harness.
//!
//! This module deliberately describes input truth only.  It does not call the
//! production analyzer or encode its Phase 0 autocorrelation output as an
//! expectation.

mod signals;

pub use signals::{
    generate_case, manifest_cases, pcm16_sha256, BreakpointKind, GoldenCase, GoldenSignal,
    SignalBreakpoint, PCM16_LE_ENCODING,
};
