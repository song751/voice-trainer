import 'dart:async';

import '../../core/domain/analysis/analysis_config.dart';
import '../../core/domain/analysis/analysis_engine.dart';
import '../../core/domain/analysis/analysis_frame.dart';
import '../../core/domain/audio/pcm_chunk.dart';

/// A single serial execution context for the stateful Rust analyzer.
///
/// Native implementations delegate to FRB's worker pool. Web implementations
/// delegate to an explicit browser Worker; the fallback is intentionally the
/// Phase 0 single-thread WASM path.
abstract interface class AnalysisWorker {
  Future<void> initialize(AnalysisConfig config);

  Future<AnalysisBatch> pushPcm(PcmBatch batch);

  Future<AnalysisFinalization> finish();

  Future<void> reset();

  Future<void> dispose();

  /// Releases a crashed or unresponsive worker without awaiting a reply.
  ///
  /// A Web implementation must terminate its dedicated Worker directly. The
  /// native implementation releases its local bridge handle synchronously.
  void terminate();
}

typedef AnalysisWorkerFactory = Future<AnalysisWorker> Function();

enum AnalysisWorkerState {
  uninitialized,
  primary,
  restartOnce,
  fallback,
  terminalFailure,
  disposed,
}

final class AnalysisWorkerMetrics {
  const AnalysisWorkerMetrics({
    required this.droppedSamples,
    required this.restartCount,
    required this.usingFallback,
    required this.state,
  });

  final int droppedSamples;
  final int restartCount;
  final bool usingFallback;
  final AnalysisWorkerState state;
}

/// Applies bounded backpressure and follows a finite recovery state machine:
/// `primary -> restartOnce -> fallback -> terminalFailure`.
///
/// Every worker request is time-bounded. A timeout is handled exactly like a
/// crash: the current worker is terminated without awaiting its response, then
/// the supervisor advances once through the recovery state machine.
final class AnalysisWorkerSupervisor implements AnalysisEngine {
  AnalysisWorkerSupervisor({
    required this.primaryWorkerFactory,
    this.fallbackWorkerFactory,
    this.maxQueuedSamples = 12000,
    this.requestTimeout = const Duration(seconds: 5),
    this.drainTimeout = const Duration(seconds: 10),
  }) : assert(maxQueuedSamples > 0),
       assert(!requestTimeout.isNegative && requestTimeout != Duration.zero),
       assert(!drainTimeout.isNegative && drainTimeout != Duration.zero);

  final AnalysisWorkerFactory primaryWorkerFactory;
  final AnalysisWorkerFactory? fallbackWorkerFactory;
  final int maxQueuedSamples;
  final Duration requestTimeout;
  final Duration drainTimeout;
  final List<_PendingBatch> _queue = <_PendingBatch>[];

  AnalysisWorker? _worker;
  AnalysisConfig? _config;
  bool _draining = false;
  bool _disposed = false;
  int _queuedSamples = 0;
  int _droppedSamples = 0;
  int _restartCount = 0;
  AnalysisWorkerState _state = AnalysisWorkerState.uninitialized;

  AnalysisWorkerMetrics get metrics => AnalysisWorkerMetrics(
    droppedSamples: _droppedSamples,
    restartCount: _restartCount,
    usingFallback: _state == AnalysisWorkerState.fallback,
    state: _state,
  );

  @override
  Future<void> initialize(AnalysisConfig config) async {
    _ensureNotDisposed();
    if (_worker != null || _state != AnalysisWorkerState.uninitialized) {
      throw StateError('Analysis worker is already initialized.');
    }
    _config = config;
    _state = AnalysisWorkerState.primary;
    try {
      _worker = await _createAndInitialize(primaryWorkerFactory, 'initialize');
    } catch (error, stackTrace) {
      await _recoverFromFailure(error, stackTrace);
    }
  }

  @override
  Future<AnalysisBatch> pushPcm(PcmBatch batch) {
    _ensureNotDisposed();
    final config = _requireConfig();
    if (batch.frameCount > config.bridgeBatchSamples) {
      throw ArgumentError.value(
        batch.frameCount,
        'batch.frameCount',
        'A worker message may contain at most ${config.bridgeBatchSamples} '
            'samples.',
      );
    }
    final pending = _PendingBatch(batch);
    if (batch.frameCount > maxQueuedSamples) {
      _droppedSamples += batch.frameCount;
      pending.complete(AnalysisBatch(const []));
      return pending.future;
    }
    while (_queue.isNotEmpty &&
        _queuedSamples + batch.frameCount > maxQueuedSamples) {
      final dropped = _queue.removeAt(0);
      _queuedSamples -= dropped.batch.frameCount;
      _droppedSamples += dropped.batch.frameCount;
      dropped.complete(AnalysisBatch(const []));
    }
    _queue.add(pending);
    _queuedSamples += batch.frameCount;
    _scheduleDrain();
    return pending.future;
  }

  @override
  Future<AnalysisFinalization> finish() async {
    _ensureNotDisposed();
    await _waitForDrain();
    return _requestWithRecovery('finish', (worker) => worker.finish());
  }

  @override
  Future<void> reset() async {
    _ensureNotDisposed();
    await _waitForDrain();
    await _requestWithRecovery('reset', (worker) => worker.reset());
    _droppedSamples = 0;
  }

