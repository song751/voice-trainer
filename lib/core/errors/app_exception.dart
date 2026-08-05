import 'failure.dart';

enum FailureOperation {
  capture,
  analysis,
  recording,
  persistence,
  finalization,
  unknown,
}

/// Sanitized error envelope shared by application entry points.
///
/// It intentionally retains only a typed failure and the source type. Raw
/// exception messages can contain paths, device identifiers, or user data and
/// must not cross into presentation or logging by default.
final class AppException implements Exception {
  const AppException({
    required this.failure,
    required this.operation,
    required this.sourceType,
  });

  final DomainFailure failure;
  final FailureOperation operation;
  final String sourceType;
}

/// Maps plugin, persistence, worker, and unknown errors to domain-safe values.
final class AppErrorMapper {
  const AppErrorMapper();

  AppException map(
    Object error, {
    FailureOperation operation = FailureOperation.unknown,
  }) {
    if (error is AppException) return error;

    final failure = error is DomainFailure
        ? error
        : switch (operation) {
            FailureOperation.capture => const CaptureFailure(
              CaptureFailureReason.unknown,
            ),
            FailureOperation.analysis => const AnalysisFailure(
              AnalysisFailureReason.unknown,
            ),
            FailureOperation.recording => const RecordingFailure(),
            FailureOperation.persistence => const PersistenceFailure(),
            FailureOperation.finalization => const FinalizationFailure(
              FinalizationFailureReason.unknown,
            ),
            FailureOperation.unknown => const UnexpectedFailure(),
          };

    return AppException(
      failure: failure,
      operation: operation,
      sourceType: error.runtimeType.toString(),
    );
  }
}
