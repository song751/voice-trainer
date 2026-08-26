import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/domain/reference/song_reference.dart';
import '../../src/rust/api/song.dart' as rust_song;
import '../../src/rust/frb_generated.dart';

const reviewedUmxHqModelSha256 =
    '1dd15a2be2f15ba035205f866a035df38d85b27824ad67fe53566e80ec1f4258';

/// Native, local-only adapter. The reviewed model is user-provisioned and is
/// never bundled, downloaded, or uploaded by the application.
final class NativeRustSongSeparator implements SongSeparator, SongModelManager {
  NativeRustSongSeparator();

  static const _maximumSongBytes = 500 * 1024 * 1024;
  static int _nextJob = 0;
  static Future<void>? _rustInitialization;
  static SongModelStatus? _cachedRuntimeStatus;

  File? _cancelMarker;
  bool _automaticSeparationAvailable = false;
  String? _modelId;

  @override
  bool get automaticSeparationAvailable => _automaticSeparationAvailable;

  @override
  Future<SongModelStatus> probe() async {
    if (!_supportedPlatform) {
      return const SongModelStatus(
        availability: SongModelAvailability.unavailable,
        detail: 'No reviewed native runtime is composed for this platform.',
      );
    }
    final model = await _resolveModel();
    if (!await model.exists()) {
      _automaticSeparationAvailable = false;
      return const SongModelStatus(
        availability: SongModelAvailability.notInstalled,
      );
    }
    final cached = _cachedRuntimeStatus;
    if (cached != null && cached.availability == SongModelAvailability.ready) {
      _automaticSeparationAvailable = true;
      _modelId = cached.modelId;
      return cached;
    }
    if (_automaticSeparationAvailable) {
      return SongModelStatus(
        availability: SongModelAvailability.ready,
        modelId: _modelId,
      );
    }
    try {
      await _ensureRustInitialized();
      final status = await rust_song.probeSongSeparationRuntime(
        modelPath: model.path,
        expectedModelSha256: reviewedUmxHqModelSha256,
      );
      _automaticSeparationAvailable = status.available;
      _modelId = status.modelId;
      final result = SongModelStatus(
        availability: status.available
            ? SongModelAvailability.ready
            : SongModelAvailability.unavailable,
        modelId: status.modelId,
        detail: status.reason,
      );
      if (status.available) _cachedRuntimeStatus = result;
      return result;
    } catch (error) {
      _automaticSeparationAvailable = false;
      return SongModelStatus(
        availability: SongModelAvailability.unavailable,
        detail: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<SongModelStatus> installModel(SongFileSource source) async {
    if (!_supportedPlatform) {
      return const SongModelStatus(
        availability: SongModelAvailability.unavailable,
      );
    }
    final length = await source.length();
    if (length <= 0 || length > 100 * 1024 * 1024) {
      throw const SongSeparationFailure(
        SongSeparationFailureReason.modelIntegrityFailed,
        detail: 'The selected model has an invalid file size.',
      );
    }
    final target = await _installedModel();
    await target.parent.create(recursive: true);
    final partial = File('${target.path}.partial');
    if (await partial.exists()) await partial.delete();
    final sink = partial.openWrite();
    var sinkClosed = false;
    try {
      await for (final chunk in source.openRead()) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sinkClosed = true;
      final actual = (await sha256.bind(partial.openRead()).first).toString();
      if (actual != reviewedUmxHqModelSha256) {
        await partial.delete();
        throw SongSeparationFailure(
          SongSeparationFailureReason.modelIntegrityFailed,
          detail: 'Expected reviewed model SHA-256 $reviewedUmxHqModelSha256.',
        );
      }
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      _automaticSeparationAvailable = false;
      _modelId = null;
      _cachedRuntimeStatus = null;
    } catch (_) {
      if (!sinkClosed) await sink.close();
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
    return probe();
  }

  @override
  Future<SeparatedSongReference> separate({
    required SongFileSource source,
    required bool rightsAcknowledged,
    required void Function(double progress) onProgress,
  }) async {
    if (!rightsAcknowledged) {
      throw const SongSeparationFailure(
        SongSeparationFailureReason.rightsNotAcknowledged,
      );
    }
    final length = await source.length();
    if (length == 0) {
      throw const SongSeparationFailure(SongSeparationFailureReason.emptyFile);
    }
    if (length > _maximumSongBytes) {
      throw const SongSeparationFailure(
        SongSeparationFailureReason.fileTooLarge,
      );
    }
    final runtime = await probe();
    if (runtime.availability == SongModelAvailability.notInstalled) {
      throw const SongSeparationFailure(
        SongSeparationFailureReason.modelNotInstalled,
      );
    }
    if (runtime.availability != SongModelAvailability.ready) {
      throw SongSeparationFailure(
        _runtimeFailure(runtime.detail),
        detail: runtime.detail,
      );
    }

    final model = await _resolveModel();
    final support = await getApplicationSupportDirectory();
    final temporary = await getTemporaryDirectory();
    final jobId = 'song_${DateTime.now().microsecondsSinceEpoch}_${_nextJob++}';
    final input = File(
      _join(temporary.path, '$jobId.${_safeExtension(source.displayName)}'),
    );
    final inputPartial = File('${input.path}.partial');
    final outputDirectory = Directory(
      _join(support.path, 'song-separation', 'stems'),
    );
    final cancelMarker = File(_join(temporary.path, '$jobId.cancel'));
    _cancelMarker = cancelMarker;
    try {
      await _spool(source, inputPartial, input);
      await outputDirectory.create(recursive: true);
      await _ensureRustInitialized();
      rust_song.SongSeparationReportDto? terminalReport;
      await for (final event in rust_song.startSongSeparation(
        request: rust_song.SongSeparationRequestDto(
          rightsAcknowledged: rightsAcknowledged,
          inputPath: input.path,
          modelPath: model.path,
          expectedModelSha256: reviewedUmxHqModelSha256,
          outputDirectory: outputDirectory.path,
          jobId: jobId,
          cancelMarker: cancelMarker.path,
          maximumDecodedFrames: BigInt.from(_maximumFramesForPlatform),
        ),
      )) {
        if (event.progress case final progress?) {
          onProgress(_progressFraction(progress));
        }
        if (event.failure case final failure?) {
          throw SongSeparationFailure(
            _mapFailure(failure.reason),
            detail: '${failure.operation}: ${failure.detail}',
          );
        }
        terminalReport = event.report ?? terminalReport;
      }
      final report = terminalReport;
      if (report == null) {
        throw const SongSeparationFailure(
          SongSeparationFailureReason.processingFailed,
          detail: 'The native worker ended without a terminal report.',
        );
      }
      onProgress(1);
      return _toDomain(source.displayName, report);
    } on SongSeparationFailure {
      rethrow;
    } catch (error) {
      throw SongSeparationFailure(
        SongSeparationFailureReason.processingFailed,
        detail: error.runtimeType.toString(),
      );
    } finally {
      _cancelMarker = null;
      if (await inputPartial.exists()) await inputPartial.delete();
      if (await input.exists()) await input.delete();
      if (await cancelMarker.exists()) await cancelMarker.delete();
    }
  }

  @override
  Future<void> cancel() async {
    final marker = _cancelMarker;
    if (marker != null) {
      await marker.writeAsString('cancel');
    }
  }

  Future<void> _spool(
    SongFileSource source,
    File partial,
    File completed,
  ) async {
    final sink = partial.openWrite();
    var written = 0;
    var sinkClosed = false;
    try {
      await for (final chunk in source.openRead()) {
        written += chunk.length;
        if (written > _maximumSongBytes) {
          throw const SongSeparationFailure(
            SongSeparationFailureReason.fileTooLarge,
          );
        }
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sinkClosed = true;
      await partial.rename(completed.path);
    } catch (_) {
      if (!sinkClosed) await sink.close();
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  Future<File> _resolveModel() async {
    if (Platform.isWindows) {
      final override = Platform.environment['VOICE_TRAINER_UMXHQ_ONNX'];
      if (override != null && override.isNotEmpty) return File(override);
    }
    return _installedModel();
  }

  Future<File> _installedModel() async {
    final support = await getApplicationSupportDirectory();
    return File(
      _join(
        support.path,
        'song-separation',
        'models',
        'umxhq-vocals-core-dynamic.onnx',
      ),
    );
  }

  bool get _supportedPlatform => Platform.isWindows || Platform.isAndroid;

  int get _maximumFramesForPlatform =>
      44_100 * 60 * (Platform.isAndroid ? 1 : 5);

  Future<void> _ensureRustInitialized() =>
      _rustInitialization ??= RustLib.init();
}

SeparatedSongReference _toDomain(
  String displayName,
  rust_song.SongSeparationReportDto report,
) => SeparatedSongReference(
  displayName: displayName,
  generatedByModel: true,
  modelId: report.modelId,
  algorithmVersion: report.algorithmVersion,
  sourceSampleRate: report.sourceSampleRate,
  sourceChannels: report.sourceChannels,
  sampleRate: report.outputSampleRate,
  channels: report.outputChannels,
  durationSamples: report.outputFrames.toInt(),
  chunkCount: report.chunkCount,
  artifactWarning: true,
  vocals: _stem(report.vocals),
  accompaniment: _stem(report.accompaniment),
);

SongStemReference _stem(rust_song.SongStemMetadataDto stem) =>
    SongStemReference(
      locator: stem.path,
      sha256: stem.sha256,
      byteLength: stem.byteLength.toInt(),
    );

double _progressFraction(rust_song.SongSeparationProgressDto progress) {
  final completed = progress.completedUnits.toDouble();
  final total = progress.totalUnits.toDouble().clamp(1, double.infinity);
  final within = (completed / total).clamp(0.0, 1.0);
  final (start, weight) = switch (progress.stage) {
    'decoding' => (0.0, 0.10),
    'resampling' => (0.10, 0.05),
    'transforming' => (0.15, 0.20),
    'inference' => (0.35, 0.45),
    'reconstructing' => (0.80, 0.10),
    'writing' => (0.90, 0.09),
    'completed' => (0.99, 0.01),
    _ => (0.0, 0.0),
  };
  return (start + weight * within).clamp(0.0, 1.0);
}

SongSeparationFailureReason _runtimeFailure(String? reason) => switch (reason) {
  'model_not_found' => SongSeparationFailureReason.modelNotInstalled,
  'model_hash_mismatch' => SongSeparationFailureReason.modelIntegrityFailed,
  'backend_incompatible' => SongSeparationFailureReason.backendIncompatible,
  _ => SongSeparationFailureReason.runtimeUnavailable,
};

SongSeparationFailureReason _mapFailure(String reason) => switch (reason) {
  'rights_acknowledgement_required' =>
    SongSeparationFailureReason.rightsNotAcknowledged,
  'input_not_found' => SongSeparationFailureReason.processingFailed,
  'unsupported_format' ||
  'format_changed' => SongSeparationFailureReason.unsupportedFormat,
  'decode_failed' => SongSeparationFailureReason.decodeFailed,
  'model_not_found' => SongSeparationFailureReason.modelNotInstalled,
  'model_hash_mismatch' => SongSeparationFailureReason.modelIntegrityFailed,
  'runtime_unavailable' => SongSeparationFailureReason.runtimeUnavailable,
  'backend_incompatible' ||
  'contract_mismatch' => SongSeparationFailureReason.backendIncompatible,
  'resource_limit_exceeded' =>
    SongSeparationFailureReason.resourceLimitExceeded,
  'cancelled' => SongSeparationFailureReason.cancelled,
  'io_failure' => SongSeparationFailureReason.outputFailed,
  _ => SongSeparationFailureReason.processingFailed,
};

String _safeExtension(String displayName) {
  final dot = displayName.lastIndexOf('.');
  if (dot < 0 || dot == displayName.length - 1) return 'audio';
  final extension = displayName.substring(dot + 1).toLowerCase();
  return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension) ? extension : 'audio';
}

String _join(String first, String second, [String? third, String? fourth]) =>
    <String>[first, second, ?third, ?fourth].join(Platform.pathSeparator);
