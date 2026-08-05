final class RecordingLocator {
  const RecordingLocator({required this.value, required this.storageKind})
    : assert(value != '');

  final String value;
  final RecordingStorageKind storageKind;
}

enum RecordingStorageKind { file, indexedDb, opfs, none }
