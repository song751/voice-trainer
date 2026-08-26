import 'dart:convert';
import 'dart:io';

import '../../core/domain/reference/song_reference.dart';
import '../persistence/recordings/native_managed_audio_store.dart';

/// Persists ownership of locally generated stems without storing a raw path.
///
/// A unique manifest is committed only after both stems have been verified.
/// The newest valid manifest is the current reference. Older manifests make
/// interrupted replacement cleanup retryable without guessing which files are
/// still in use.
final class NativeSongReferenceOwnership {
  NativeSongReferenceOwnership(
    this.root, {
    DateTime Function()? now,
    this.orphanGrace = const Duration(hours: 24),
    this.maximumStemBytes = 44_100 * 2 * 2 * 60 * 5 + 44,
  }) : _now = now ?? DateTime.now;

  static const _schemaVersion = 1;
  static const _maximumManifestBytes = 32 * 1024;
  static final _jobPattern = RegExp(r'^song_[0-9]{1,20}_[0-9]+$');
  static final _manifestPattern = RegExp(
    r'^reference-(song_[0-9]{1,20}_[0-9]+)\.json$',
  );
  static final _partialManifestPattern = RegExp(
    r'^\.reference-song_[0-9]{1,20}_[0-9]+\.json\.partial$',
  );
  static final _stemPattern = RegExp(
    r'^(song_[0-9]{1,20}_[0-9]+)-(vocals|accompaniment)\.wav$',
  );

  final Directory root;
  final DateTime Function() _now;
  final Duration orphanGrace;
  final int maximumStemBytes;

