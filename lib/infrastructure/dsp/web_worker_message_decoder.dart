import 'dart:convert';

import '../../core/domain/analysis/analysis_engine.dart';
import '../../core/domain/analysis/analysis_frame.dart';
import '../../core/domain/analysis/feature_series.dart';
import 'analysis_frame_dto_mapper.dart';
import 'segment_summary_dto_mapper.dart';

/// Validates the JSON-only boundary returned by the dedicated Web Worker.
/// Unknown fields may be added compatibly, but unknown quality bits, an
/// oversized band payload, or a malformed shape are rejected before domain
/// state is updated.
final class WebWorkerMessageDecoder {
  const WebWorkerMessageDecoder();

  AnalysisBatch decodeBatch(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      throw const FormatException('Web worker batch must be a JSON array.');
    }
    return AnalysisBatch(
      decoded
          .map((value) {
            if (value is! Map<String, dynamic>) {
              throw const FormatException(
                'Web worker frame must be an object.',
              );
            }
            return _mapFrame(value);
          })
          .toList(growable: false),
    );
  }

  AnalysisFinalization decodeFinalization(
    String raw,
    List<AnalysisFrame> frames,
  ) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Web worker summary must be an object.');
    }
    return AnalysisFinalization(
      featureSeries: FeatureSeries(frameRateHz: 100, frames: frames),
      finalFrames: frames,
      segmentSummary: mapWebSegmentSummary(decoded),
    );
  }

  AnalysisFrame _mapFrame(Map<String, dynamic> frame) => mapAnalysisFrameDto(
    startSample: (frame['startSample'] as num).toInt(),
    rmsDbfs: (frame['rmsDbfs'] as num).toDouble(),
    peakDbfs: (frame['peakDbfs'] as num).toDouble(),
    pitchClarity: (frame['pitchClarity'] as num).toDouble(),
    voiced: frame['voiced'] as bool,
    f0Hz: (frame['pitchHz'] as num?)?.toDouble(),
    bandPowersDb: (frame['bandPowersDbfs'] as List<dynamic>)
        .map((value) => (value as num).toDouble())
        .toList(growable: false),
    qualityFlags: (frame['qualityFlags'] as num).toInt(),
  );
}
