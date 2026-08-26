import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../../core/domain/persistence/audio_content_identity.dart';

final class NativeManagedAudioStore {
  NativeManagedAudioStore(this.root);

  final Directory root;
  static int _nextLease = 0;

  Future<File> resolveManaged(String locator) async {
    await root.create(recursive: true);
    final rootPath = await root.resolveSymbolicLinks();
    final source = _sourceFor(locator);
    if (!await source.exists()) {
      _requireInside(rootPath, await _canonicalMissingPath(source));
      throw const AudioContentFailure(AudioContentFailureReason.missing);
    }
    final sourcePath = await source.resolveSymbolicLinks();
    _requireInside(rootPath, sourcePath);
    return File(sourcePath);
  }

  Future<bool> existsManaged(String locator) async {
    await root.create(recursive: true);
    final rootPath = await root.resolveSymbolicLinks();
    final source = _sourceFor(locator);
    if (!await source.exists()) {
      _requireInside(rootPath, await _canonicalMissingPath(source));
      return false;
    }
    _requireInside(rootPath, await source.resolveSymbolicLinks());
    return true;
  }

  Future<void> deleteManaged(String locator) async {
    final source = await resolveManaged(locator);
    await source.delete();
  }

  Future<VerifiedAudioLease> openVerified({
    required String locator,
    required AudioContentIdentity? expected,
  }) async {
    if (expected == null || !expected.isWellFormed) {
      throw const AudioContentFailure(AudioContentFailureReason.legacyUnbound);
    }
    final source = await resolveManaged(locator);
    final snapshots = Directory(
      '${root.path}${Platform.pathSeparator}.verified',
    );
    await snapshots.create(recursive: true);
    final snapshot = File(
      '${snapshots.path}${Platform.pathSeparator}'
      'lease_${DateTime.now().microsecondsSinceEpoch}_${_nextLease++}.wav',
    );
    try {
      await source.copy(snapshot.path);
      final actual = await identify(snapshot);
      if (actual.byteLength != expected.byteLength) {
        throw const AudioContentFailure(
          AudioContentFailureReason.lengthMismatch,
        );
      }
      if (actual.sha256 != expected.sha256) {
        throw const AudioContentFailure(AudioContentFailureReason.hashMismatch);
      }
      return _NativeVerifiedAudioLease(snapshot, actual);
    } on AudioContentFailure {
      if (await snapshot.exists()) await snapshot.delete();
      rethrow;
    } catch (error) {
      if (await snapshot.exists()) await snapshot.delete();
      throw AudioContentFailure(
        AudioContentFailureReason.ioFailure,
        detail: error.runtimeType.toString(),
      );
    }
  }

  static Future<AudioContentIdentity> identify(File file) async =>
      AudioContentIdentity(
        sha256: (await sha256.bind(file.openRead()).first).toString(),
        byteLength: await file.length(),
      );

  File _sourceFor(String locator) {
    if (locator.isEmpty) {
      throw const AudioContentFailure(
        AudioContentFailureReason.unsupportedLocator,
      );
    }
    if (File(locator).isAbsolute) return File(locator);
    if (locator == '.' ||
        locator == '..' ||
        locator.contains('/') ||
        locator.contains(r'\')) {
      throw const AudioContentFailure(
        AudioContentFailureReason.unsupportedLocator,
      );
    }
    return File('${root.path}${Platform.pathSeparator}$locator');
  }

  Future<String> _canonicalMissingPath(File source) async {
    final parent = source.parent;
    if (!await parent.exists()) {
      throw const AudioContentFailure(
        AudioContentFailureReason.outsideManagedRoot,
      );
    }
    return '${await parent.resolveSymbolicLinks()}'
        '${Platform.pathSeparator}${source.uri.pathSegments.last}';
  }

  void _requireInside(String rootPath, String sourcePath) {
    final normalizedRoot = _normalize(rootPath);
    final normalizedSource = _normalize(sourcePath);
    if (normalizedSource == normalizedRoot ||
        !normalizedSource.startsWith(
          '$normalizedRoot${Platform.pathSeparator}',
        )) {
      throw const AudioContentFailure(
        AudioContentFailureReason.outsideManagedRoot,
      );
    }
  }

  String _normalize(String path) {
    var value = File(path).absolute.path;
    while (value.endsWith(Platform.pathSeparator)) {
      value = value.substring(0, value.length - 1);
    }
    return Platform.isWindows ? value.toLowerCase() : value;
  }
}

final class _NativeVerifiedAudioLease implements VerifiedAudioLease {
  _NativeVerifiedAudioLease(this._snapshot, this.identity);

  final File _snapshot;
  var _disposed = false;

  @override
  String get path => _snapshot.path;

  @override
  final AudioContentIdentity identity;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (await _snapshot.exists()) await _snapshot.delete();
  }
}
