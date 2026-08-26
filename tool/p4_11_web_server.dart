import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final port = arguments.isEmpty ? 7397 : int.parse(arguments.first);
  final root = Directory(
    arguments.length < 2 ? 'build/web' : arguments[1],
  ).absolute;
  if (!root.existsSync()) {
    stderr.writeln('Web root does not exist: ${root.path}');
    exitCode = 2;
    return;
  }
  final manifestFile = File(
    '${root.path}${Platform.pathSeparator}deployment_manifest.json',
  );
  final contractFile = File(
    '${root.path}${Platform.pathSeparator}deployment_contract.json',
  );
  if (!manifestFile.existsSync() || !contractFile.existsSync()) {
    stderr.writeln('Prepared P4-11 deployment metadata is missing.');
    exitCode = 2;
    return;
  }
  final manifest = jsonDecode(await manifestFile.readAsString());
  final contract = jsonDecode(await contractFile.readAsString());
  if (manifest is! Map<String, Object?> ||
      manifest['releaseId'] is! String ||
      contract is! Map<String, Object?> ||
      contract['contentSecurityPolicy'] is! String ||
      contract['criticalAssetCacheControl'] is! String) {
    stderr.writeln('Invalid P4-11 deployment metadata.');
    exitCode = 2;
    return;
  }
  final releaseId = manifest['releaseId']! as String;
  final csp = contract['contentSecurityPolicy']! as String;
  final criticalCache = contract['criticalAssetCacheControl']! as String;
  final rootPath = root.resolveSymbolicLinksSync();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('P4_11_WEB_SERVER_READY http://127.0.0.1:$port');

  await for (final request in server) {
    final relative = request.uri.pathSegments.isEmpty
        ? 'index.html'
        : request.uri.pathSegments.join(Platform.pathSeparator);
    final candidate = File('${root.path}${Platform.pathSeparator}$relative');
    String resolved;
    try {
      resolved = candidate.resolveSymbolicLinksSync();
    } on FileSystemException {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }
    if (!resolved.startsWith('$rootPath${Platform.pathSeparator}') ||
        !File(resolved).existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }
    final response = request.response;
    response.headers.contentType = _contentType(resolved);
    response.headers.set(
      'Cache-Control',
      _isCritical(relative) ? criticalCache : 'public, max-age=86400',
    );
    response.headers.set('Content-Security-Policy', csp);
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('Referrer-Policy', 'no-referrer');
    response.headers.set('Permissions-Policy', 'microphone=(self)');
    response.headers.set('X-Voice-Trainer-Release', releaseId);
    await response.addStream(File(resolved).openRead());
    await response.close();
  }
}

bool _isCritical(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.html') ||
      lower.endsWith('.js') ||
      lower.endsWith('.wasm') ||
      lower.endsWith('.json');
}

ContentType _contentType(String path) {
  final extension = path.substring(path.lastIndexOf('.')).toLowerCase();
  return switch (extension) {
    '.css' => ContentType('text', 'css', charset: 'utf-8'),
    '.html' => ContentType.html,
    '.js' => ContentType('text', 'javascript', charset: 'utf-8'),
    '.json' => ContentType.json,
    '.png' => ContentType('image', 'png'),
    '.svg' => ContentType('image', 'svg+xml'),
    '.wasm' => ContentType('application', 'wasm'),
    _ => ContentType.binary,
  };
}