  Future<void> activate(SeparatedSongReference reference) async {
    final jobId = _requireOwnedPair(reference);
    try {
      await _verifyReference(reference);
    } on SongSeparationFailure {
      rethrow;
    } catch (error) {
      throw SongSeparationFailure(
        SongSeparationFailureReason.outputFailed,
        detail: 'Generated stem verification failed: ${error.runtimeType}.',
      );
    }
    final rootPath = await _prepareRoot();
    final target = File(_join(root.path, 'reference-$jobId.json'));
    final partial = File(_join(root.path, '.reference-$jobId.json.partial'));
    await _requireWritableManifestPath(partial, rootPath);
    if (await target.exists()) {
      throw const SongSeparationFailure(
        SongSeparationFailureReason.outputFailed,
        detail: 'A stem ownership manifest already exists for this job.',
      );
    }
    try {
      await partial.writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': _schemaVersion,
          'jobId': jobId,
          'activatedAtMicros': _now().microsecondsSinceEpoch,
          'reference': _encodeReference(reference),
        }),
        flush: true,
      );
      await partial.rename(target.path);
    } catch (error) {
      if (await _isRegularFile(partial)) await partial.delete();
      throw SongSeparationFailure(
        SongSeparationFailureReason.outputFailed,
        detail: 'Stem ownership commit failed: ${error.runtimeType}.',
      );
    }
    await _bestEffortCleanup(currentJobId: jobId, removeNoncurrentNow: true);
  }

  Future<SeparatedSongReference?> restore() async {
    final manifests = await _readManifests();
    manifests.sort(_newestFirst);
    _OwnedManifest? current;
    for (final manifest in manifests) {
      try {
        await _verifyReference(manifest.reference);
        current = manifest;
        break;
      } on Object {
        // A damaged manifest never makes an unverified stem current. An older
        // valid manifest remains recoverable until age-bounded cleanup.
      }
    }
    await _bestEffortCleanup(currentJobId: current?.jobId);
    return current?.reference;
  }

  /// Performs bounded startup cleanup without loading large stem payloads.
  /// The newest structurally valid manifest protects its exact job pair.
  Future<void> recover() async {
    final manifests = await _readManifests();
    manifests.sort(_newestFirst);
    String? currentJobId;
    for (final manifest in manifests) {
      if (manifest.isValid) {
        currentJobId = manifest.jobId;
        break;
      }
    }
    await _bestEffortCleanup(currentJobId: currentJobId);
  }

  Future<void> delete(SeparatedSongReference reference) async {
    final requestedJobId = _requireOwnedPair(reference);
    final manifests = await _readManifests();
    manifests.sort(_newestFirst);
    _OwnedManifest? current;
    for (final manifest in manifests) {
      if (manifest.isValid) {
        current = manifest;
        break;
      }
    }
    if (current == null ||
        current.jobId != requestedJobId ||
        !_sameReference(current.reference, reference)) {
      throw const SongSeparationFailure(
        SongSeparationFailureReason.outputFailed,
        detail: 'The requested stems are not the current managed reference.',
      );
    }
    try {
      await _deleteOwnedPair(current.reference);
      await _deleteRegularManifest(current.file);
    } on SongSeparationFailure {
      rethrow;
    } catch (error) {
      throw SongSeparationFailure(
        SongSeparationFailureReason.outputFailed,
        detail: 'Managed stem deletion failed: ${error.runtimeType}.',
      );
    }
  }

  Future<void> _bestEffortCleanup({
    required String? currentJobId,
    bool removeNoncurrentNow = false,
  }) async {
    try {
      final manifests = await _readManifests();
      final protectedJobs = <String>{};
      if (currentJobId != null) protectedJobs.add(currentJobId);
      for (final manifest in manifests) {
        if (manifest.jobId == currentJobId ||
            (!removeNoncurrentNow && !await _isPastGrace(manifest.file))) {
          protectedJobs.add(manifest.jobId);
          continue;
        }
        try {
          if (manifest.isValid) {
            await _deleteOwnedPair(manifest.reference);
          } else {
            await _deleteExactJobPair(manifest.jobId);
          }
          await _deleteRegularManifest(manifest.file);
        } on Object {
          protectedJobs.add(manifest.jobId);
        }
      }
      await _cleanupExactOrphanStems(protectedJobs);
      await _cleanupStalePartialManifests();
    } on Object {
      // Activation is already durable. Cleanup is retried on the next restore,
      // activation, or explicit deletion and must not roll UI state backwards.
    }
  }

  Future<void> _cleanupExactOrphanStems(Set<String> protectedJobs) async {
    if (!await root.exists()) return;
    final rootPath = await root.resolveSymbolicLinks();
    final candidates = <String, List<File>>{};
    await for (final entity in root.list(followLinks: false)) {
      final name = File(entity.path).uri.pathSegments.last;
      final match = _stemPattern.firstMatch(name);
      if (match == null) continue;
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file) continue;
      final canonical = await File(entity.path).resolveSymbolicLinks();
      _requireInside(rootPath, canonical);
      candidates
          .putIfAbsent(match.group(1)!, () => <File>[])
          .add(File(canonical));
    }
    for (final entry in candidates.entries) {
      if (protectedJobs.contains(entry.key)) continue;
      for (final file in entry.value) {
        if (await _isPastGrace(file)) await file.delete();
      }
    }
  }

  Future<void> _cleanupStalePartialManifests() async {
    if (!await root.exists()) return;
    final rootPath = await root.resolveSymbolicLinks();
    await for (final entity in root.list(followLinks: false)) {
      final name = File(entity.path).uri.pathSegments.last;
      if (!_partialManifestPattern.hasMatch(name)) continue;
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file) continue;
      final file = File(await File(entity.path).resolveSymbolicLinks());
      _requireInside(rootPath, file.path);
      if (await _isPastGrace(file)) await file.delete();
    }
  }

  Future<List<_OwnedManifest>> _readManifests() async {
    final rootPath = await _prepareRoot();
    final result = <_OwnedManifest>[];
    await for (final entity in root.list(followLinks: false)) {
      final name = File(entity.path).uri.pathSegments.last;
      final match = _manifestPattern.firstMatch(name);
      if (match == null) continue;
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file) continue;
      final file = File(await File(entity.path).resolveSymbolicLinks());
      _requireInside(rootPath, file.path);
      try {
        if (await file.length() > _maximumManifestBytes) continue;
        final decoded = jsonDecode(await file.readAsString());
        final manifest = _decodeManifest(file, decoded);
        if (manifest.jobId == match.group(1)) result.add(manifest);
      } on Object {
        result.add(_OwnedManifest.invalid(file: file, jobId: match.group(1)!));
      }
    }
    return result;
  }

  _OwnedManifest _decodeManifest(File file, Object? value) {
    if (value is! Map<String, Object?> ||
        value['schemaVersion'] != _schemaVersion ||
        value['jobId'] is! String ||
        value['activatedAtMicros'] is! int) {
      throw const FormatException('Invalid stem ownership manifest.');
    }
    final jobId = value['jobId']! as String;
    if (!_jobPattern.hasMatch(jobId)) {
      throw const FormatException('Invalid stem job id.');
    }
    final reference = _decodeReference(value['reference']);
    if (_requireOwnedPair(reference) != jobId) {
      throw const FormatException('Manifest and stem job ids differ.');
    }
    return _OwnedManifest(
      file: file,
      jobId: jobId,
      activatedAtMicros: value['activatedAtMicros']! as int,
      reference: reference,
    );
  }

  Future<void> _verifyReference(SeparatedSongReference reference) async {
    _requireOwnedPair(reference);
    final store = NativeManagedAudioStore(root);
    for (final stem in <SongStemReference>[
      reference.vocals!,
      reference.accompaniment!,
    ]) {
      final lease = await store.openVerified(
        locator: stem.locator,
        expected: stem.identity,
        maximumBytes: maximumStemBytes,
      );
      await lease.dispose();
    }
  }

  Future<void> _deleteOwnedPair(SeparatedSongReference reference) async {
    final jobId = _requireOwnedPair(reference);
    await _deleteExactJobPair(jobId);
  }

  Future<void> _deleteExactJobPair(String jobId) async {
    if (!_jobPattern.hasMatch(jobId)) {
      throw const SongSeparationFailure(
        SongSeparationFailureReason.outputFailed,
        detail: 'The managed stem job id is invalid.',
      );
    }
    final store = NativeManagedAudioStore(root);
    for (final locator in <String>[
      '$jobId-vocals.wav',
      '$jobId-accompaniment.wav',
    ]) {
      final source = File(_join(root.path, locator));
      final type = await FileSystemEntity.type(source.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw const SongSeparationFailure(
          SongSeparationFailureReason.outputFailed,
          detail: 'A managed stem is not a regular file.',
        );
      }
      await store.deleteManaged(locator);
    }
  }

  String _requireOwnedPair(SeparatedSongReference reference) {
    final vocals = reference.vocals;
    final accompaniment = reference.accompaniment;
    if (vocals == null ||
        accompaniment == null ||
        !vocals.identity.isWellFormed ||
        !accompaniment.identity.isWellFormed) {
      throw const SongSeparationFailure(
        SongSeparationFailureReason.outputFailed,
        detail: 'Both content-bound stems are required for managed ownership.',
      );
    }
    final vocalsMatch = _stemPattern.firstMatch(vocals.locator);
    final accompanimentMatch = _stemPattern.firstMatch(accompaniment.locator);
    if (vocalsMatch == null ||
        accompanimentMatch == null ||
        vocalsMatch.group(2) != 'vocals' ||
        accompanimentMatch.group(2) != 'accompaniment' ||
        vocalsMatch.group(1) != accompanimentMatch.group(1)) {
      throw const SongSeparationFailure(
        SongSeparationFailureReason.outputFailed,
        detail: 'Stem locators do not form an exact managed job pair.',
      );
    }
    return vocalsMatch.group(1)!;
  }

  Future<String> _prepareRoot() async {
    final type = await FileSystemEntity.type(root.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await root.create(recursive: true);
    }
    final preparedType = await FileSystemEntity.type(
      root.path,
      followLinks: false,
    );
    if (preparedType != FileSystemEntityType.directory) {
      throw const SongSeparationFailure(
        SongSeparationFailureReason.outputFailed,
        detail: 'The managed stem root is not a regular directory.',
      );
    }
    return root.resolveSymbolicLinks();
  }

  Future<void> _requireWritableManifestPath(File file, String rootPath) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.link ||
        type == FileSystemEntityType.directory) {
      throw const SongSeparationFailure(
        SongSeparationFailureReason.outputFailed,
        detail: 'The ownership staging path is unsafe.',
      );
    }
    _requireInside(rootPath, _join(rootPath, file.uri.pathSegments.last));
    if (type == FileSystemEntityType.file) await file.delete();
  }

  Future<void> _deleteRegularManifest(File file) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.file) {
      throw const SongSeparationFailure(
        SongSeparationFailureReason.outputFailed,
        detail: 'The ownership manifest is not a regular file.',
      );
    }
    await file.delete();
  }

  Future<bool> _isPastGrace(File file) async {
    final modified = await file.lastModified();
    return !_now().isBefore(modified.add(orphanGrace));
  }

  Future<bool> _isRegularFile(File file) async =>
      await FileSystemEntity.type(file.path, followLinks: false) ==
      FileSystemEntityType.file;

  void _requireInside(String rootPath, String sourcePath) {
    final normalizedRoot = _normalize(rootPath);
    final normalizedSource = _normalize(sourcePath);
    if (!normalizedSource.startsWith(
      '$normalizedRoot${Platform.pathSeparator}',
    )) {
      throw const SongSeparationFailure(
        SongSeparationFailureReason.outputFailed,
        detail: 'Managed ownership path escaped its root.',
      );
    }
  }

  String _normalize(String path) {
    final absolute = File(path).absolute.path;
    return Platform.isWindows ? absolute.toLowerCase() : absolute;
  }
}

