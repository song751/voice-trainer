import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/errors/failure.dart';
import 'package:voice_trainer/features/live_practice/domain/practice_session_state.dart';

void main() {
  const machine = PracticeSessionStateMachine();

  group('PracticeSessionStateMachine', () {
    test('follows the legal idle-to-completed flow', () {
      PracticeSessionState state = const Idle();

      state = machine.transition(
        state,
        const BeginSession(sessionId: 'session-1'),
      );
      expect(state, isA<RequestingPermission>());

      state = machine.transition(state, const PermissionGrantedEvent());
      expect(state, isA<Ready>());

      state = machine.transition(state, const CaptureStarted());
      expect(state, isA<Running>());

      state = machine.transition(state, const PauseRequested());
      expect(state, isA<Paused>());

      state = machine.transition(state, const ResumeRequested());
      expect(state, isA<Running>());

      state = machine.transition(state, const StopRequested());
      expect(state, isA<Finalizing>());

      state = machine.transition(state, const FinalizationSucceeded());
      expect(state, isA<Completed>());
      expect((state as Completed).sessionId, 'session-1');
    });

    test('rejects an illegal transition with a typed failure', () {
      expect(
        () => machine.transition(const Idle(), const StopRequested()),
        throwsA(
          isA<InvalidSessionTransition>()
              .having((failure) => failure.from, 'from state', 'idle')
              .having(
                (failure) => failure.code,
                'failure code',
                FailureCode.invalidTransition,
              ),
        ),
      );
    });

    test('represents permission denial without a UI string', () {
      final state = machine.transition(
        const RequestingPermission(sessionId: 'session-2'),
        const PermissionDeniedEvent(
          PermissionDeniedFailure(canRequestAgain: true),
        ),
      );

      expect(state, isA<Failed>());
      final failed = state as Failed;
      expect(failed.failure, isA<PermissionDeniedFailure>());
      expect(failed.retryState, PracticeSessionStateKind.requestingPermission);
      expect(failed.canRetry, isTrue);

      final retried = machine.transition(failed, const RetryRequested());
      expect(retried, isA<RequestingPermission>());
    });

    test('recovers from a capture failure at the ready state', () {
      final state = machine.transition(
        const Ready(sessionId: 'session-3'),
        const CaptureFailedEvent(
          CaptureFailure(CaptureFailureReason.streamInterrupted),
        ),
      );

      expect(state, isA<Failed>());
      final failed = state as Failed;
      expect(failed.failure, isA<CaptureFailure>());
      expect(failed.retryState, PracticeSessionStateKind.ready);
      expect(machine.transition(failed, const RetryRequested()), isA<Ready>());
    });

    test('returns to finalizing when a recoverable finalization fails', () {
      final state = machine.transition(
        const Finalizing(sessionId: 'session-4'),
        const FinalizationFailed(
          FinalizationFailure(FinalizationFailureReason.persistence),
        ),
      );

      expect(state, isA<Failed>());
      final failed = state as Failed;
      expect(failed.retryState, PracticeSessionStateKind.finalizing);

      final retried = machine.transition(failed, const RetryRequested());
      expect(retried, isA<Finalizing>());
      expect(
        machine.transition(retried, const FinalizationSucceeded()),
        isA<Completed>(),
      );
    });

    test('does not retry a non-recoverable failure', () {
      const state = Failed(
        sessionId: 'session-5',
        failure: FinalizationFailure(
          FinalizationFailureReason.recording,
          isRecoverable: false,
        ),
        retryState: PracticeSessionStateKind.finalizing,
      );

      expect(
        () => machine.transition(state, const RetryRequested()),
        throwsA(isA<InvalidSessionTransition>()),
      );
    });
  });
}
