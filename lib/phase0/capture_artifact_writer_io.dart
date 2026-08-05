import 'dart:io';
import 'dart:typed_data';

Future<String?> writeCaptureArtifact(Uint8List bytes, String fileName) async {
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
