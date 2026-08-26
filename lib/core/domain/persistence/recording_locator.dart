import 'audio_content_identity.dart';

final class RecordingLocator {
  const RecordingLocator({
    required this.value,
    required this.storageKind,
    this.identity,
  }) : assert(value != '');

  final String value;
  final RecordingStorageKind storageKind;
  final AudioContentIdentity? identity;
}

enum RecordingStorageKind { file, indexedDb, opfs, none }
