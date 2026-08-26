import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:voice_trainer/app/app_lifecycle_observer.dart';
import 'package:voice_trainer/app/default_adapters.dart';
import 'package:voice_trainer/app/default_persistence.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_config.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_engine.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/audio/audio_capture.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/core/domain/persistence/recording_sink.dart';
import 'package:voice_trainer/core/domain/persistence/recording_locator.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/metrics/p3_performance_observer.dart';
import 'package:voice_trainer/core/platform/application_lifecycle.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';
import 'package:voice_trainer/features/live_practice/application/practice_session_coordinator.dart';
import 'package:voice_trainer/features/live_practice/domain/practice_session_state.dart';
import 'package:voice_trainer/infrastructure/audio/fake_audio_capture.dart';

const _sessionId = 'p4-08-release-emulator-baseline';
const _sampleRate = 48000;
const _chunkSamples = 1024;
const _durationSeconds = int.fromEnvironment(
  'P4_08_DURATION_SECONDS',
  defaultValue: 600,
);
const _totalSamples = _sampleRate * _durationSeconds;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final permission = await createDefaultAudioCapture(
    PlatformCapabilities.android,
  ).requestPermission();
  if (permission is PermissionDenied) {
    debugPrint('P4_08_PERMISSION_DENIED_OK');
    runApp(const _SentinelApp('P4_08_PERMISSION_DENIED_OK'));
    return;
  }
  debugPrint('P4_08_PERMISSION_GRANTED_OK');
  runApp(const _P408ReleaseGateApp());
}

final class _SentinelApp extends StatelessWidget {
  const _SentinelApp(this.sentinel);

  final String sentinel;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: Center(child: Text(sentinel))),
  );
}

final class _P408ReleaseGateApp extends StatefulWidget {
  const _P408ReleaseGateApp();

  @override
  State<_P408ReleaseGateApp> createState() => _P408ReleaseGateAppState();
}

final class _P408ReleaseGateAppState extends State<_P408ReleaseGateApp> {
  final Stopwatch _wallClock = Stopwatch();
  final Stopwatch _activeClock = Stopwatch();
  late final P3PerformanceObserver _observer;
  late final FakeAudioCapture _capture;
  late final DefaultPersistenceAdapters _persistence;
  PracticeSessionCoordinator? _coordinator;
  WidgetsBindingApplicationLifecycleSource? _lifecycle;
  StreamSubscription<ApplicationLifecyclePhase>? _lifecycleSubscription;
  Future<void> _lifecycleSerial = Future<void>.value();
  Timer? _progressTimer;
  String _status = 'P4_08_PERMISSION_GRANTED_OK';
  int _emittedSamples = 0;
  bool _manualPauseResume = false;
  bool _backgroundObserved = false;
  bool _foregroundObserved = false;
  bool _pausedByLifecycle = false;
  String _stage = 'initialize';

  @override
  void initState() {
    super.initState();
    _observer = P3PerformanceObserver.enabled(clock: () => _wallClock.elapsed);
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    unawaited(_run());
  }

