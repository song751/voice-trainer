import '../audio/pcm_chunk.dart';
import 'recording_locator.dart';

final class RecordingMetadata {
  const RecordingMetadata({required this.sessionId, required this.startedAt});

  final String sessionId;
  final DateTime startedAt;
}

abstract interface class RecordingSink {
  Future<void> open(RecordingMetadata metadata);

  Future<void> append(PcmChunk chunk);

  Future<RecordingLocator> finalize();

  Future<void> abort();
}
