final class AudioContentIdentity {
  const AudioContentIdentity({required this.sha256, required this.byteLength})
    : assert(byteLength >= 0);

  final String sha256;
  final int byteLength;

  bool get isWellFormed =>
      byteLength >= 0 && RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256);

  String get shortId => sha256.length < 12 ? sha256 : sha256.substring(0, 12);

  @override
  bool operator ==(Object other) =>
      other is AudioContentIdentity &&
      other.sha256 == sha256 &&
      other.byteLength == byteLength;

  @override
  int get hashCode => Object.hash(sha256, byteLength);
}

enum AudioContentFailureReason {
  unavailable,
  legacyUnbound,
  unsupportedLocator,
  outsideManagedRoot,
  missing,
  lengthMismatch,
  hashMismatch,
  ioFailure,
}

final class AudioContentFailure implements Exception {
  const AudioContentFailure(this.reason, {this.detail});

  final AudioContentFailureReason reason;
  final String? detail;
}

/// An immutable, verified local snapshot. Consumers must not retain [path]
/// after [dispose], and must never substitute the unverified source locator.
abstract interface class VerifiedAudioLease {
  String get path;
  AudioContentIdentity get identity;
  Future<void> dispose();
}
