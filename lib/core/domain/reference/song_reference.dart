abstract interface class SongFileSource {
  String get displayName;
  Future<int> length();
  Stream<List<int>> openRead();
}

abstract interface class SongFilePicker {
  Future<SongFileSource?> pickSong();
}

enum SongSeparationFailureReason {
  rightsNotAcknowledged,
  emptyFile,
  fileTooLarge,
  unsupportedFormat,
  runtimeUnavailable,
  cancelled,
  processingFailed,
}

final class SongSeparationFailure implements Exception {
  const SongSeparationFailure(this.reason);

  final SongSeparationFailureReason reason;
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
  });

  final String displayName;
  final bool generatedByModel;
  final String modelId;
  final int sampleRate;
  final int channels;
  final int durationSamples;
  final bool artifactWarning;
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

final class UnavailableSongSeparator implements SongSeparator {
  const UnavailableSongSeparator();

  @override
  bool get automaticSeparationAvailable => false;

  @override
  Future<void> cancel() async {}

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
