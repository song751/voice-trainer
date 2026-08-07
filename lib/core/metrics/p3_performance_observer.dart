import '../domain/analysis/analysis_engine.dart';
import '../domain/analysis/analysis_frame.dart';
import '../domain/audio/pcm_chunk.dart';

typedef ElapsedClock = Duration Function();

/// Gate-only, bounded measurement of the production audio pipeline.
///
/// It is deliberately opt-in.  The normal product path uses [disabled], which
/// retains no samples, opens no report and adds no per-frame logging.
final class P3PerformanceObserver {
  P3PerformanceObserver.enabled({
    ElapsedClock? clock,
    this.maxTrackedChunks = 128,
    this.maxMemorySamples = 32,
  }) : _enabled = true,
       _clock = clock ?? _stopwatchClock() {
    _lastMemorySampleAt = _clock();
  }

  P3PerformanceObserver.disabled()
    : _enabled = false,
      _clock = _zeroClock,
      maxTrackedChunks = 0,
      maxMemorySamples = 0;

  final bool _enabled;
  final ElapsedClock _clock;
  final int maxTrackedChunks;
  final int maxMemorySamples;
  final Map<int, Duration> _captureTimes = <int, Duration>{};
  final _OnlineQuantiles _pipelineLatency = _OnlineQuantiles();
  final _OnlineQuantiles _uiBuild = _OnlineQuantiles();
  final _OnlineQuantiles _uiRaster = _OnlineQuantiles();
  final List<P3MemorySample> _memorySamples = <P3MemorySample>[];
  Duration? _lastMemorySampleAt;
  int _analysisQueueDroppedSamples = 0;
  int _recordingQueueDroppedSamples = 0;
  int _discontinuityCount = 0;
  AnalysisWorkerMetrics? _lastWorkerMetrics;

  bool get enabled => _enabled;

  void onCaptureChunk(PcmChunk chunk) {
    if (!_enabled) return;
    _captureTimes[chunk.firstSampleIndex] = chunk.captureMonotonicTime;
    while (_captureTimes.length > maxTrackedChunks) {
      _captureTimes.remove(_captureTimes.keys.first);
    }
    if (chunk.discontinuityBefore) {
      _discontinuityCount += 1;
    }
  }

  void onQueueAccounting({
    required int analysisDroppedSamples,
    required int recordingDroppedSamples,
  }) {
    if (!_enabled) return;
    _analysisQueueDroppedSamples = analysisDroppedSamples;
    _recordingQueueDroppedSamples = recordingDroppedSamples;
  }

  void onAnalysisPublished(AnalysisFrame frame) {
    if (!_enabled) return;
    final captureTime = _captureTimeFor(frame.sampleIndex);
    if (captureTime != null) {
      final latency = _clock() - captureTime;
      if (!latency.isNegative) {
        _pipelineLatency.add(latency.inMicroseconds / 1000);
      }
    }
  }

  void onWorkerMetrics(AnalysisWorkerMetrics metrics) {
    if (_enabled) _lastWorkerMetrics = metrics;
  }

  /// Called by the Flutter gate shell after a UI frame containing analysis.
  void onUiFrameTiming({required Duration build, required Duration raster}) {
    if (!_enabled) return;
    _uiBuild.add(build.inMicroseconds / 1000);
    _uiRaster.add(raster.inMicroseconds / 1000);
  }

  /// The host supplies process memory; it is sampled rather than streamed.
  void sampleMemory({
    required double workingSetMib,
    required double privateMib,
  }) {
    if (!_enabled || workingSetMib < 0 || privateMib < 0) return;
    final now = _clock();
    if (_lastMemorySampleAt == now) return;
    _lastMemorySampleAt = now;
    _memorySamples.add(
      P3MemorySample(
        elapsed: now,
        workingSetMib: workingSetMib,
        privateMib: privateMib,
      ),
    );
    if (_memorySamples.length > maxMemorySamples) _memorySamples.removeAt(0);
  }

  P3PerformanceSnapshot snapshot() => P3PerformanceSnapshot(
    pipelineLatency: _pipelineLatency.snapshot(),
    uiBuild: _uiBuild.snapshot(),
    uiRaster: _uiRaster.snapshot(),
    analysisQueueDroppedSamples: _analysisQueueDroppedSamples,
    recordingQueueDroppedSamples: _recordingQueueDroppedSamples,
    discontinuityCount: _discontinuityCount,
    memorySamples: List<P3MemorySample>.unmodifiable(_memorySamples),
    workerState: _lastWorkerMetrics?.state.name,
    workerRestartCount: _lastWorkerMetrics?.restartCount ?? 0,
  );

  Duration? _captureTimeFor(int sampleIndex) {
    Duration? candidate;
    var candidateIndex = -1;
    for (final entry in _captureTimes.entries) {
      if (entry.key <= sampleIndex && entry.key > candidateIndex) {
        candidateIndex = entry.key;
        candidate = entry.value;
      }
    }
    return candidate;
  }

  static ElapsedClock _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  static Duration _zeroClock() => Duration.zero;
}

final class P3PerformanceSnapshot {
  const P3PerformanceSnapshot({
    required this.pipelineLatency,
    required this.uiBuild,
    required this.uiRaster,
    required this.analysisQueueDroppedSamples,
    required this.recordingQueueDroppedSamples,
    required this.discontinuityCount,
    required this.memorySamples,
    required this.workerState,
    required this.workerRestartCount,
  });

  final P3Quantiles pipelineLatency;
  final P3Quantiles uiBuild;
  final P3Quantiles uiRaster;
  final int analysisQueueDroppedSamples;
  final int recordingQueueDroppedSamples;
  final int discontinuityCount;
  final List<P3MemorySample> memorySamples;
  final String? workerState;
  final int workerRestartCount;
}

final class P3Quantiles {
  const P3Quantiles({
    required this.p50,
    required this.p95,
    required this.count,
  });

  final double? p50;
  final double? p95;
  final int count;
}

final class P3MemorySample {
  const P3MemorySample({
    required this.elapsed,
    required this.workingSetMib,
    required this.privateMib,
  });

  final Duration elapsed;
  final double workingSetMib;
  final double privateMib;
}

final class _OnlineQuantiles {
  static const _capacity = 256;
  final List<double> _values = <double>[];

  void add(double value) {
    if (!value.isFinite || value < 0) return;
    if (_values.length == _capacity) {
      _values.removeAt(0);
    }
    _values.add(value);
  }

  P3Quantiles snapshot() {
    if (_values.isEmpty) {
      return const P3Quantiles(p50: null, p95: null, count: 0);
    }
    final sorted = List<double>.of(_values)..sort();
    return P3Quantiles(
      p50: _percentile(sorted, 0.5),
      p95: _percentile(sorted, 0.95),
      count: sorted.length,
    );
  }

  double _percentile(List<double> sorted, double quantile) {
    final index = ((sorted.length - 1) * quantile).ceil();
    return sorted[index];
  }
}
