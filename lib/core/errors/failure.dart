/// Typed failures that can cross domain and application boundaries.
sealed class DomainFailure implements Exception {
  const DomainFailure();

  FailureCode get code;

  bool get isRecoverable;
}

enum FailureCode {
  permissionDenied,
  captureUnavailable,
  captureInterrupted,
  analysisUnavailable,
  recordingUnavailable,
  finalizationFailed,
  persistenceFailed,
  invalidTransition,
}

final class PermissionDeniedFailure extends DomainFailure {
  const PermissionDeniedFailure({this.canRequestAgain = true});

  final bool canRequestAgain;

  @override
  FailureCode get code => FailureCode.permissionDenied;

  @override
  bool get isRecoverable => canRequestAgain;
}

final class CaptureFailure extends DomainFailure {
  const CaptureFailure(this.reason, {this.isRecoverable = true});

  final CaptureFailureReason reason;

  @override
  final bool isRecoverable;

  @override
  FailureCode get code => switch (reason) {
    CaptureFailureReason.deviceUnavailable => FailureCode.captureUnavailable,
    CaptureFailureReason.streamInterrupted ||
    CaptureFailureReason.invalidPcm ||
    CaptureFailureReason.unknown => FailureCode.captureInterrupted,
  };
}

enum CaptureFailureReason {
  deviceUnavailable,
  streamInterrupted,
  invalidPcm,
  unknown,
}

final class AnalysisFailure extends DomainFailure {
  const AnalysisFailure(this.reason, {this.isRecoverable = true});

  final AnalysisFailureReason reason;

  @override
  final bool isRecoverable;

  @override
  FailureCode get code => FailureCode.analysisUnavailable;
}

enum AnalysisFailureReason { processing, unavailable, unknown }

final class FinalizationFailure extends DomainFailure {
  const FinalizationFailure(this.reason, {this.isRecoverable = true});

  final FinalizationFailureReason reason;

  @override
  final bool isRecoverable;

  @override
  FailureCode get code => FailureCode.finalizationFailed;
}

enum FinalizationFailureReason { analysis, recording, persistence, unknown }

final class InvalidSessionTransition extends DomainFailure {
  const InvalidSessionTransition({required this.from, required this.event});

  final String from;
  final String event;

  @override
  FailureCode get code => FailureCode.invalidTransition;

  @override
  bool get isRecoverable => false;
}
