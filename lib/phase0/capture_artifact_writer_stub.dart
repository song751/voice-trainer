import 'dart:typed_data';

Future<String?> writeCaptureArtifact(Uint8List bytes, String fileName) async {
  // Browser runs still validate the complete in-memory WAV and its SHA-256.
  // Downloading is intentionally left to the operator because browsers may
  // reject an automatic download without another user gesture.
  return null;
}
