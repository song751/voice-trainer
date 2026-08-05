import '../../core/domain/audio/pcm_chunk.dart';

final class CaptureMetricsSnapshot {
  const CaptureMetricsSnapshot({
    required this.chunkCount,
    required this.totalSamples,
    required this.discontinuityCount,
    required this.oddByteChunkCount,
  });
  final int chunkCount;
  final int totalSamples;
  final int discontinuityCount;
  final int oddByteChunkCount;
}

final class CaptureMetricsCollector {
  Duration? _previousArrival;
  bool _ignoreNextInterval = false;
  int _chunkCount = 0;
  int _totalSamples = 0;
  int _discontinuityCount = 0;
  int _oddByteChunkCount = 0;

  bool add(PcmChunk chunk, Duration arrival) {
    _chunkCount += 1;
    _totalSamples += chunk.frameCount;
    final previous = _previousArrival;
    var discontinuity = false;
    if (previous != null && !_ignoreNextInterval) {
      final intervalUs = (arrival - previous).inMicroseconds;
      final expectedUs =
          chunk.frameCount *
          Duration.microsecondsPerSecond ~/
          chunk.format.sampleRate;
      if (intervalUs > (expectedUs * 3 > 100000 ? expectedUs * 3 : 100000)) {
        _discontinuityCount += 1;
        discontinuity = true;
      }
    }
    _ignoreNextInterval = false;
    _previousArrival = arrival;
    return discontinuity;
  }

  void recordOddBytes() => _oddByteChunkCount += 1;
  void ignoreNextIntervalAfterResume() => _ignoreNextInterval = true;
  CaptureMetricsSnapshot get snapshot => CaptureMetricsSnapshot(
    chunkCount: _chunkCount,
    totalSamples: _totalSamples,
    discontinuityCount: _discontinuityCount,
    oddByteChunkCount: _oddByteChunkCount,
  );
}
