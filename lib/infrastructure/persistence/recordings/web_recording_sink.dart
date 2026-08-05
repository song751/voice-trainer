import 'dart:typed_data';
import 'dart:js_interop';

import '../../../core/domain/audio/pcm_chunk.dart';
import '../../../core/domain/persistence/recording_locator.dart';
import '../../../core/domain/persistence/recording_sink.dart';
import '../../../core/domain/persistence/recording_store.dart';
import 'wav_stream_writer.dart';

@JS('VoiceTrainerRecordingStore')
extension type _WebRecordingClient._(JSObject _) implements JSObject {
  external factory _WebRecordingClient();

  external JSPromise<JSString> write(String locator, JSUint8Array bytes);
  external JSPromise<JSBoolean> exists(String locator, String storageKind);
  external JSPromise<JSAny?> remove(String locator, String storageKind);
}

/// Browser BlobStore with OPFS first, IndexedDB second and an explicitly
/// non-persistent memory fallback. It intentionally never touches Drift.
final class WebRecordingStore implements RecordingStore {
  WebRecordingStore() : _client = _WebRecordingClient();

  final _WebRecordingClient _client;
  String? _persistenceWarning;

  String? get persistenceWarning => _persistenceWarning;

  Future<RecordingLocator> write(String name, Uint8List wav) async {
    final kind = RecordingStorageKind.values.byName(
      (await _client.write(name, wav.toJS).toDart).toDart,
    );
    if (kind == RecordingStorageKind.none) {
      _persistenceWarning = '此浏览器无法持久化录音；关闭页面后录音会丢失。';
    }
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
  WebRecordingSink(this._store, {this.maximumPcmBytes = 5760000});

  final WebRecordingStore _store;
  final int maximumPcmBytes;
  RecordingMetadata? _metadata;
  _MemoryWavOutput? _output;
  WavStreamWriter? _writer;
  int _pcmBytes = 0;
  bool _finished = false;

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
    if (_pcmBytes + chunk.bytes.lengthInBytes > maximumPcmBytes) {
      throw StateError('Web recording exceeds the 60-second PCM16 limit.');
    }
    var writer = _writer;
    if (writer == null) {
      final output = _MemoryWavOutput();
      _output = output;
      writer = WavStreamWriter(output);
      _writer = writer;
      await writer.open(chunk.format);
    }
    _pcmBytes += chunk.bytes.lengthInBytes;
    await writer.append(chunk);
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
  Uint8List _bytes = Uint8List(0);
  Uint8List get bytes => Uint8List.fromList(_bytes);

  @override
  Future<void> append(Uint8List bytes) async {
    final next = Uint8List(_bytes.lengthInBytes + bytes.lengthInBytes);
    next.setRange(0, _bytes.lengthInBytes, _bytes);
    next.setRange(_bytes.lengthInBytes, next.lengthInBytes, bytes);
    _bytes = next;
  }

  @override
  Future<void> overwrite(int offset, Uint8List bytes) async {
    _bytes.setRange(offset, offset + bytes.lengthInBytes, bytes);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> abort() async {
    _bytes = Uint8List(0);
  }
}
