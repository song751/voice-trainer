import '../../core/domain/audio/pcm_chunk.dart';
import '../../core/domain/persistence/recording_locator.dart';
import '../../core/domain/persistence/recording_sink.dart';
import '../../core/domain/persistence/recording_store.dart';

final class InMemoryRecordingStore implements RecordingStore {
  final Set<String> _locators = <String>{};

  @override
  Future<void> delete(RecordingLocator locator) async {
    _locators.remove(locator.value);
  }

  @override
  Future<bool> exists(RecordingLocator locator) async =>
      _locators.contains(locator.value);

  void add(RecordingLocator locator) {
    _locators.add(locator.value);
  }
}

final class InMemoryRecordingSink implements RecordingSink {
  InMemoryRecordingSink(this._store);

  final InMemoryRecordingStore _store;
  final List<PcmChunk> chunks = <PcmChunk>[];
  RecordingMetadata? metadata;
  bool _opened = false;
  bool _aborted = false;

  @override
  Future<void> abort() async {
    _aborted = true;
    _opened = false;
  }

  @override
  Future<void> append(PcmChunk chunk) async {
    if (!_opened || _aborted) {
      throw StateError('Recording sink is not open.');
    }
    chunks.add(chunk);
  }

  @override
  Future<RecordingLocator> finalize() async {
    if (!_opened || _aborted || metadata == null) {
      throw StateError('Recording sink cannot finalize.');
    }
    _opened = false;
    final locator = RecordingLocator(
      value: 'memory://${metadata!.sessionId}',
      storageKind: RecordingStorageKind.none,
    );
    _store.add(locator);
    return locator;
  }

  @override
  Future<void> open(RecordingMetadata metadata) async {
    this.metadata = metadata;
    _opened = true;
    _aborted = false;
  }
}