  Future<void> _run() async {
    _persistence = createDefaultPersistenceAdapters(
      PlatformCapabilities.android,
    );
    try {
      final existing = await _persistence.sessionRepository.findById(
        _sessionId,
      );
      if (existing != null && existing.recording == null) {
        final inHistory = (await _persistence.sessionRepository.listRecent())
            .any((record) => record.id == _sessionId);
        if (!inHistory) throw StateError('restart history is unavailable');
        await _persistence.sessionRepository.delete(_sessionId);
        if (await _persistence.sessionRepository.findById(_sessionId) != null) {
          throw StateError('restart delete did not remove the session');
        }
        _setStatus('P4_08_RESTART_DELETE_OK');
        return;
      }
      if (existing != null) {
        await _persistence.sessionRepository.delete(_sessionId);
      }

      _capture = FakeAudioCapture();
      final coordinator = PracticeSessionCoordinator(
        audioCapture: _capture,
        analysisEngine: _GateAnalysisEngine(
          createDefaultAnalysisEngine(PlatformCapabilities.android),
          _setStage,
        ),
        recordingSink: _GateRecordingSink(
          _persistence.recordingSink,
          _setStage,
        ),
        recordingStore: _persistence.recordingStore,
        sessionRepository: _GateSessionRepository(
          _persistence.sessionRepository,
          _setStage,
        ),
        performanceObserver: _observer,
      );
      _coordinator = coordinator;
      _lifecycle = WidgetsBindingApplicationLifecycleSource();
      _lifecycleSubscription = _lifecycle!.phases.listen(_onLifecyclePhase);

      _wallClock.start();
      _activeClock.start();
      final started = await coordinator.start(
        PracticeSessionRequest(
          sessionId: _sessionId,
          template: const PracticeTemplate(
            id: 'p4-08-synthetic-sustained-note',
            version: 1,
            kind: PracticeKind.sustainedNote,
            target: PracticeTarget(targetMidiNote: 57),
            reviewStatus: ContentReviewStatus.draft,
          ),
          startedAt: DateTime.now().toUtc(),
        ),
      );
      if (started is! Running) throw StateError('session did not start');
      _stage = 'stream';
      _setStatus('P4_08_STABILITY_RUNNING samples=0');
      _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _status = 'P4_08_STABILITY_RUNNING samples=$_emittedSamples';
          });
        }
      });

      await _streamTenMinutes(coordinator);
      _activeClock.stop();
      _stage = 'stop_finalize';
      final completed = await coordinator.stop();
      if (completed is! Completed) throw StateError('session did not finish');
      await _lifecycleSerial;

      _stage = 'result_history';
      final record = await _persistence.sessionRepository.findById(_sessionId);
      if (record == null || record.recording == null) {
        throw StateError('completed result or recording is unavailable');
      }
      final inHistory = (await _persistence.sessionRepository.listRecent()).any(
        (candidate) => candidate.id == _sessionId,
      );
      if (!inHistory ||
          !await _persistence.recordingStore.exists(record.recording!)) {
        throw StateError('history or recording did not persist');
      }
      _stage = 'recording_delete';
      await _persistence.sessionRepository.deleteRecording(_sessionId);
      final retained = await _persistence.sessionRepository.findById(
        _sessionId,
      );
      if (retained == null ||
          retained.recording != null ||
          await _persistence.recordingStore.exists(record.recording!)) {
        throw StateError('recording delete contract failed');
      }

      _stage = 'metrics';
      final snapshot = _observer.snapshot();
      final metrics = <String, Object?>{
        'active_duration_seconds': _emittedSamples / _sampleRate,
        'wall_duration_seconds': _wallClock.elapsedMilliseconds / 1000,
        'generated_samples': _emittedSamples,
        'analysis_queue_dropped_samples': snapshot.analysisQueueDroppedSamples,
        'recording_queue_dropped_samples':
            snapshot.recordingQueueDroppedSamples,
        'discontinuity_count': snapshot.discontinuityCount,
        'worker_state': snapshot.workerState,
        'worker_restart_count': snapshot.workerRestartCount,
        'pipeline_p95_ms': snapshot.pipelineLatency.p95,
        'ui_build_p95_ms': snapshot.uiBuild.p95,
        'ui_raster_p95_ms': snapshot.uiRaster.p95,
        'manual_pause_resume': _manualPauseResume,
        'background_observed': _backgroundObserved,
        'foreground_observed': _foregroundObserved,
      };
      final encoded = jsonEncode(metrics);
      debugPrint('P4_08_METRICS $encoded');
      if (_emittedSamples != _totalSamples ||
          snapshot.analysisQueueDroppedSamples != 0 ||
          snapshot.recordingQueueDroppedSamples != 0 ||
          snapshot.workerState != 'primary' ||
          snapshot.workerRestartCount != 0 ||
          !_manualPauseResume ||
          !_backgroundObserved ||
          !_foregroundObserved ||
          snapshot.pipelineLatency.p95 == null ||
          snapshot.uiBuild.p95 == null ||
          snapshot.uiRaster.p95 == null) {
        throw StateError('stability metrics did not satisfy the gate');
      }
      _setStatus('P4_08_READY_FOR_RESTART $encoded');
    } catch (_) {
      _setStatus('P4_08_RELEASE_GATE_FAILED stage=$_stage');
    } finally {
      _progressTimer?.cancel();
    }
  }

  Future<void> _streamTenMinutes(PracticeSessionCoordinator coordinator) async {
    var sequence = 0;
    while (_emittedSamples < _totalSamples) {
      if (coordinator.state is! Running) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        continue;
      }
      if (!_manualPauseResume &&
          _activeClock.elapsed >= const Duration(seconds: 10)) {
        _activeClock.stop();
        await coordinator.pause();
        await Future<void>.delayed(const Duration(seconds: 1));
        await coordinator.resume();
        _activeClock.start();
        _manualPauseResume = true;
        continue;
      }
      final target = Duration(
        microseconds:
            (_emittedSamples * Duration.microsecondsPerSecond) ~/ _sampleRate,
      );
      if (_activeClock.elapsed < target) {
        await Future<void>.delayed(const Duration(milliseconds: 4));
        continue;
      }
      _capture.emit(
        PcmChunk(
          sequenceNumber: sequence,
          firstSampleIndex: _emittedSamples,
          format: const CaptureFormat(sampleRate: _sampleRate, channels: 1),
          bytes: _sineChunk(
            _emittedSamples,
            math.min(_chunkSamples, _totalSamples - _emittedSamples),
          ),
          captureMonotonicTime: _wallClock.elapsed,
        ),
      );
      sequence += 1;
      _emittedSamples += math.min(
        _chunkSamples,
        _totalSamples - _emittedSamples,
      );
      await Future<void>.delayed(Duration.zero);
    }
  }

  Uint8List _sineChunk(int firstSample, int sampleCount) {
    final bytes = Uint8List(sampleCount * 2);
    final data = ByteData.sublistView(bytes);
    for (var index = 0; index < sampleCount; index += 1) {
      final radians = 2 * math.pi * 220 * (firstSample + index) / _sampleRate;
      data.setInt16(
        index * 2,
        (math.sin(radians) * 12000).round(),
        Endian.little,
      );
    }
    return bytes;
  }

  void _onLifecyclePhase(ApplicationLifecyclePhase phase) {
    _lifecycleSerial = _lifecycleSerial.then((_) async {
      final coordinator = _coordinator;
      if (coordinator == null) return;
      switch (phase) {
        case ApplicationLifecyclePhase.background:
          _backgroundObserved = true;
          if (coordinator.state is Running) {
            _activeClock.stop();
            await coordinator.pause();
            _pausedByLifecycle = true;
          }
        case ApplicationLifecyclePhase.foreground:
          _foregroundObserved = true;
          if (_pausedByLifecycle && coordinator.state is Paused) {
            await coordinator.resume();
            _activeClock.start();
            _pausedByLifecycle = false;
          }
        case ApplicationLifecyclePhase.detached:
          break;
      }
    });
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _observer.onUiFrameTiming(
        build: timing.buildDuration,
        raster: timing.rasterDuration,
      );
    }
  }

  void _setStatus(String status) {
    debugPrint(status);
    if (mounted) setState(() => _status = status);
  }

  void _setStage(String stage) => _stage = stage;

  @override
  void dispose() {
    _progressTimer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    unawaited(_lifecycleSubscription?.cancel());
    _lifecycle?.dispose();
    final coordinator = _coordinator;
    if (coordinator != null) unawaited(coordinator.dispose());
    unawaited(_persistence.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Semantics(
          container: true,
          label: _status,
          child: Text(_status, textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}

final class _GateAnalysisEngine implements AnalysisEngine {
  const _GateAnalysisEngine(this._delegate, this._stage);

  final AnalysisEngine _delegate;
  final void Function(String) _stage;

  @override
  AnalysisWorkerMetrics get workerMetrics => _delegate.workerMetrics;

  @override
  Stream<AnalysisWorkerMetrics> get workerMetricsStream =>
      _delegate.workerMetricsStream;

  @override
  Future<void> initialize(AnalysisConfig config) =>
      _delegate.initialize(config);

  @override
  Future<AnalysisBatch> pushPcm(PcmBatch batch) => _delegate.pushPcm(batch);

  @override
  Future<AnalysisFinalization> finish() async {
    _stage('analysis_finish');
    final result = await _delegate.finish();
    _stage('analysis_finished');
    return result;
  }

  @override
  Future<void> reset() => _delegate.reset();

  @override
  Future<void> dispose() => _delegate.dispose();
}

final class _GateRecordingSink implements RecordingSink {
  const _GateRecordingSink(this._delegate, this._stage);

  final RecordingSink _delegate;
  final void Function(String) _stage;

  @override
  Future<void> open(RecordingMetadata metadata) => _delegate.open(metadata);

  @override
  Future<void> append(PcmChunk chunk) => _delegate.append(chunk);

  @override
  Future<RecordingLocator> finalize() async {
    _stage('recording_finalize');
    final result = await _delegate.finalize();
    _stage('recording_finalized');
    return result;
  }

  @override
  Future<void> abort() => _delegate.abort();
}

final class _GateSessionRepository implements SessionRepository {
  const _GateSessionRepository(this._delegate, this._stage);

  final SessionRepository _delegate;
  final void Function(String) _stage;

  @override
  Future<void> save(PracticeSessionRecord record) async {
    _stage('repository_save');
    await _delegate.save(record);
    _stage('repository_saved');
  }

  @override
  Future<PracticeSessionRecord?> findById(String id) => _delegate.findById(id);

  @override
  Future<List<PracticeSessionRecord>> listRecent({int limit = 20}) =>
      _delegate.listRecent(limit: limit);

  @override
  Future<void> delete(String id) => _delegate.delete(id);

  @override
  Future<void> deleteRecording(String id) => _delegate.deleteRecording(id);
}
