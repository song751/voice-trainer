import 'dart:io';
import 'dart:typed_data';

import '../../../core/domain/audio/pcm_chunk.dart';
import '../../../core/domain/persistence/recording_locator.dart';
import '../../../core/domain/persistence/recording_sink.dart';
import '../../../core/domain/persistence/recording_store.dart';
import 'recording_recovery_service.dart';
import 'wav_stream_writer.dart';

final class NativeRecordingSink implements RecordingSink {
  NativeRecordingSink(this._directory);

  final Directory _directory;
  RecordingMetadata? _metadata;
  File? _partialFile;
  WavStreamWriter? _writer;
  bool _finished = false;

  @override
  Future<void> open(RecordingMetadata metadata) async {
    if (_metadata != null) throw StateError('Recording sink is already open.');
    await _directory.create(recursive: true);
    _metadata = metadata;
  }

  @override
  Future<void> append(PcmChunk chunk) async {
    if (_finished || _metadata == null) {
      throw StateError('Recording sink is not open.');
    }
    var writer = _writer;
    if (writer == null) {
      final partial = File(
        '${_directory.path}${Platform.pathSeparator}$_fileStem.partial',
      );
      _partialFile = partial;
      writer = WavStreamWriter(
        _NativeWavOutput(await partial.open(mode: FileMode.write)),
      );
      _writer = writer;
      await writer.open(chunk.format);
    }
    await writer.append(chunk);
  }

  @override
  Future<RecordingLocator> finalize() async {
    final partial = _partialFile;
    final writer = _writer;
    if (_finished || partial == null || writer == null) {
      throw StateError('Recording sink has no PCM data to finalize.');
    }
    await writer.finalize();
    final completed = File(
      '${_directory.path}${Platform.pathSeparator}$_fileStem.wav',
    );
    final file = await partial.rename(completed.path);
    _finished = true;
    return RecordingLocator(
      value: file.path,
      storageKind: RecordingStorageKind.file,
    );
  }

  @override
  Future<void> abort() async {
    if (_finished) return;
    final writer = _writer;
    if (writer != null) {
      await writer.abort();
    } else {
      final partial = _partialFile;
      if (partial != null && await partial.exists()) await partial.delete();
    }
    _finished = true;
  }

  String get _fileStem {
    final sessionId = _metadata!.sessionId.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    return '${sessionId}_${_metadata!.startedAt.microsecondsSinceEpoch}';
  }
}

final class NativeRecordingStore
    implements RecordingStore, IncompleteRecordingRecovery {
  NativeRecordingStore(this._directory);

  final Directory _directory;

  @override
  Future<void> delete(RecordingLocator locator) async {
    if (locator.storageKind != RecordingStorageKind.file) return;
    final file = File(locator.value);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<bool> exists(RecordingLocator locator) async =>
      locator.storageKind == RecordingStorageKind.file &&
      await File(locator.value).exists();

  @override
  Future<void> recoverIncompleteRecordings() async {
    if (!await _directory.exists()) return;
    await for (final entity in _directory.list()) {
      if (entity is File && entity.path.endsWith('.partial')) {
        await entity.delete();
      }
    }
  }
}

final class _NativeWavOutput implements WavOutput {
  _NativeWavOutput(this._file);

  final RandomAccessFile _file;

  @override
  Future<void> append(Uint8List bytes) => _file.writeFrom(bytes);

  @override
  Future<void> overwrite(int offset, Uint8List bytes) async {
    await _file.setPosition(offset);
    await _file.writeFrom(bytes);
  }

  @override
  Future<void> flush() => _file.flush();

  @override
  Future<void> close() => _file.close();

  @override
  Future<void> abort() async {
    final path = _file.path;
    await _file.close();
    final partial = File(path);
    if (await partial.exists()) await partial.delete();
  }
}
