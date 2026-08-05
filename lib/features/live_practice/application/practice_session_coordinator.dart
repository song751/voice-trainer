import 'dart:async';

import '../../../core/domain/analysis/analysis_config.dart';
import '../../../core/domain/analysis/analysis_engine.dart';
import '../../../core/domain/analysis/analysis_quality_flag.dart';
import '../../../core/domain/analysis/session_summary.dart';
import '../../../core/domain/audio/audio_capture.dart';
import '../../../core/domain/audio/pcm_chunk.dart';
import '../../../core/domain/persistence/recording_sink.dart';
import '../../../core/domain/persistence/session_repository.dart';
import '../../../core/domain/practice/practice_template.dart';
import '../../../core/errors/failure.dart';
import '../domain/practice_session_state.dart';

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
    required SessionRepository sessionRepository,
    int maxQueuedSamples = 12000,
    PracticeSessionStateMachine stateMachine =
        const PracticeSessionStateMachine(),
  }) {
    return PracticeSessionCoordinator._internal(
      audioCapture: audioCapture,
      analysisEngine: analysisEngine,
      recordingSink: recordingSink,
      sessionRepository: sessionRepository,
      maxQueuedSamples: maxQueuedSamples,
      stateMachine: stateMachine,
    );
  }

  PracticeSessionCoordinator._internal({
    required this._audioCapture,
    required this._analysisEngine,
    required this._recordingSink,
    required this._sessionRepository,
    required this.maxQueuedSamples,
    required this._stateMachine,
  }) : assert(maxQueuedSamples > 0),
       _analysisQueue = _BoundedPcmQueue(maxQueuedSamples),
       _recordingQueue = _BoundedPcmQueue(maxQueuedSamples);

  final AudioCapture _audioCapture;
  final AnalysisEngine _analysisEngine;
  final RecordingSink _recordingSink;
  final SessionRepository _sessionRepository;
  final PracticeSessionStateMachine _stateMachine;
  final int maxQueuedSamples;
  final _BoundedPcmQueue _analysisQueue;
  final _BoundedPcmQueue _recordingQueue;

  PracticeSessionState _state = const Idle();
  PracticeSessionRequest? _request;
  CaptureSession? _captureSession;
  StreamSubscription<PcmChunk>? _chunkSubscription;
  StreamSubscription? _healthSubscription;
  bool _analysisDraining = false;
  bool _recordingDraining = false;
  int _droppedSamples = 0;
  bool _hasDiscontinuity = false;

  PracticeSessionState get state => _state;

  QueueAccounting get analysisQueueAccounting => QueueAccounting(
    droppedSamples: _droppedSamples,
    hasDiscontinuity: _hasDiscontinuity,
  );

  Future<PracticeSessionState> start(PracticeSessionRequest request) async {
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
      await _analysisEngine.initialize(
        AnalysisConfig(
          inputFormatSampleRate: request.captureRequest.format.sampleRate,
        ),
      );
      await _recordingSink.open(
        RecordingMetadata(
          sessionId: request.sessionId,
          startedAt: request.startedAt,
        ),
      );
      final captureSession = await _audioCapture.start(request.captureRequest);
      _captureSession = captureSession;
      _chunkSubscription = captureSession.pcmChunks.listen(
        _onPcmChunk,
        onError: _onCaptureStreamError,
      );
      _healthSubscription = captureSession.health.listen(_onCaptureHealth);
      _state = _stateMachine.transition(_state, const CaptureStarted());
    } on CaptureFailure catch (failure) {
      _state = _stateMachine.transition(_state, CaptureFailedEvent(failure));
    } catch (_) {
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
    await _captureSession!.pause();
    _state = _stateMachine.transition(_state, const PauseRequested());
    return _state;
  }

  Future<PracticeSessionState> resume() async {
    if (_state is! Paused) {
      throw InvalidSessionTransition(from: _state.kind.name, event: 'resume');
    }
    await _captureSession!.resume();
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
    await _stopCapture();
    await _analysisEngine.dispose();
  }

  Future<PracticeSessionState> _finalize() async {
    final request = _request;
    if (request == null || _state is! Finalizing) {
      return _state;
    }
    try {
      final finalized = await _analysisEngine.finish();
      final recording = await _recordingSink.finalize();
      final flags = <AnalysisQualityFlag>{};
      if (_hasDiscontinuity) {
        flags.add(AnalysisQualityFlag.discontinuity);
      }
      if (_droppedSamples > 0) {
        flags.add(AnalysisQualityFlag.droppedSamples);
      }
      final summary = SessionSummary(
        validFrameCount: finalized.featureSeries.frames.length,
        totalFrameCount: finalized.featureSeries.frames.length,
        qualityFlags: flags,
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
    } catch (_) {
      _failFinalization(
        const FinalizationFailure(FinalizationFailureReason.unknown),
      );
    }
    return _state;
  }

  void _onPcmChunk(PcmChunk chunk) {
    if (_state is! Running) {
      return;
    }
    final analysisResult = _analysisQueue.add(chunk);
    _droppedSamples += analysisResult.droppedSamples;
    _hasDiscontinuity = _hasDiscontinuity || analysisResult.droppedSamples > 0;
    final recordingResult = _recordingQueue.add(chunk, dropOldest: false);
    if (!recordingResult.accepted) {
      _state = _stateMachine.transition(
        _state,
        const CaptureFailedEvent(CaptureFailure(CaptureFailureReason.unknown)),
      );
      unawaited(_recordingSink.abort());
      unawaited(_stopCapture());
      return;
    }
    _scheduleAnalysisDrain();
    _scheduleRecordingDrain();
  }

  void _onCaptureHealth(Object _) {}

  void _onCaptureStreamError(Object error, StackTrace stackTrace) {
    if (_state is Running || _state is Paused) {
      _state = _stateMachine.transition(
        _state,
        const CaptureFailedEvent(
          CaptureFailure(CaptureFailureReason.streamInterrupted),
        ),
      );
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
        await _analysisEngine.pushPcm(
          PcmBatch(
            firstSampleIndex: chunk.firstSampleIndex,
            format: chunk.format,
            bytes: chunk.bytes,
          ),
        );
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
      _failFinalization(
        const FinalizationFailure(FinalizationFailureReason.recording),
      );
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
}
