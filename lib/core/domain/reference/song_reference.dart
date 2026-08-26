import '../persistence/audio_content_identity.dart';

abstract interface class SongFileSource {
  String get displayName;
  Future<int> length();
  Stream<List<int>> openRead();
}

abstract interface class SongFilePicker {
  Future<SongFileSource?> pickSong();
}

abstract interface class SongModelFilePicker {
  Future<SongFileSource?> pickModel();
}

enum SongSeparationFailureReason {
  rightsNotAcknowledged,
  emptyFile,
  fileTooLarge,
  unsupportedFormat,
  modelNotInstalled,
  modelIntegrityFailed,
  runtimeUnavailable,
  backendIncompatible,
  decodeFailed,
  resourceLimitExceeded,
  outputFailed,
  cancelled,
  processingFailed,
}

final class SongSeparationFailure implements Exception {
  const SongSeparationFailure(this.reason, {this.detail});

  final SongSeparationFailureReason reason;
  final String? detail;
}

enum SongModelAvailability { ready, notInstalled, unavailable }

final class SongModelStatus {
  const SongModelStatus({
    required this.availability,
    this.modelId,
    this.detail,
  });

  final SongModelAvailability availability;
  final String? modelId;
  final String? detail;
}

final class SongStemReference {
  const SongStemReference({
    required this.locator,
    required this.sha256,
    required this.byteLength,
  });

  final String locator;
  final String sha256;
  final int byteLength;

  AudioContentIdentity get identity =>
      AudioContentIdentity(sha256: sha256, byteLength: byteLength);
}

final class SeparatedSongReference {
  const SeparatedSongReference({
    required this.displayName,
    required this.generatedByModel,
    required this.modelId,
    required this.sampleRate,
    required this.channels,
    required this.durationSamples,
    required this.artifactWarning,
    this.algorithmVersion = 'unknown',
    this.sourceSampleRate,
    this.sourceChannels,
    this.chunkCount = 0,
    this.vocals,
    this.accompaniment,
  });

  final String displayName;
  final bool generatedByModel;
  final String modelId;
  final int sampleRate;
  final int channels;
  final int durationSamples;
  final bool artifactWarning;
  final String algorithmVersion;
  final int? sourceSampleRate;
  final int? sourceChannels;
  final int chunkCount;
  final SongStemReference? vocals;
  final SongStemReference? accompaniment;
}

abstract interface class SongModelManager {
  Future<SongModelStatus> probe();

  Future<SongModelStatus> installModel(SongFileSource source);
}

abstract interface class SongSeparator {
  bool get automaticSeparationAvailable;

  Future<SeparatedSongReference> separate({
    required SongFileSource source,
    required bool rightsAcknowledged,
    required void Function(double progress) onProgress,
  });

  Future<void> cancel();
}

/// Optional capability for separators that keep generated stems in managed
/// application storage. Implementations must preserve the last valid
/// reference until a replacement has been committed successfully.
abstract interface class ManagedSongReferenceLifecycle {
  Future<SeparatedSongReference?> restoreReference();

  Future<void> deleteReference(SeparatedSongReference reference);
}

final class UnavailableSongSeparator
    implements SongSeparator, SongModelManager {
  const UnavailableSongSeparator();

  @override
  bool get automaticSeparationAvailable => false;

  @override
  Future<void> cancel() async {}

  @override
  Future<SongModelStatus> installModel(SongFileSource source) async =>
      const SongModelStatus(availability: SongModelAvailability.unavailable);

  @override
  Future<SongModelStatus> probe() async =>
      const SongModelStatus(availability: SongModelAvailability.unavailable);

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
    throw const SongSeparationFailure(
      SongSeparationFailureReason.runtimeUnavailable,
    );
  }
}
