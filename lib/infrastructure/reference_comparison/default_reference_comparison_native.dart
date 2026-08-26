import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/domain/analysis/analysis_frame.dart';
import '../../core/domain/analysis/analysis_quality_flag.dart';
import '../../core/domain/reference/reference_comparison.dart';
import '../../src/rust/api/song_compare.dart' as rust_compare;
import '../../src/rust/frb_generated.dart';

ReferenceFeatureExtractor createDefaultReferenceFeatureExtractor() =>
    NativeReferenceFeatureExtractor();

AudioPreview createDefaultAudioPreview() => NativeAudioPreview();

final class NativeReferenceFeatureExtractor
    implements ReferenceFeatureExtractor {
  static Future<void>? _rustInitialization;
  static int _nextJob = 0;

  File? _cancelMarker;

  @override
  bool get available => Platform.isWindows || Platform.isAndroid;

  @override
  Future<ReferenceAnalysisSeries> analyze({
    required vocals,
    required void Function(double progress) onProgress,
  }) async {
    if (!available) {
      throw const ReferenceAnalysisFailure(
        ReferenceAnalysisFailureReason.unavailable,
      );
    }
    final source = File(vocals.locator);
    if (!await source.exists()) {
      throw const ReferenceAnalysisFailure(
        ReferenceAnalysisFailureReason.inputMissing,
      );
    }
    final temporary = await getTemporaryDirectory();
    final marker = File(
      '${temporary.path}${Platform.pathSeparator}'
      'reference_analysis_${DateTime.now().microsecondsSinceEpoch}_'
      '${_nextJob++}.cancel',
    );
    _cancelMarker = marker;
    try {
      await _ensureRustInitialized();
      rust_compare.ReferenceAnalysisReportDto? terminal;
      await for (final event in rust_compare.startReferenceAnalysis(
        request: rust_compare.ReferenceAnalysisRequestDto(
          vocalsPath: source.path,
          maximumDecodedFrames: BigInt.from(
            44_100 * 60 * (Platform.isAndroid ? 1 : 5),
          ),
          cancelMarker: marker.path,
        ),
      )) {
        if (event.progress case final progress?) {
          onProgress(progress.clamp(0.0, 1.0));
        }
        if (event.failure case final failure?) {
          throw ReferenceAnalysisFailure(
            _mapFailure(failure.reason),
            detail: failure.detail,
          );
        }
        terminal = event.report ?? terminal;
      }
      final report = terminal;
      if (report == null) {
        throw const ReferenceAnalysisFailure(
          ReferenceAnalysisFailureReason.processingFailed,
          detail: 'Reference worker ended without a terminal report.',
        );
      }
      return ReferenceAnalysisSeries(
        sampleRate: report.sampleRate,
        frameRateHz: report.frameRateHz,
        algorithmVersion: report.algorithmVersion,
        frames: report.frames
            .map(
              (frame) => AnalysisFrame(
                sampleIndex: frame.sampleIndex.toInt(),
                rmsDbfs: frame.rmsDbfs,
                peakDbfs: frame.rmsDbfs,
                pitchClarity: frame.periodicity,
                voiced: frame.voiced,
                algorithmVersion: report.algorithmVersion,
                pitchCents: frame.pitchCents,
                qualityFlags: frame.clipping
                    ? const <AnalysisQualityFlag>{AnalysisQualityFlag.clipping}
                    : const <AnalysisQualityFlag>{},
              ),
            )
            .toList(growable: false),
      );
    } finally {
      _cancelMarker = null;
      if (await marker.exists()) await marker.delete();
    }
  }

  @override
  Future<void> cancel() async {
    final marker = _cancelMarker;
    if (marker != null) await marker.writeAsString('cancel');
  }

  Future<void> _ensureRustInitialized() async {
    // ignore: invalid_use_of_internal_member
    if (RustLib.instance.initialized) return;
    final initialization = _rustInitialization ??= RustLib.init();
    try {
      await initialization;
    } catch (_) {
      if (identical(_rustInitialization, initialization)) {
        _rustInitialization = null;
      }
      rethrow;
    }
  }
}

final class NativeAudioPreview implements AudioPreview {
  NativeAudioPreview() : _player = AudioPlayer();

  final AudioPlayer _player;
  Timer? _stopTimer;

  @override
  bool get available => Platform.isWindows || Platform.isAndroid;

  @override
  Future<void> playFile({
    required String path,
    required PhraseRange range,
  }) async {
    if (!available) {
      throw const AudioPreviewFailure(AudioPreviewFailureReason.unavailable);
    }
    final source = File(path);
    if (!await source.exists()) {
      throw const AudioPreviewFailure(AudioPreviewFailureReason.sourceMissing);
    }
    try {
      _stopTimer?.cancel();
      await _player.stop();
      await _player.play(
        DeviceFileSource(source.path),
        position: Duration(milliseconds: (range.startSeconds * 1000).round()),
        mode: PlayerMode.mediaPlayer,
      );
      _stopTimer = Timer(
        Duration(milliseconds: (range.durationSeconds * 1000).round()),
        () => unawaited(_player.stop()),
      );
    } catch (error) {
      throw AudioPreviewFailure(
        AudioPreviewFailureReason.playbackFailed,
        detail: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> stop() async {
    _stopTimer?.cancel();
    _stopTimer = null;
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    _stopTimer?.cancel();
    await _player.dispose();
  }
}

ReferenceAnalysisFailureReason _mapFailure(String reason) => switch (reason) {
  'runtime_unavailable' => ReferenceAnalysisFailureReason.unavailable,
  'input_not_found' => ReferenceAnalysisFailureReason.inputMissing,
  'unsupported_format' => ReferenceAnalysisFailureReason.unsupportedFormat,
  'decode_failed' => ReferenceAnalysisFailureReason.decodeFailed,
  'resource_limit_exceeded' =>
    ReferenceAnalysisFailureReason.resourceLimitExceeded,
  'cancelled' => ReferenceAnalysisFailureReason.cancelled,
  'insufficient_audio' => ReferenceAnalysisFailureReason.insufficientAudio,
  _ => ReferenceAnalysisFailureReason.processingFailed,
};
