/// Stable platform facts consumed by application composition and presentation.
///
/// This value object deliberately contains no platform detection or plugin
/// imports. A conditional composition adapter selects one of these profiles.
enum PlatformTarget { windows, android, web, otherNative }

enum PlatformAdapterMode { production, fallback }

enum AnalysisWorkerCapability { nativeWorker, dedicatedWebWorker, fallback }

final class PlatformCapabilities {
  const PlatformCapabilities({
    required this.target,
    required this.capture,
    required this.persistence,
    required this.analysisWorker,
    required this.maximumRecordingDuration,
    required this.supportsDeviceSelection,
    required this.supportsLifecycleEvents,
  });

  static const windows = PlatformCapabilities(
    target: PlatformTarget.windows,
    capture: PlatformAdapterMode.production,
    persistence: PlatformAdapterMode.production,
    analysisWorker: AnalysisWorkerCapability.nativeWorker,
    maximumRecordingDuration: null,
    supportsDeviceSelection: true,
    supportsLifecycleEvents: false,
  );

  /// P4-04 promotes Android persistence to the shared native Drift/WAV stack;
  /// P4-05 adds application-level lifecycle handling.
  static const android = PlatformCapabilities(
    target: PlatformTarget.android,
    capture: PlatformAdapterMode.production,
    persistence: PlatformAdapterMode.production,
    analysisWorker: AnalysisWorkerCapability.nativeWorker,
    maximumRecordingDuration: null,
    supportsDeviceSelection: false,
    supportsLifecycleEvents: true,
  );

  /// P4-09 promotes Web capture and the dedicated Rust WASM worker. P4-10
  /// promotes durable Drift/recording persistence while retaining the 60-second
  /// sample-timeline limit. P4-11 adds the browser lifecycle observer.
  static const web = PlatformCapabilities(
    target: PlatformTarget.web,
    capture: PlatformAdapterMode.production,
    persistence: PlatformAdapterMode.production,
    analysisWorker: AnalysisWorkerCapability.dedicatedWebWorker,
    maximumRecordingDuration: Duration(seconds: 60),
    supportsDeviceSelection: false,
    supportsLifecycleEvents: true,
  );

  static const otherNative = PlatformCapabilities(
    target: PlatformTarget.otherNative,
    capture: PlatformAdapterMode.fallback,
    persistence: PlatformAdapterMode.fallback,
    analysisWorker: AnalysisWorkerCapability.fallback,
    maximumRecordingDuration: null,
    supportsDeviceSelection: false,
    supportsLifecycleEvents: false,
  );

  final PlatformTarget target;
  final PlatformAdapterMode capture;
  final PlatformAdapterMode persistence;
  final AnalysisWorkerCapability analysisWorker;
  final Duration? maximumRecordingDuration;
  final bool supportsDeviceSelection;
  final bool supportsLifecycleEvents;
}
