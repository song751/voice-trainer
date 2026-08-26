import '../../../core/errors/failure.dart';

enum SessionInterruptionReason {
  pageHidden,
  inputDevicesChanged,
  audioContextSuspended,
  audioContextInterrupted,
  workerRestarted,
  workerFallback,
}

final class SessionInterruption {
  const SessionInterruption({
    required this.reason,
    required this.sampleIndex,
    required this.recoveryReady,
  });

  final SessionInterruptionReason reason;
  final int sampleIndex;
  final bool recoveryReady;

  SessionInterruption withRecoveryReady() => SessionInterruption(
    reason: reason,
    sampleIndex: sampleIndex,
    recoveryReady: true,
  );
}

enum PracticeSessionStateKind {
  idle,
  requestingPermission,
  ready,
  running,
  paused,
  finalizing,
  completed,
  failed,
}

sealed class PracticeSessionState {
  const PracticeSessionState();

  PracticeSessionStateKind get kind;
}

final class Idle extends PracticeSessionState {
  const Idle();

  @override
  PracticeSessionStateKind get kind => PracticeSessionStateKind.idle;
}

final class RequestingPermission extends PracticeSessionState {
  const RequestingPermission({required this.sessionId});

  final String sessionId;

  @override
  PracticeSessionStateKind get kind =>
      PracticeSessionStateKind.requestingPermission;
}

final class Ready extends PracticeSessionState {
  const Ready({required this.sessionId});

  final String sessionId;

  @override
  PracticeSessionStateKind get kind => PracticeSessionStateKind.ready;
}

final class Running extends PracticeSessionState {
  const Running({required this.sessionId});

  final String sessionId;

  @override
  PracticeSessionStateKind get kind => PracticeSessionStateKind.running;
}

final class Paused extends PracticeSessionState {
  const Paused({required this.sessionId, this.interruption});

  final String sessionId;
  final SessionInterruption? interruption;

  @override
  PracticeSessionStateKind get kind => PracticeSessionStateKind.paused;
}

final class Finalizing extends PracticeSessionState {
  const Finalizing({required this.sessionId});

  final String sessionId;

  @override
  PracticeSessionStateKind get kind => PracticeSessionStateKind.finalizing;
}

final class Completed extends PracticeSessionState {
  const Completed({required this.sessionId});

  final String sessionId;

  @override
  PracticeSessionStateKind get kind => PracticeSessionStateKind.completed;
}

final class Failed extends PracticeSessionState {
  const Failed({
    required this.sessionId,
    required this.failure,
    required this.retryState,
  });

  final String sessionId;
  final DomainFailure failure;
  final PracticeSessionStateKind retryState;

  bool get canRetry => failure.isRecoverable;

  @override
  PracticeSessionStateKind get kind => PracticeSessionStateKind.failed;
}

sealed class PracticeSessionEvent {
  const PracticeSessionEvent();
}

final class BeginSession extends PracticeSessionEvent {
  const BeginSession({required this.sessionId});

  final String sessionId;
}

final class PermissionGrantedEvent extends PracticeSessionEvent {
  const PermissionGrantedEvent();
}

final class PermissionDeniedEvent extends PracticeSessionEvent {
  const PermissionDeniedEvent(this.failure);

  final PermissionDeniedFailure failure;
}

final class CaptureStarted extends PracticeSessionEvent {
  const CaptureStarted();
}

final class PauseRequested extends PracticeSessionEvent {
  const PauseRequested({this.interruption});

  final SessionInterruption? interruption;
}

final class LifecycleRecoveryAvailable extends PracticeSessionEvent {
  const LifecycleRecoveryAvailable();
}

final class ResumeRequested extends PracticeSessionEvent {
  const ResumeRequested();
}

final class StopRequested extends PracticeSessionEvent {
  const StopRequested();
}

final class CaptureFailedEvent extends PracticeSessionEvent {
  const CaptureFailedEvent(this.failure);

  final CaptureFailure failure;
}

final class AnalysisFailedEvent extends PracticeSessionEvent {
  const AnalysisFailedEvent(this.failure);

  final AnalysisFailure failure;
}

final class PersistenceFailedEvent extends PracticeSessionEvent {
  const PersistenceFailedEvent(this.failure);

  final PersistenceFailure failure;
}

final class RecordingFailedEvent extends PracticeSessionEvent {
  const RecordingFailedEvent(this.failure);

  final RecordingFailure failure;
}

final class FinalizationSucceeded extends PracticeSessionEvent {
  const FinalizationSucceeded();
}

final class FinalizationFailed extends PracticeSessionEvent {
  const FinalizationFailed(this.failure);

  final FinalizationFailure failure;
}

final class RetryRequested extends PracticeSessionEvent {
  const RetryRequested();
}

final class ResetRequested extends PracticeSessionEvent {
  const ResetRequested();
}

final class PracticeSessionStateMachine {
  const PracticeSessionStateMachine();