final class _OwnedManifest {
  const _OwnedManifest({
    required this.file,
    required this.jobId,
    required this.activatedAtMicros,
    required this.reference,
  }) : isValid = true;

  _OwnedManifest.invalid({required this.file, required this.jobId})
    : activatedAtMicros = 0,
      reference = _invalidReference,
      isValid = false;

  final File file;
  final String jobId;
  final int activatedAtMicros;
  final SeparatedSongReference reference;
  final bool isValid;
}

const _invalidReference = SeparatedSongReference(
  displayName: '',
  generatedByModel: true,
  modelId: '',
  sampleRate: 1,
  channels: 1,
  durationSamples: 0,
  artifactWarning: true,
);

Map<String, Object?> _encodeReference(SeparatedSongReference reference) =>
    <String, Object?>{
      'displayName': reference.displayName,
      'generatedByModel': reference.generatedByModel,
      'modelId': reference.modelId,
      'sampleRate': reference.sampleRate,
      'channels': reference.channels,
      'durationSamples': reference.durationSamples,
      'artifactWarning': reference.artifactWarning,
      'algorithmVersion': reference.algorithmVersion,
      'sourceSampleRate': reference.sourceSampleRate,
      'sourceChannels': reference.sourceChannels,
      'chunkCount': reference.chunkCount,
      'vocals': _encodeStem(reference.vocals!),
      'accompaniment': _encodeStem(reference.accompaniment!),
    };

