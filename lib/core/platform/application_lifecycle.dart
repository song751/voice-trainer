enum ApplicationLifecyclePhase { foreground, background, detached }

/// Browser lifecycle facts that can affect an active recording.
///
/// Flutter's widget lifecycle maps to [ApplicationLifecyclePhase]. Web also
/// exposes permission, input-device, AudioContext, and worker facts that need
/// a richer typed event without importing browser APIs into application code.
enum ApplicationLifecycleEventKind {
  pageHidden,
  pageVisible,
  microphonePermissionGranted,
  microphonePermissionPrompt,
  microphonePermissionDenied,
  inputDevicesChanged,
  audioContextRunning,
  audioContextSuspended,
  audioContextInterrupted,
  audioContextClosed,
  workerInterrupted,
  workerRecovered,
}

final class ApplicationLifecycleEvent {
  const ApplicationLifecycleEvent({required this.kind, this.detail});

  final ApplicationLifecycleEventKind kind;

  /// A bounded, non-identifying platform value such as an AudioContext state.
  /// Device ids, labels and browser profile paths must never be placed here.
  final String? detail;
}

abstract interface class ApplicationLifecycle {
  Stream<ApplicationLifecycleEvent> get events;

  Future<void> initialize();

  Future<void> dispose();
}

final class InactiveApplicationLifecycle implements ApplicationLifecycle {
  const InactiveApplicationLifecycle();

  @override
  Stream<ApplicationLifecycleEvent> get events => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}
}
