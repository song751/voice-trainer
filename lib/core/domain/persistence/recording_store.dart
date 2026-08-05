import 'recording_locator.dart';

abstract interface class RecordingStore {
  Future<void> delete(RecordingLocator locator);

  Future<bool> exists(RecordingLocator locator);
}