  @override
  Future<void> dispose() {
    if (_disposed) {
      return Future<void>.value();
    }
    _disposed = true;
    _state = AnalysisWorkerState.disposed;
    for (final pending in _queue) {
      pending.completeError(StateError('Analysis worker was disposed.'));
    }
    _queue.clear();
    _queuedSamples = 0;
    _terminateCurrentWorker();
    return Future<void>.value();
  }

  void _scheduleDrain() {
    if (_draining) {
      return;
    }
    _draining = true;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    try {
      while (_queue.isNotEmpty && !_disposed) {
        final pending = _queue.removeAt(0);
        _queuedSamples -= pending.batch.frameCount;
        try {
          pending.complete(
            await _requestWithRecovery(
              'pushPcm',
              (worker) => worker.pushPcm(pending.batch),
            ),
          );
        } catch (error, stackTrace) {
          pending.completeError(error, stackTrace);
        }
      }
    } finally {
      _draining = false;
      if (_queue.isNotEmpty && !_disposed) {
        _scheduleDrain();
      }
    }
  }

  Future<T> _requestWithRecovery<T>(
    String operation,
    Future<T> Function(AnalysisWorker worker) request,
  ) async {
    while (true) {
      _ensureNotDisposed();
      final worker = _requireWorker();
      try {
        return await _withTimeout(request(worker), operation);
      } catch (error, stackTrace) {
        await _recoverFromFailure(error, stackTrace);
      }
    }
  }

  Future<void> _recoverFromFailure(Object error, StackTrace stackTrace) async {
    _ensureNotDisposed();
    _terminateCurrentWorker();
    switch (_state) {
      case AnalysisWorkerState.primary:
        _state = AnalysisWorkerState.restartOnce;
        _restartCount += 1;
        try {
          _worker = await _createAndInitialize(primaryWorkerFactory, 'restart');
          return;
        } catch (restartError, restartStackTrace) {
          await _activateFallback(restartError, restartStackTrace);
          return;
        }
      case AnalysisWorkerState.restartOnce:
        await _activateFallback(error, stackTrace);
        return;
      case AnalysisWorkerState.fallback:
        _enterTerminalFailure(error, stackTrace);
      case AnalysisWorkerState.terminalFailure:
        _enterTerminalFailure(error, stackTrace);
      case AnalysisWorkerState.uninitialized:
      case AnalysisWorkerState.disposed:
        _enterTerminalFailure(error, stackTrace);
    }
  }

  Future<void> _activateFallback(Object error, StackTrace stackTrace) async {
    final factory = fallbackWorkerFactory;
    if (factory == null) {
      _enterTerminalFailure(error, stackTrace);
    }
    try {
      _worker = await _createAndInitialize(factory, 'fallback initialize');
      _state = AnalysisWorkerState.fallback;
    } catch (fallbackError, fallbackStackTrace) {
      _enterTerminalFailure(fallbackError, fallbackStackTrace);
    }
  }

  Future<AnalysisWorker> _createAndInitialize(
    AnalysisWorkerFactory factory,
    String operation,
  ) async {
    final worker = await _withTimeout(factory(), '$operation factory');
    try {
      await _withTimeout(worker.initialize(_requireConfig()), operation);
      return worker;
    } catch (_) {
      _terminate(worker);
      rethrow;
    }
  }

  Never _enterTerminalFailure(Object error, StackTrace stackTrace) {
    _state = AnalysisWorkerState.terminalFailure;
    Error.throwWithStackTrace(
      StateError('Analysis worker reached terminal failure: $error'),
      stackTrace,
    );
  }

  Future<T> _withTimeout<T>(Future<T> future, String operation) =>
      future.timeout(
        requestTimeout,
        onTimeout: () => throw TimeoutException(
          'Analysis worker $operation timed out after $requestTimeout.',
          requestTimeout,
        ),
      );

  Future<void> _waitForDrain() async {
    final deadline = DateTime.now().add(drainTimeout);
    while (_draining || _queue.isNotEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException(
          'Analysis worker queue drain timed out after $drainTimeout.',
          drainTimeout,
        );
      }
      await Future<void>.delayed(Duration.zero);
    }
  }

  void _terminateCurrentWorker() {
    final worker = _worker;
    _worker = null;
    if (worker != null) {
      _terminate(worker);
    }
  }

  void _terminate(AnalysisWorker worker) {
    try {
      worker.terminate();
    } catch (_) {
      // A failed worker can be partially torn down already.
    }
  }

  AnalysisConfig _requireConfig() =>
      _config ?? (throw StateError('Analysis worker is not initialized.'));

  AnalysisWorker _requireWorker() =>
      _worker ?? (throw StateError('Analysis worker is not initialized.'));

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('Analysis worker has been disposed.');
    }
  }
}

final class _PendingBatch {
  _PendingBatch(this.batch);

  final PcmBatch batch;
  final Completer<AnalysisBatch> _completer = Completer<AnalysisBatch>();

  Future<AnalysisBatch> get future => _completer.future;

  void complete(AnalysisBatch result) {
    if (!_completer.isCompleted) {
      _completer.complete(result);
    }
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }
}
