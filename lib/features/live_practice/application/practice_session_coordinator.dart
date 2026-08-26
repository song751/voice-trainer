import 'dart:async';

import '../../../core/domain/analysis/analysis_config.dart';
import '../../../core/domain/analysis/analysis_engine.dart';
import '../../../core/domain/analysis/analysis_frame.dart';
import '../../../core/domain/analysis/analysis_quality_flag.dart';
import '../../../core/domain/analysis/session_summary.dart';
import '../../../core/domain/audio/audio_capture.dart';
import '../../../core/domain/audio/capture_format.dart';
import '../../../core/domain/audio/capture_health.dart';
import '../../../core/domain/audio/pcm_chunk.dart';
import '../../../core/domain/persistence/recording_sink.dart';
import '../../../core/domain/persistence/recording_locator.dart';
import '../../../core/domain/persistence/recording_store.dart';
import '../../../core/domain/persistence/session_repository.dart';
import '../../../core/domain/practice/practice_template.dart';
import '../../../core/errors/failure.dart';
import '../../../core/metrics/p3_performance_observer.dart';
import '../../../core/platform/application_lifecycle.dart';
import '../domain/practice_session_state.dart';
import '../../session_result/application/session_result_calculator.dart';

final class PracticeSessionRequest {
  const PracticeSessionRequest({
    required this.sessionId,
    required this.template,
    required this.startedAt,
    this.captureRequest = const CaptureRequest(),
  });

  final String sessionId;
  final PracticeTemplate template;
  final DateTime startedAt;
  final CaptureRequest captureRequest;
}

final class QueueAccounting {
  const QueueAccounting({
    required this.droppedSamples,
    required this.hasDiscontinuity,
  });

  final int droppedSamples;
  final bool hasDiscontinuity;
}

/// Coordinates domain contracts without depending on UI or concrete adapters.
final class PracticeSessionCoordinator {
  factory PracticeSessionCoordinator({
    required AudioCapture audioCapture,
    required AnalysisEngine analysisEngine,
    required RecordingSink recordingSink,
    required RecordingStore recordingStore,
    required SessionRepository sessionRepository,
    int maxQueuedSamples = 12000,
    P3PerformanceObserver? performanceObserver,
    PracticeSessionStateMachine stateMachine =
        const PracticeSessionStateMachine(),
  }) {
    return PracticeSessionCoordinator._internal(
      audioCapture: audioCapture,
      analysisEngine: analysisEngine,
      recordingSink: recordingSink,
      recordingStore: recordingStore,
      sessionRepository: sessionRepository,
      maxQueuedSamples: maxQueuedSamples,
      performanceObserver:
          performanceObserver ?? P3PerformanceObserver.disabled(),
      stateMachine: stateMachine,
    );
  }

  PracticeSessionCoordinator._internal({
    required this._audioCapture,
    required this._analysisEngine,
    required this._recordingSink,
    required this._recordingStore,
    required this._sessionRepository,
    required this.maxQueuedSamples,
    required this.performanceObserver,
    required this._stateMachine,
  }) : assert(maxQueuedSamples > 0),
       _analysisQueue = _BoundedPcmQueue(maxQueuedSamples),
       _recordingQueue = _BoundedPcmQueue(maxQueuedSamples);

  final AudioCapture _audioCapture;
  final AnalysisEngine _analysisEngine;
  final RecordingSink _recordingSink;
  final RecordingStore _recordingStore;
  final SessionRepository _sessionRepository;
  final PracticeSessionStateMachine _stateMachine;
  final int maxQueuedSamples;
  final P3PerformanceObserver performanceObserver;
  final _BoundedPcmQueue _analysisQueue;
  final _BoundedPcmQueue _recordingQueue;
  final StreamController<AnalysisFrame> _realtimeFrames =
      StreamController<AnalysisFrame>.broadcast(sync: true);
  final StreamController<CaptureHealth> _captureHealth =
      StreamController<CaptureHealth>.broadcast(sync: true);
  final StreamController<AnalysisWorkerMetrics> _workerMetrics =
      StreamController<AnalysisWorkerMetrics>.broadcast(sync: true);
  final StreamController<SessionInterruption> _lifecycleCheckpoints =
      StreamController<SessionInterruption>.broadcast(sync: true);

