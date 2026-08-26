import 'dart:io';
import 'dart:typed_data';

import '../../../core/domain/audio/pcm_chunk.dart';
import '../../../core/domain/persistence/audio_content_identity.dart';
import '../../../core/domain/persistence/recording_locator.dart';
import '../../../core/domain/persistence/recording_sink.dart';
import '../../../core/domain/persistence/recording_store.dart';
import '../../../core/domain/persistence/verified_recording_resolver.dart';
import 'native_managed_audio_store.dart';
import 'recording_recovery_service.dart';
import 'wav_stream_writer.dart';

final class NativeRecordingSink implements RecordingSink {
  NativeRecordingSink(this._directory);

  final Directory _directory;
  RecordingMetadata? _metadata;
  File? _partialFile;
  File? _completedFile;
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
    _completedFile = file;
    _finished = true;
    final identity = await NativeManagedAudioStore.identify(file);
    return RecordingLocator(
      value: file.uri.pathSegments.last,
      storageKind: RecordingStorageKind.file,
      identity: identity,
    );
  }

  @override
  Future<void> abort() async {
    if (_finished) {
      final completed = _completedFile;
      if (completed != null && await completed.exists()) {
        await completed.delete();
      }
      return;
    }
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
    implements
        RecordingStore,
        IncompleteRecordingRecovery,
        VerifiedRecordingResolver {
  NativeRecordingStore(this._directory)
    : _managed = NativeManagedAudioStore(_directory);

  final Directory _directory;
  final NativeManagedAudioStore _managed;

  @override
  bool get available => true;

  @override
  Future<void> delete(RecordingLocator locator) async {
    if (locator.storageKind != RecordingStorageKind.file) return;
    try {
      await _managed.deleteManaged(locator.value);
    } on AudioContentFailure catch (failure) {
      if (failure.reason != AudioContentFailureReason.missing) rethrow;
    }
  }

  @override
  Future<bool> exists(RecordingLocator locator) async {
    if (locator.storageKind != RecordingStorageKind.file) return false;
    return _managed.existsManaged(locator.value);
  }

  @override
  Future<VerifiedAudioLease> openVerified(RecordingLocator locator) async {
    if (locator.storageKind != RecordingStorageKind.file) {
      throw const AudioContentFailure(
        AudioContentFailureReason.unsupportedLocator,
      );
    }
    return _managed.openVerified(
      locator: locator.value,
      expected: locator.identity,
      // A/B verification is bounded even though native capture itself is not:
      // Android admits one canonical minute; Windows admits the documented
      // ten-minute soak. The managed store enforces this while streaming.
      maximumBytes: Platform.isAndroid
          ? 48_000 * 2 * 60 + 44
          : 48_000 * 2 * 60 * 10 + 44,
    );
  }

  @override
  Future<void> recoverIncompleteRecordings() async {
    if (!await _directory.exists()) return;
    await _managed.recoverVerifiedLeases();
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
