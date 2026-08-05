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
}

typedef AnalysisWorkerFactory = Future<AnalysisWorker> Function();

final class AnalysisWorkerMetrics {
  const AnalysisWorkerMetrics({
    required this.droppedSamples,
    required this.restartCount,
    required this.usingFallback,
  });

  final int droppedSamples;
  final int restartCount;
  final bool usingFallback;
}

/// Applies bounded backpressure and recovers a crashed worker once before
/// using a known-good fallback implementation.
///
/// Batches are kept at the bridge size (1024 samples by default), rather than
/// letting a browser message or FRB call grow with capture chunk size.
final class AnalysisWorkerSupervisor implements AnalysisEngine {
  AnalysisWorkerSupervisor({
    required this.primaryWorkerFactory,
    this.fallbackWorkerFactory,
    this.maxQueuedSamples = 12000,
  }) : assert(maxQueuedSamples > 0);

  final AnalysisWorkerFactory primaryWorkerFactory;
  final AnalysisWorkerFactory? fallbackWorkerFactory;
  final int maxQueuedSamples;
  final List<_PendingBatch> _queue = <_PendingBatch>[];

  AnalysisWorker? _worker;
  AnalysisConfig? _config;
  bool _draining = false;
  bool _disposed = false;
  bool _usingFallback = false;
  int _queuedSamples = 0;
  int _droppedSamples = 0;
  int _restartCount = 0;

  AnalysisWorkerMetrics get metrics => AnalysisWorkerMetrics(
    droppedSamples: _droppedSamples,
    restartCount: _restartCount,
    usingFallback: _usingFallback,
  );

  @override
  Future<void> initialize(AnalysisConfig config) async {
    _ensureNotDisposed();
    if (_worker != null) {
      throw StateError('Analysis worker is already initialized.');
    }
    _config = config;
    _worker = await _createPrimaryOrFallback();
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
    final worker = _requireWorker();
    try {
      return await worker.finish();
    } catch (_) {
      if (_usingFallback) {
        rethrow;
      }
      final replacement = await _restartOrFallback();
      return replacement.finish();
    }
  }

  @override
  Future<void> reset() async {
    _ensureNotDisposed();
    await _waitForDrain();
    await _requireWorker().reset();
    _droppedSamples = 0;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final pending in _queue) {
      pending.completeError(StateError('Analysis worker was disposed.'));
    }
    _queue.clear();
    _queuedSamples = 0;
    final worker = _worker;
    _worker = null;
    if (worker != null) {
      await worker.dispose();
    }
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
          pending.complete(await _pushWithRecovery(pending.batch));
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

  Future<AnalysisBatch> _pushWithRecovery(PcmBatch batch) async {
    final worker = _requireWorker();
    try {
      return await worker.pushPcm(batch);
    } catch (_) {
      if (_usingFallback) {
        rethrow;
      }
      final replacement = await _restartOrFallback();
      return replacement.pushPcm(batch);
    }
  }

  Future<AnalysisWorker> _createPrimaryOrFallback() async {
    try {
      final worker = await primaryWorkerFactory();
      await worker.initialize(_requireConfig());
      return worker;
    } catch (_) {
      return _activateFallback();
    }
  }

  Future<AnalysisWorker> _restartOrFallback() async {
    final previous = _worker;
    _worker = null;
    if (previous != null) {
      try {
        await previous.dispose();
      } catch (_) {
        // A crashed worker may no longer be able to acknowledge disposal.
      }
    }
    _restartCount += 1;
    try {
      final worker = await primaryWorkerFactory();
      await worker.initialize(_requireConfig());
      _worker = worker;
      return worker;
    } catch (_) {
      return _activateFallback();
    }
  }

  Future<AnalysisWorker> _activateFallback() async {
    final factory = fallbackWorkerFactory;
    if (factory == null) {
      throw StateError('No analysis worker fallback is configured.');
    }
    final worker = await factory();
    await worker.initialize(_requireConfig());
    _usingFallback = true;
    _worker = worker;
    return worker;
  }

  Future<void> _waitForDrain() async {
    while (_draining || _queue.isNotEmpty) {
      await Future<void>.delayed(Duration.zero);
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