  PracticeSessionState _state = const Idle();
  PracticeSessionRequest? _request;
  CaptureSession? _captureSession;
  StreamSubscription<PcmChunk>? _chunkSubscription;
  StreamSubscription? _healthSubscription;
  StreamSubscription<AnalysisWorkerMetrics>? _workerMetricsSubscription;
  Future<void>? _failureCleanup;
  bool _analysisDraining = false;
  bool _recordingDraining = false;
  bool _recordingOpen = false;
  int _droppedSamples = 0;
  bool _hasDiscontinuity = false;
  bool _analysisInitialized = false;
  CaptureFormat? _analysisEngineFormat;
  CaptureFormat? _analysisFormat;
  int? _expectedSequenceNumber;
  int? _expectedSampleIndex;
  bool _resumeDiscontinuityPending = false;
  bool _lifecycleTransitioning = false;
  bool _workerInterruptionPending = false;
  int _lastWorkerRestartCount = 0;

  PracticeSessionState get state => _state;

  /// Raw production frames for the next card's UI decimator. Presentation must
  /// not listen to this 100 Hz stream directly.
  Stream<AnalysisFrame> get realtimeFrames => _realtimeFrames.stream;

  Stream<CaptureHealth> get captureHealth => _captureHealth.stream;

  Stream<AnalysisWorkerMetrics> get workerMetrics => _workerMetrics.stream;

  Stream<SessionInterruption> get lifecycleCheckpoints =>
      _lifecycleCheckpoints.stream;

  QueueAccounting get analysisQueueAccounting => QueueAccounting(
    droppedSamples: _droppedSamples,
    hasDiscontinuity: _hasDiscontinuity,
  );

  Future<PracticeSessionState> start(PracticeSessionRequest request) async {
    if (_state is Completed || _state is Failed) {
      await _resetForNextSession();
    }
    if (_state is! Idle) {
      throw InvalidSessionTransition(from: _state.kind.name, event: 'start');
    }
    _request = request;
    _state = _stateMachine.transition(
      _state,
      BeginSession(sessionId: request.sessionId),
    );
    final permission = await _audioCapture.requestPermission();
    switch (permission) {
      case PermissionDenied(:final failure):
        _state = _stateMachine.transition(
          _state,
          PermissionDeniedEvent(failure),
        );
        return _state;
      case PermissionGranted():
        _state = _stateMachine.transition(
          _state,
          const PermissionGrantedEvent(),
        );
    }

    try {
      final captureSession = await _audioCapture.start(request.captureRequest);
      _captureSession = captureSession;
      await _prepareAnalysis(captureSession.effectiveFormat);
      _analysisFormat = captureSession.effectiveFormat;
      await _workerMetricsSubscription?.cancel();
      _workerMetricsSubscription = _analysisEngine.workerMetricsStream.listen((
        metrics,
      ) {
        _observeWorkerRecovery(metrics);
        performanceObserver.onWorkerMetrics(metrics);
        _workerMetrics.add(metrics);
      });
      performanceObserver.onWorkerMetrics(_analysisEngine.workerMetrics);
      _workerMetrics.add(_analysisEngine.workerMetrics);
      _recordingOpen = true;
      await _recordingSink.open(
        RecordingMetadata(
          sessionId: request.sessionId,
          startedAt: request.startedAt,
        ),
      );
      _chunkSubscription = captureSession.pcmChunks.listen(
        _onPcmChunk,
        onError: _onCaptureStreamError,
      );
      _healthSubscription = captureSession.health.listen(_onCaptureHealth);
      _state = _stateMachine.transition(_state, const CaptureStarted());
    } on CaptureFailure catch (failure) {
      _state = _stateMachine.transition(_state, CaptureFailedEvent(failure));
    } on AnalysisFailure catch (failure) {
      await _stopCapture();
      _state = _stateMachine.transition(_state, AnalysisFailedEvent(failure));
    } on PersistenceFailure catch (failure) {
      await _stopCapture();
      await _abortOpenRecording();
      _state = _stateMachine.transition(
        _state,
        PersistenceFailedEvent(failure),
      );
    } catch (_) {
      await _stopCapture();
      await _abortOpenRecording();
      _state = _stateMachine.transition(
        _state,
        CaptureFailedEvent(const CaptureFailure(CaptureFailureReason.unknown)),
      );
    }
    return _state;
  }

