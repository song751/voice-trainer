import 'dart:io';

Future<void> main(List<String> arguments) async {
  final port = arguments.isEmpty ? 7394 : int.parse(arguments.first);
  final root = Directory(
    arguments.length < 2 ? 'build/web' : arguments[1],
  ).absolute;
  if (!root.existsSync()) {
    stderr.writeln('Web root does not exist: ${root.path}');
    exitCode = 2;
    return;
  }
  final rootPath = root.resolveSymbolicLinksSync();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('P4_09_WEB_SERVER_READY http://127.0.0.1:$port');

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
    request.response.headers.contentType = _contentType(resolved);
    request.response.headers.set('Cache-Control', 'no-store');
    await request.response.addStream(File(resolved).openRead());
    await request.response.close();
  }
}

ContentType _contentType(String path) {
  final dot = path.lastIndexOf('.');
  final extension = dot < 0 ? '' : path.substring(dot).toLowerCase();
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
