import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/errors/app_exception.dart';
import 'package:voice_trainer/core/errors/failure.dart';

void main() {
  const mapper = AppErrorMapper();

  test('preserves an existing typed domain failure', () {
    const failure = PermissionDeniedFailure(canRequestAgain: false);

    final mapped = mapper.map(failure, operation: FailureOperation.capture);

    expect(mapped.failure, same(failure));
    expect(mapped.sourceType, 'PermissionDeniedFailure');
  });

  test(
    'maps infrastructure errors by operation without retaining messages',
    () {
      final cases = <FailureOperation, FailureCode>{
        FailureOperation.capture: FailureCode.captureInterrupted,
        FailureOperation.analysis: FailureCode.analysisUnavailable,
        FailureOperation.recording: FailureCode.recordingUnavailable,
        FailureOperation.persistence: FailureCode.persistenceFailed,
        FailureOperation.finalization: FailureCode.finalizationFailed,
        FailureOperation.unknown: FailureCode.unexpected,
      };

      for (final entry in cases.entries) {
        final mapped = mapper.map(
          StateError(r'D:\private\recording.wav'),
          operation: entry.key,
        );
        expect(mapped.failure.code, entry.value);
        expect(mapped.sourceType, 'StateError');
        expect(mapped.toString(), isNot(contains('recording.wav')));
      }
    },
  );

  test('does not remap an existing app exception', () {
    const exception = AppException(
      failure: UnexpectedFailure(),
      operation: FailureOperation.unknown,
      sourceType: 'TestError',
    );

    expect(mapper.map(exception), same(exception));
  });
}