  Future<PracticeSessionState> pause() async {
    if (_state is! Running) {
      throw InvalidSessionTransition(from: _state.kind.name, event: 'pause');
    }
    await _pauseCapture();
    _state = _stateMachine.transition(_state, const PauseRequested());
    return _state;
  }

  Future<PracticeSessionState> resume() async {
    if (_state is! Paused) {
      throw InvalidSessionTransition(from: _state.kind.name, event: 'resume');
    }
    final paused = _state as Paused;
    if (paused.interruption case final interruption?
        when !interruption.recoveryReady) {
      throw InvalidSessionTransition(
        from: _state.kind.name,
        event: 'resumeBeforeLifecycleRecovery',
      );
    }
    await _captureSession!.resume();
    _resumeDiscontinuityPending = true;
    _state = _stateMachine.transition(_state, const ResumeRequested());
    return _state;
  }

  Future<PracticeSessionState> stop() async {
    if (_state is Running || _state is Paused) {
      _state = _stateMachine.transition(_state, const StopRequested());
    } else if (_state is Failed) {
      await _stopCapture();
      return _state;
    } else if (_state is! Finalizing) {
      throw InvalidSessionTransition(from: _state.kind.name, event: 'stop');
    }

    await _stopCapture();
    await _waitForQueues();
    if (_state is Failed) {
      return _state;
    }
    return _finalize();
  }

  Future<PracticeSessionState> retry() async {
    if (_state is! Failed) {
      throw InvalidSessionTransition(from: _state.kind.name, event: 'retry');
    }
    _state = _stateMachine.transition(_state, const RetryRequested());
    if (_state is Finalizing) {
      await _waitForQueues();
      return _finalize();
    }
    return _state;
  }

  Future<void> dispose() async {
    await _failureCleanup;
    await _stopCapture();
    await _abortOpenRecording();
    await _analysisEngine.dispose();
    await _workerMetricsSubscription?.cancel();
    await _realtimeFrames.close();
    await _captureHealth.close();
    await _workerMetrics.close();
    await _lifecycleCheckpoints.close();
  }

