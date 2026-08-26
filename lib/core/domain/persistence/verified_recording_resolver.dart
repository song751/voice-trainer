import 'audio_content_identity.dart';
import 'recording_locator.dart';

abstract interface class VerifiedRecordingResolver {
  bool get available;

  Future<VerifiedAudioLease> openVerified(RecordingLocator locator);
}

final class UnavailableVerifiedRecordingResolver
    implements VerifiedRecordingResolver {
  const UnavailableVerifiedRecordingResolver();

  @override
  bool get available => false;

  @override
  Future<VerifiedAudioLease> openVerified(RecordingLocator locator) async {
    throw const AudioContentFailure(AudioContentFailureReason.unavailable);
  }
}
