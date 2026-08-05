#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init, sync)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

// FRB's generated default handler always wraps the WASM pool in a LocalKey,
// even when its `thread-pool` feature is disabled. Supplying the documented
// custom handler avoids that upstream 2.12 mismatch and uses the no-op pool on
// Web. Native resolves the same type to FRB's real thread pool.
flutter_rust_bridge::for_generated::lazy_static! {
    pub static ref FLUTTER_RUST_BRIDGE_HANDLER: flutter_rust_bridge::DefaultHandler<
        flutter_rust_bridge::for_generated::SimpleThreadPool,
    > = flutter_rust_bridge::DefaultHandler::new_simple(Default::default());
}