  /// Applies browser lifecycle signals sequentially to the active session.
  ///
  /// Hidden tabs and suspended/interrupted AudioContexts pause capture and
  /// retain an explicit sample-index checkpoint. Returning to a runnable state
  /// only enables the user-controlled resume action; it never silently resumes
  /// a microphone in the background.
  Future<PracticeSessionState> handleLifecycleEvent(
    ApplicationLifecycleEvent event,
  ) async {
    if (_lifecycleTransitioning) return _state;
    switch (event.kind) {
      case ApplicationLifecycleEventKind.microphonePermissionDenied:
        if (_state is Running || _state is Paused) {
          _state = _stateMachine.transition(
            _state,
            const PermissionDeniedEvent(PermissionDeniedFailure()),
          );
          _scheduleFailureCleanup();
        }
      case ApplicationLifecycleEventKind.pageHidden:
        await _interrupt(SessionInterruptionReason.pageHidden);
      case ApplicationLifecycleEventKind.inputDevicesChanged:
        await _interrupt(
          SessionInterruptionReason.inputDevicesChanged,
          recoveryReady: true,
        );
      case ApplicationLifecycleEventKind.audioContextSuspended:
        await _interrupt(SessionInterruptionReason.audioContextSuspended);
      case ApplicationLifecycleEventKind.audioContextInterrupted:
      case ApplicationLifecycleEventKind.audioContextClosed:
        await _interrupt(SessionInterruptionReason.audioContextInterrupted);
      case ApplicationLifecycleEventKind.workerInterrupted:
        _workerInterruptionPending = true;
        _resumeDiscontinuityPending = true;
        _hasDiscontinuity = true;
        _publishLifecycleCheckpoint(
          SessionInterruption(
            reason: SessionInterruptionReason.workerRestarted,
            sampleIndex: _expectedSampleIndex ?? 0,
            recoveryReady: false,
          ),
        );
      case ApplicationLifecycleEventKind.workerRecovered:
        if (!_workerInterruptionPending) break;
        _workerInterruptionPending = false;
        _resumeDiscontinuityPending = true;
        _hasDiscontinuity = true;
        _publishLifecycleCheckpoint(
          SessionInterruption(
            reason: SessionInterruptionReason.workerRestarted,
            sampleIndex: _expectedSampleIndex ?? 0,
            recoveryReady: true,
          ),
        );
      case ApplicationLifecycleEventKind.pageVisible:
        _markRecoveryReady(SessionInterruptionReason.pageHidden);
      case ApplicationLifecycleEventKind.audioContextRunning:
        _markRecoveryReady(SessionInterruptionReason.audioContextSuspended);
        _markRecoveryReady(SessionInterruptionReason.audioContextInterrupted);
      case ApplicationLifecycleEventKind.microphonePermissionGranted:
      case ApplicationLifecycleEventKind.microphonePermissionPrompt:
        break;
    }
    return _state;
  }

  Future<void> _interrupt(
    SessionInterruptionReason reason, {
    bool recoveryReady = false,
  }) async {
    if (_state is! Running || _captureSession == null) return;
    _lifecycleTransitioning = true;
    try {
      await _pauseCapture();
      _resumeDiscontinuityPending = true;
      _hasDiscontinuity = true;
      final interruption = SessionInterruption(
        reason: reason,
        sampleIndex: _expectedSampleIndex ?? 0,
        recoveryReady: recoveryReady,
      );
      _publishLifecycleCheckpoint(interruption);
      _state = _stateMachine.transition(
        _state,
        PauseRequested(interruption: interruption),
      );
    } catch (_) {
      _state = _stateMachine.transition(
        _state,
        const CaptureFailedEvent(
          CaptureFailure(CaptureFailureReason.streamInterrupted),
        ),
      );
      _scheduleFailureCleanup();
    } finally {
      _lifecycleTransitioning = false;
    }
  }

  Future<void> _pauseCapture() async {
    _lifecycleTransitioning = true;
    try {
      await _captureSession!.pause();
    } finally {
      _lifecycleTransitioning = false;
    }
  }

  void _markRecoveryReady(SessionInterruptionReason reason) {
    final current = _state;
    if (current is Paused &&
        current.interruption?.reason == reason &&
        !(current.interruption?.recoveryReady ?? false)) {
      _state = _stateMachine.transition(
        current,
        const LifecycleRecoveryAvailable(),
      );
    }
  }

  void _observeWorkerRecovery(AnalysisWorkerMetrics metrics) {
    if (metrics.restartCount > _lastWorkerRestartCount) {
      _lastWorkerRestartCount = metrics.restartCount;
      _resumeDiscontinuityPending = true;
      _hasDiscontinuity = true;
      _publishLifecycleCheckpoint(
        SessionInterruption(
          reason: SessionInterruptionReason.workerRestarted,
          sampleIndex: _expectedSampleIndex ?? 0,
          recoveryReady: true,
        ),
      );
    }
    if (metrics.state == AnalysisWorkerState.fallback) {
      _resumeDiscontinuityPending = true;
      _hasDiscontinuity = true;
      _publishLifecycleCheckpoint(
        SessionInterruption(
          reason: SessionInterruptionReason.workerFallback,
          sampleIndex: _expectedSampleIndex ?? 0,
          recoveryReady: true,
        ),
      );
    }
  }

  void _publishLifecycleCheckpoint(SessionInterruption interruption) {
    if (!_lifecycleCheckpoints.isClosed) {
      _lifecycleCheckpoints.add(interruption);
    }
  }