  PracticeSessionState transition(
    PracticeSessionState state,
    PracticeSessionEvent event,
  ) {
    return switch ((state, event)) {
      (Idle(), BeginSession(:final sessionId)) => RequestingPermission(
        sessionId: sessionId,
      ),
      (RequestingPermission(:final sessionId), PermissionGrantedEvent()) =>
        Ready(sessionId: sessionId),
      (
        RequestingPermission(:final sessionId),
        PermissionDeniedEvent(:final failure),
      ) =>
        Failed(
          sessionId: sessionId,
          failure: failure,
          retryState: PracticeSessionStateKind.requestingPermission,
        ),
      (Ready(:final sessionId), CaptureStarted()) => Running(
        sessionId: sessionId,
      ),
      (Ready(:final sessionId), CaptureFailedEvent(:final failure)) => Failed(
        sessionId: sessionId,
        failure: failure,
        retryState: PracticeSessionStateKind.ready,
      ),
      (Ready(:final sessionId), AnalysisFailedEvent(:final failure)) => Failed(
        sessionId: sessionId,
        failure: failure,
        retryState: PracticeSessionStateKind.ready,
      ),
      (Ready(:final sessionId), PersistenceFailedEvent(:final failure)) =>
        Failed(
          sessionId: sessionId,
          failure: failure,
          retryState: PracticeSessionStateKind.ready,
        ),
      (Ready(:final sessionId), RecordingFailedEvent(:final failure)) => Failed(
        sessionId: sessionId,
        failure: failure,
        retryState: PracticeSessionStateKind.ready,
      ),
      (Running(:final sessionId), PauseRequested(:final interruption)) =>
        Paused(sessionId: sessionId, interruption: interruption),
      (
        Paused(:final sessionId, :final interruption),
        LifecycleRecoveryAvailable(),
      )
          when interruption != null =>
        Paused(
          sessionId: sessionId,
          interruption: interruption.withRecoveryReady(),
        ),
      (Paused(:final sessionId), ResumeRequested()) => Running(
        sessionId: sessionId,
      ),
      (Running(:final sessionId), StopRequested()) ||
      (
        Paused(:final sessionId),
        StopRequested(),
      ) => Finalizing(sessionId: sessionId),
      (Running(:final sessionId), CaptureFailedEvent(:final failure)) ||
      (Paused(:final sessionId), CaptureFailedEvent(:final failure)) => Failed(
        sessionId: sessionId,
        failure: failure,
        retryState: PracticeSessionStateKind.ready,
      ),
      (Running(:final sessionId), PermissionDeniedEvent(:final failure)) ||
      (
        Paused(:final sessionId),
        PermissionDeniedEvent(:final failure),
      ) => Failed(
        sessionId: sessionId,
        failure: failure,
        retryState: PracticeSessionStateKind.requestingPermission,
      ),
      (Running(:final sessionId), AnalysisFailedEvent(:final failure)) ||
      (Paused(:final sessionId), AnalysisFailedEvent(:final failure)) => Failed(
        sessionId: sessionId,
        failure: failure,
        retryState: PracticeSessionStateKind.ready,
      ),
      (Running(:final sessionId), RecordingFailedEvent(:final failure)) ||
      (
        Paused(:final sessionId),
        RecordingFailedEvent(:final failure),
      ) => Failed(
        sessionId: sessionId,
        failure: failure,
        retryState: PracticeSessionStateKind.ready,
      ),
      (Running(:final sessionId), PersistenceFailedEvent(:final failure)) ||
      (
        Paused(:final sessionId),
        PersistenceFailedEvent(:final failure),
      ) => Failed(
        sessionId: sessionId,
        failure: failure,
        retryState: PracticeSessionStateKind.ready,
      ),
      (Finalizing(:final sessionId), FinalizationSucceeded()) => Completed(
        sessionId: sessionId,
      ),
      (Finalizing(:final sessionId), FinalizationFailed(:final failure)) =>
        Failed(
          sessionId: sessionId,
          failure: failure,
          retryState: PracticeSessionStateKind.finalizing,
        ),
      (Finalizing(:final sessionId), PersistenceFailedEvent(:final failure)) =>
        Failed(
          sessionId: sessionId,
          failure: failure,
          retryState: PracticeSessionStateKind.finalizing,
        ),
      (Finalizing(:final sessionId), RecordingFailedEvent(:final failure)) =>
        Failed(
          sessionId: sessionId,
          failure: failure,
          retryState: PracticeSessionStateKind.finalizing,
        ),
      (
        Failed(:final sessionId, :final retryState, :final canRetry),
        RetryRequested(),
      )
          when canRetry =>
        _retry(sessionId, retryState),
      (Completed(), ResetRequested()) ||
      (Failed(), ResetRequested()) => const Idle(),
      _ => throw InvalidSessionTransition(
        from: state.kind.name,
        event: event.runtimeType.toString(),
      ),
    };
  }

  PracticeSessionState _retry(
    String sessionId,
    PracticeSessionStateKind retryState,
  ) {
    return switch (retryState) {
      PracticeSessionStateKind.requestingPermission => RequestingPermission(
        sessionId: sessionId,
      ),
      PracticeSessionStateKind.ready => Ready(sessionId: sessionId),
      PracticeSessionStateKind.finalizing => Finalizing(sessionId: sessionId),
      _ => throw InvalidSessionTransition(
        from: PracticeSessionStateKind.failed.name,
        event: (const RetryRequested()).runtimeType.toString(),
      ),
    };
  }
}