Map<String, Object?> _encodeStem(SongStemReference stem) => <String, Object?>{
  'locator': stem.locator,
  'sha256': stem.sha256,
  'byteLength': stem.byteLength,
};

SeparatedSongReference _decodeReference(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Invalid stem reference.');
  }
  final displayName = value['displayName'];
  final generatedByModel = value['generatedByModel'];
  final modelId = value['modelId'];
  final sampleRate = value['sampleRate'];
  final channels = value['channels'];
  final durationSamples = value['durationSamples'];
  final artifactWarning = value['artifactWarning'];
  final algorithmVersion = value['algorithmVersion'];
  final sourceSampleRate = value['sourceSampleRate'];
  final sourceChannels = value['sourceChannels'];
  final chunkCount = value['chunkCount'];
  if (displayName is! String ||
      displayName.length > 512 ||
      generatedByModel is! bool ||
      modelId is! String ||
      modelId.length > 256 ||
      sampleRate is! int ||
      sampleRate <= 0 ||
      channels is! int ||
      channels <= 0 ||
      durationSamples is! int ||
      durationSamples < 0 ||
      artifactWarning is! bool ||
      algorithmVersion is! String ||
      (sourceSampleRate != null && sourceSampleRate is! int) ||
      (sourceChannels != null && sourceChannels is! int) ||
      chunkCount is! int ||
      chunkCount < 0) {
    throw const FormatException('Invalid stem reference metadata.');
  }
  return SeparatedSongReference(
    displayName: displayName,
    generatedByModel: generatedByModel,
    modelId: modelId,
    sampleRate: sampleRate,
    channels: channels,
    durationSamples: durationSamples,
    artifactWarning: artifactWarning,
    algorithmVersion: algorithmVersion,
    sourceSampleRate: sourceSampleRate as int?,
    sourceChannels: sourceChannels as int?,
    chunkCount: chunkCount,
    vocals: _decodeStem(value['vocals']),
    accompaniment: _decodeStem(value['accompaniment']),
  );
}

SongStemReference _decodeStem(Object? value) {
  if (value is! Map<String, Object?> ||
      value['locator'] is! String ||
      value['sha256'] is! String ||
      value['byteLength'] is! int) {
    throw const FormatException('Invalid stem identity.');
  }
  return SongStemReference(
    locator: value['locator']! as String,
    sha256: value['sha256']! as String,
    byteLength: value['byteLength']! as int,
  );
}

bool _sameReference(
  SeparatedSongReference left,
  SeparatedSongReference right,
) =>
    left.vocals?.locator == right.vocals?.locator &&
    left.vocals?.identity == right.vocals?.identity &&
    left.accompaniment?.locator == right.accompaniment?.locator &&
    left.accompaniment?.identity == right.accompaniment?.identity;

int _newestFirst(_OwnedManifest left, _OwnedManifest right) {
  final activated = right.activatedAtMicros.compareTo(left.activatedAtMicros);
  return activated != 0 ? activated : right.jobId.compareTo(left.jobId);
}

String _join(String first, String second) =>
    <String>[first, second].join(Platform.pathSeparator);