  Future<PracticeSessionState> _finalize() async {
    final request = _request;
    if (request == null || _state is! Finalizing) {
      return _state;
    }
    RecordingLocator? recording;
    try {
      final finalized = await _analysisEngine.finish();
      recording = await _recordingSink.finalize();
      _recordingOpen = false;
      final flags = <AnalysisQualityFlag>{
        ...finalized.segmentSummary.qualityFlags,
      };
      if (_hasDiscontinuity) {
        flags.add(AnalysisQualityFlag.discontinuity);
      }
      if (_droppedSamples > 0) {
        flags.add(AnalysisQualityFlag.droppedSamples);
      }
      final summary = withTargetHitRate(
        segmentSummary: SessionSummary(
          validFrameCount: finalized.segmentSummary.validFrameCount,
          totalFrameCount: finalized.segmentSummary.totalFrameCount,
          droppedSamples: finalized.segmentSummary.droppedSamples,
          pitchStability: finalized.segmentSummary.pitchStability,
          levelStability: finalized.segmentSummary.levelStability,
          onsetDelaySamples: finalized.segmentSummary.onsetDelaySamples,
          qualityFlags: flags,
        ),
        frames: finalized.featureSeries.frames,
        target: request.template.target,
      );
      await _sessionRepository.save(
        PracticeSessionRecord(
          id: request.sessionId,
          template: request.template,
          startedAt: request.startedAt,
          summary: summary,
          features: finalized.featureSeries,
          recording: recording,
        ),
      );
      _state = _stateMachine.transition(_state, const FinalizationSucceeded());
    } on PersistenceFailure catch (failure) {
      await _discardFailedRecording(recording);
      _state = _stateMachine.transition(
        _state,
        PersistenceFailedEvent(failure),
      );
    } catch (_) {
      await _discardFailedRecording(recording);
      _failFinalization(
        const FinalizationFailure(FinalizationFailureReason.unknown),
      );
    }
    return _state;
  }

  Future<void> _discardFailedRecording(RecordingLocator? recording) async {
    if (recording != null) {
      try {
        await _recordingStore.delete(recording);
      } catch (_) {
        // Native sinks also retain enough state to remove a finalized file.
        // Recovery handles any remaining durable tombstone on the next start.
      }
    }
    await _abortOpenRecording();
  }

  Future<void> _resetForNextSession() async {
    await _failureCleanup;
    _failureCleanup = null;
    await _stopCapture();
    await _waitForQueues();
    await _abortOpenRecording();
    _analysisQueue.clear();
    _recordingQueue.clear();
    _request = null;
    _analysisFormat = null;
    _expectedSequenceNumber = null;
    _expectedSampleIndex = null;
    _resumeDiscontinuityPending = false;
    _workerInterruptionPending = false;
    _lastWorkerRestartCount = 0;
    _droppedSamples = 0;
    _hasDiscontinuity = false;
    _state = _stateMachine.transition(_state, const ResetRequested());
  }

  Future<void> _prepareAnalysis(CaptureFormat format) async {
    final initializedFormat = _analysisEngineFormat;
    if (!_analysisInitialized) {
      await _analysisEngine.initialize(AnalysisConfig(inputFormat: format));
      _analysisInitialized = true;
      _analysisEngineFormat = format;
      return;
    }
    if (initializedFormat != format) {
      throw const AnalysisFailure(AnalysisFailureReason.formatChanged);
    }
    try {
      await _analysisEngine.reset();
    } on AnalysisFailure {
      rethrow;
    } catch (_) {
      throw const AnalysisFailure(AnalysisFailureReason.processing);
    }
  }

  Future<void> _abortOpenRecording() async {
    if (!_recordingOpen) return;
    try {
      await _recordingSink.abort();
    } catch (_) {
      // Failure cleanup must not mask the already typed session failure.
    } finally {
      _recordingOpen = false;
    }
  }

