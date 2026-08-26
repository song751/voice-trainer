import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/domain/persistence/audio_content_identity.dart';

Future<void> recoverVerifiedAudioRoots(Iterable<Directory> roots) async {
  for (final root in roots) {
    await NativeManagedAudioStore(root).recoverVerifiedLeases();
  }
}

final class NativeManagedAudioStore {
  NativeManagedAudioStore(this.root);

  final Directory root;

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
    required int maximumBytes,
  }) async {
    if (maximumBytes <= 0) {
      throw ArgumentError.value(maximumBytes, 'maximumBytes');
    }
    if (expected == null || !expected.isWellFormed) {
      throw const AudioContentFailure(AudioContentFailureReason.legacyUnbound);
    }
    if (expected.byteLength > maximumBytes) {
      throw const AudioContentFailure(AudioContentFailureReason.resourceLimit);
    }
    final source = await resolveManaged(locator);
    try {
      if (await source.length() > maximumBytes) {
        throw const AudioContentFailure(
          AudioContentFailureReason.resourceLimit,
        );
      }
      final builder = BytesBuilder(copy: false);
      var byteLength = 0;
      await for (final chunk in source.openRead()) {
        byteLength += chunk.length;
        if (byteLength > maximumBytes) {
          throw const AudioContentFailure(
            AudioContentFailureReason.resourceLimit,
          );
        }
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      final actual = identityForBytes(bytes);
      if (actual.byteLength != expected.byteLength) {
        throw const AudioContentFailure(
          AudioContentFailureReason.lengthMismatch,
        );
      }
      if (actual.sha256 != expected.sha256) {
        throw const AudioContentFailure(AudioContentFailureReason.hashMismatch);
      }
      return _NativeVerifiedAudioLease(bytes, actual);
    } on AudioContentFailure {
      rethrow;
    } catch (error) {
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

  static AudioContentIdentity identityForBytes(Uint8List bytes) =>
      AudioContentIdentity(
        sha256: sha256.convert(bytes).toString(),
        byteLength: bytes.lengthInBytes,
      );

  /// Removes only legacy on-disk verified snapshots created by older builds.
  /// Links and non-directory containers are rejected without being followed.
  Future<void> recoverVerifiedLeases() async {
    if (!await root.exists()) return;
    final rootPath = await root.resolveSymbolicLinks();
    final snapshots = Directory(
      '${root.path}${Platform.pathSeparator}.verified',
    );
    final snapshotType = await FileSystemEntity.type(
      snapshots.path,
      followLinks: false,
    );
    if (snapshotType == FileSystemEntityType.notFound) return;
    if (snapshotType != FileSystemEntityType.directory) {
      throw const AudioContentFailure(
        AudioContentFailureReason.outsideManagedRoot,
      );
    }
    final snapshotsPath = await snapshots.resolveSymbolicLinks();
    _requireInside(rootPath, snapshotsPath);
    final stale = <File>[];
    await for (final entity in snapshots.list(followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw const AudioContentFailure(
          AudioContentFailureReason.outsideManagedRoot,
        );
      }
      if (type != FileSystemEntityType.file || !_isLeaseName(entity.path)) {
        continue;
      }
      final path = await File(entity.path).resolveSymbolicLinks();
      _requireInside(snapshotsPath, path);
      stale.add(File(path));
    }
    for (final file in stale) {
      if (await file.exists()) await file.delete();
    }
    if (!await snapshots.list(followLinks: false).isEmpty) return;
    await snapshots.delete();
  }

  bool _isLeaseName(String path) {
    final name = File(path).uri.pathSegments.last;
    return RegExp(r'^lease_[0-9]+_[0-9]+\.wav$').hasMatch(name);
  }

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
  _NativeVerifiedAudioLease(this._bytes, this.identity);

  Uint8List _bytes;
  var _disposed = false;

  @override
  Uint8List get bytes {
    if (_disposed) throw StateError('Verified audio lease is disposed.');
    return _bytes.asUnmodifiableView();
  }

  @override
  final AudioContentIdentity identity;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _bytes.fillRange(0, _bytes.length, 0);
    _bytes = Uint8List(0);
  }
}
