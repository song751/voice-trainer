import 'dart:typed_data';

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

/// An immutable, verified audio snapshot held independently of its source
/// pathname. [bytes] is read-only so filesystem changes or callers cannot
/// alter the consumer's input after verification.
abstract interface class VerifiedAudioLease {
  Uint8List get bytes;
  AudioContentIdentity get identity;
  Future<void> dispose();
}