  void _scheduleFailureCleanup() {
    if (_failureCleanup != null) return;
    final cleanup = _cleanupFailedSession();
    _failureCleanup = cleanup;
    unawaited(cleanup);
  }

  Future<void> _cleanupFailedSession() async {
    try {
      await _stopCapture();
    } catch (_) {
      // The failed session cannot keep capture ownership into the next start.
    }
    await _waitForQueues();
    await _abortOpenRecording();
  }

  void _onPcmChunk(PcmChunk chunk) {
    if (_state is! Running) {
      return;
    }
    final analysisFormat = _analysisFormat;
    if (analysisFormat == null || chunk.format != analysisFormat) {
      _failAnalysis(const AnalysisFailure(AnalysisFailureReason.formatChanged));
      return;
    }
    final expectedSequence = _expectedSequenceNumber;
    final expectedSample = _expectedSampleIndex;
    final sequenceGap =
        expectedSequence != null && chunk.sequenceNumber != expectedSequence;
    final sampleGap =
        expectedSample != null && chunk.firstSampleIndex != expectedSample;
    final dropped =
        expectedSample != null && chunk.firstSampleIndex > expectedSample
        ? chunk.firstSampleIndex - expectedSample
        : 0;
    chunk.droppedSamplesBefore = dropped;
    chunk.discontinuityBefore =
        _resumeDiscontinuityPending || sequenceGap || sampleGap;
    _resumeDiscontinuityPending = false;
    _expectedSequenceNumber = chunk.sequenceNumber + 1;
    _expectedSampleIndex = chunk.endSampleIndexExclusive;
    _droppedSamples += dropped;
    _hasDiscontinuity = _hasDiscontinuity || chunk.discontinuityBefore;
    performanceObserver.onCaptureChunk(chunk);
    final analysisResult = _analysisQueue.add(chunk);
    _droppedSamples += analysisResult.droppedSamples;
    _hasDiscontinuity = _hasDiscontinuity || analysisResult.droppedSamples > 0;
    final recordingResult = _recordingQueue.add(chunk, dropOldest: false);
    if (!recordingResult.accepted) {
      _state = _stateMachine.transition(
        _state,
        const CaptureFailedEvent(CaptureFailure(CaptureFailureReason.unknown)),
      );
      _scheduleFailureCleanup();
      return;
    }
    performanceObserver.onQueueAccounting(
      analysisDroppedSamples: _droppedSamples,
      recordingDroppedSamples: 0,
    );
    _scheduleAnalysisDrain();
    _scheduleRecordingDrain();
  }

  void _onCaptureHealth(CaptureHealth health) {
    if (!_captureHealth.isClosed) {
      _captureHealth.add(health);
    }
    final analysisFormat = _analysisFormat;
    if (analysisFormat != null && health.effectiveFormat != analysisFormat) {
      _failAnalysis(const AnalysisFailure(AnalysisFailureReason.formatChanged));
    }
  }

  void _onCaptureStreamError(Object error, StackTrace stackTrace) {
    if (_state is Running || _state is Paused) {
      _state = _stateMachine.transition(
        _state,
        const CaptureFailedEvent(
          CaptureFailure(CaptureFailureReason.streamInterrupted),
        ),
      );
      _scheduleFailureCleanup();
    }
  }

  void _scheduleAnalysisDrain() {
    if (_analysisDraining) {
      return;
    }
    _analysisDraining = true;
    unawaited(_drainAnalysis());
  }

  Future<void> _drainAnalysis() async {
    try {
      while (_analysisQueue.isNotEmpty) {
        final chunk = _analysisQueue.removeFirst();
        final result = await _analysisEngine.pushPcm(
          PcmBatch(
            firstSampleIndex: chunk.firstSampleIndex,
            format: chunk.format,
            bytes: chunk.bytes,
            droppedSamplesBefore: chunk.droppedSamplesBefore,
            discontinuityBefore: chunk.discontinuityBefore,
          ),
        );
        for (final frame in result.frames) {
          performanceObserver.onAnalysisPublished(frame);
          if (!_realtimeFrames.isClosed) {
            _realtimeFrames.add(frame);
          }
        }
      }
    } catch (_) {
      if (_state is Finalizing) {
        _failFinalization(
          const FinalizationFailure(FinalizationFailureReason.analysis),
        );
      } else if (_state is Running || _state is Paused) {
        _state = _stateMachine.transition(
          _state,
          const AnalysisFailedEvent(
            AnalysisFailure(AnalysisFailureReason.processing),
          ),
        );
        _scheduleFailureCleanup();
      }
    } finally {
      _analysisDraining = false;
      if (_analysisQueue.isNotEmpty && _state is! Failed) {
        _scheduleAnalysisDrain();
      }
    }
  }

