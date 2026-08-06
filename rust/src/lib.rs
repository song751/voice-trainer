pub mod api;
#[cfg(feature = "frb")]
mod features;
#[cfg(not(feature = "frb"))]
pub mod features;
mod frb_generated;
#[cfg(feature = "frb")]
mod golden;
#[cfg(not(feature = "frb"))]
pub mod golden;
#[cfg(feature = "frb")]
mod model;
#[cfg(not(feature = "frb"))]
pub mod model;
#[cfg(feature = "frb")]
mod pipeline;
#[cfg(not(feature = "frb"))]
pub mod pipeline;
#[cfg(feature = "frb")]
mod pitch;
#[cfg(not(feature = "frb"))]
pub mod pitch;
#[cfg(feature = "frb")]
mod signal;
#[cfg(not(feature = "frb"))]
pub mod signal;
#[cfg(feature = "frb")]
mod spectrum;
#[cfg(not(feature = "frb"))]
pub mod spectrum;

#[cfg(target_family = "wasm")]
mod web_worker;
