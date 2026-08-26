import 'dart:typed_data';
import 'dart:js_interop';

import '../../../core/domain/audio/pcm_chunk.dart';
import '../../../core/domain/persistence/recording_locator.dart';
import '../../../core/domain/persistence/recording_sink.dart';
import '../../../core/domain/persistence/recording_store.dart';
import 'web_recording_limit.dart';
import 'web_storage_result.dart';
import 'wav_stream_writer.dart';

@JS('VoiceTrainerRecordingStore')
extension type _WebRecordingClient._(JSObject _) implements JSObject {
  external factory _WebRecordingClient();

  external JSPromise<JSString> probe();
  external JSPromise<JSString> write(String locator, JSUint8Array bytes);
  external JSPromise<JSBoolean> exists(String locator, String storageKind);
  external JSPromise<JSAny?> remove(String locator, String storageKind);
}

/// Browser BlobStore with OPFS first and IndexedDB second.
///
/// A browser without either durable backend fails explicitly. Production code
/// never stores recording bytes in Drift and never silently falls back to RAM.
final class WebRecordingStore implements RecordingStore {
  WebRecordingStore() : _client = _WebRecordingClient();

  final _WebRecordingClient _client;
  RecordingStorageKind? _storageKind;

  RecordingStorageKind? get storageKind => _storageKind;

  Future<RecordingStorageKind> probe() async {
    final result = (await _client.probe().toDart).toDart;
    return _storageKind = decodeWebRecordingStorageResult(result);
  }

  Future<RecordingLocator> write(String name, Uint8List wav) async {
    final result = (await _client.write(name, wav.toJS).toDart).toDart;
    final kind = decodeWebRecordingStorageResult(result);
    _storageKind = kind;
    return RecordingLocator(value: name, storageKind: kind);
  }

  @override
  Future<void> delete(RecordingLocator locator) async {
    await _client.remove(locator.value, locator.storageKind.name).toDart;
  }

  @override
  Future<bool> exists(RecordingLocator locator) async =>
      (await _client.exists(locator.value, locator.storageKind.name).toDart)
          .toDart;
}

/// Web MVP buffers no more than 60 seconds of mono PCM16, patches a WAV in
/// memory, then delegates persistence to [WebRecordingStore].
final class WebRecordingSink implements RecordingSink {
  WebRecordingSink(
    this._store, {
    Duration maximumDuration = const Duration(seconds: 60),
  }) : _sampleLimit = WebRecordingSampleLimit(maximumDuration: maximumDuration);

  final WebRecordingStore _store;
  final WebRecordingSampleLimit _sampleLimit;
  RecordingMetadata? _metadata;
  _MemoryWavOutput? _output;
  WavStreamWriter? _writer;
  bool _finished = false;

  bool get limitReached => _sampleLimit.reached;

  @override
  Future<void> open(RecordingMetadata metadata) async {
    if (_metadata != null) throw StateError('Recording sink is already open.');
    _metadata = metadata;
  }

  @override
  Future<void> append(PcmChunk chunk) async {
    if (_finished || _metadata == null) {
      throw StateError('Recording sink is not open.');
    }
    final accepted = _sampleLimit.accept(chunk);
    if (accepted == null) return;
    var writer = _writer;
    if (writer == null) {
      final output = _MemoryWavOutput();
      _output = output;
      writer = WavStreamWriter(output);
      _writer = writer;
      await writer.open(accepted.format);
    }
    await writer.append(accepted);
  }

  @override
  Future<RecordingLocator> finalize() async {
    final writer = _writer;
    final output = _output;
    if (_finished || writer == null || output == null) {
      throw StateError('Recording sink has no PCM data to finalize.');
    }
    await writer.finalize();
    _finished = true;
    return _store.write('${_metadata!.sessionId}.wav', output.bytes);
  }

  @override
  Future<void> abort() async {
    if (_finished) return;
    _finished = true;
    await _writer?.abort();
  }
}

final class _MemoryWavOutput implements WavOutput {
  final List<Uint8List> _segments = <Uint8List>[];
  int _length = 0;

  Uint8List get bytes {
    final result = Uint8List(_length);
    var offset = 0;
    for (final segment in _segments) {
      result.setRange(offset, offset + segment.lengthInBytes, segment);
      offset += segment.lengthInBytes;
    }
    return result;
  }

  @override
  Future<void> append(Uint8List bytes) async {
    final copy = Uint8List.fromList(bytes);
    _segments.add(copy);
    _length += copy.lengthInBytes;
  }

  @override
  Future<void> overwrite(int offset, Uint8List bytes) async {
    var remainingOffset = offset;
    var sourceOffset = 0;
    for (final segment in _segments) {
      if (remainingOffset >= segment.lengthInBytes) {
        remainingOffset -= segment.lengthInBytes;
        continue;
      }
      final count = (segment.lengthInBytes - remainingOffset).clamp(
        0,
        bytes.lengthInBytes - sourceOffset,
      );
      segment.setRange(
        remainingOffset,
        remainingOffset + count,
        bytes,
        sourceOffset,
      );
      sourceOffset += count;
      remainingOffset = 0;
      if (sourceOffset == bytes.lengthInBytes) return;
    }
    throw RangeError.range(offset + bytes.lengthInBytes, 0, _length);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> abort() async {
    _segments.clear();
    _length = 0;
  }
}