  void _scheduleRecordingDrain() {
    if (_recordingDraining) {
      return;
    }
    _recordingDraining = true;
    unawaited(_drainRecording());
  }

  Future<void> _drainRecording() async {
    try {
      while (_recordingQueue.isNotEmpty) {
        await _recordingSink.append(_recordingQueue.removeFirst());
      }
    } catch (_) {
      _failRecording();
    } finally {
      _recordingDraining = false;
      if (_recordingQueue.isNotEmpty && _state is! Failed) {
        _scheduleRecordingDrain();
      }
    }
  }

  Future<void> _stopCapture() async {
    final captureSession = _captureSession;
    _captureSession = null;
    await _chunkSubscription?.cancel();
    await _healthSubscription?.cancel();
    _chunkSubscription = null;
    _healthSubscription = null;
    if (captureSession != null) {
      await captureSession.stop();
      await captureSession.dispose();
    }
  }

  Future<void> _waitForQueues() async {
    while (_analysisDraining || _recordingDraining) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void _failFinalization(FinalizationFailure failure) {
    if (_state is Finalizing) {
      _state = _stateMachine.transition(_state, FinalizationFailed(failure));
    }
  }

  void _failRecording() {
    if (_state is Finalizing) {
      _failFinalization(
        const FinalizationFailure(FinalizationFailureReason.recording),
      );
      return;
    }
    if (_state is Running || _state is Paused) {
      _state = _stateMachine.transition(
        _state,
        const CaptureFailedEvent(CaptureFailure(CaptureFailureReason.unknown)),
      );
      _scheduleFailureCleanup();
    }
  }

  void _failAnalysis(AnalysisFailure failure) {
    if (_state is Running || _state is Paused) {
      _state = _stateMachine.transition(_state, AnalysisFailedEvent(failure));
      _scheduleFailureCleanup();
    }
  }
}

final class _QueueAddResult {
  const _QueueAddResult({required this.droppedSamples, required this.accepted});

  final int droppedSamples;
  final bool accepted;
}

final class _BoundedPcmQueue {
  _BoundedPcmQueue(this.maximumSamples);

  final int maximumSamples;
  final List<PcmChunk> _chunks = <PcmChunk>[];
  int _queuedSamples = 0;

  bool get isNotEmpty => _chunks.isNotEmpty;

  _QueueAddResult add(PcmChunk chunk, {bool dropOldest = true}) {
    var dropped = 0;
    if (!dropOldest && _queuedSamples + chunk.frameCount > maximumSamples) {
      return const _QueueAddResult(droppedSamples: 0, accepted: false);
    }
    while (_chunks.isNotEmpty &&
        _queuedSamples + chunk.frameCount > maximumSamples) {
      final removed = _chunks.removeAt(0);
      _queuedSamples -= removed.frameCount;
      dropped += removed.frameCount;
    }
    if (chunk.frameCount > maximumSamples) {
      return _QueueAddResult(
        droppedSamples: dropped + chunk.frameCount,
        accepted: false,
      );
    }
    _chunks.add(chunk);
    _queuedSamples += chunk.frameCount;
    return _QueueAddResult(droppedSamples: dropped, accepted: true);
  }

  PcmChunk removeFirst() {
    final chunk = _chunks.removeAt(0);
    _queuedSamples -= chunk.frameCount;
    return chunk;
  }

  void clear() {
    _chunks.clear();
    _queuedSamples = 0;
  }
}
