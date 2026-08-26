import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Future<void> main(List<String> arguments) async {
  final root = Directory(arguments.isEmpty ? 'build/web' : arguments.first);
  if (!root.existsSync()) {
    stderr.writeln('Web release directory does not exist: ${root.path}');
    exitCode = 2;
    return;
  }

  const required = <String>[
    'index.html',
    'flutter_bootstrap.js',
    'flutter_service_worker.js',
    'flutter.js',
    'main.dart.js',
    'lifecycle_client.js',
    'recording_store_client.js',
    'analysis_worker_client.js',
    'analysis_worker.js',
    'pkg/rust_lib_voice_trainer.js',
    'pkg/rust_lib_voice_trainer_bg.wasm',
    'drift_worker.js',
    'sqlite3.wasm',
    'version.json',
    'deployment_contract.json',
  ];
  final assets = <String, String>{};
  for (final relative in required) {
    final file = File(
      '${root.path}${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}',
    );
    if (!file.existsSync()) {
      throw StateError('Release is missing required asset: $relative');
    }
    assets[relative] = sha256.convert(await file.readAsBytes()).toString();
  }

  final canvasKit = root.listSync(recursive: true).whereType<File>().where((
    file,
  ) {
    final relative = _relativePath(root, file);
    return relative.startsWith('canvaskit/') &&
        (relative.endsWith('.js') || relative.endsWith('.wasm'));
  }).toList()..sort((left, right) => left.path.compareTo(right.path));
  if (canvasKit.isEmpty) {
    throw StateError(
      'Self-contained release must include local CanvasKit resources.',
    );
  }
  for (final file in canvasKit) {
    assets[_relativePath(root, file)] = sha256
        .convert(await file.readAsBytes())
        .toString();
  }

  final aggregate = assets.entries
      .map((entry) => '${entry.key}:${entry.value}')
      .join('\n');
  final releaseId = sha256.convert(utf8.encode(aggregate)).toString();
  final manifest = <String, Object?>{
    'schemaVersion': 1,
    'releaseId': releaseId,
    'runtimeMode': 'single-thread',
    'requiresCrossOriginIsolation': false,
    'assets': assets,
  };
  const encoder = JsonEncoder.withIndent('  ');
  await File(
    '${root.path}${Platform.pathSeparator}deployment_manifest.json',
  ).writeAsString('${encoder.convert(manifest)}\n');
  stdout.writeln(
    jsonEncode(<String, Object?>{
      'releaseId': releaseId,
      'criticalAssetCount': assets.length,
      'selfContainedCanvasKit': true,
    }),
  );
}

String _relativePath(Directory root, File file) {
  final rootPath = root.absolute.path.replaceAll('\\', '/');
  return file.absolute.path
      .replaceAll('\\', '/')
      .substring(rootPath.length + 1);
}
