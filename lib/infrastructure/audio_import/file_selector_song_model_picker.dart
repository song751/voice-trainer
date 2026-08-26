import 'package:file_selector/file_selector.dart';

import '../../core/domain/reference/song_reference.dart';

final class FileSelectorSongModelPicker {
  const FileSelectorSongModelPicker();

  static const _modelType = XTypeGroup(
    label: 'UMX-HQ ONNX model',
    extensions: <String>['onnx'],
    mimeTypes: <String>['application/octet-stream'],
  );

  Future<SongFileSource?> pickModel() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_modelType],
    );
    return file == null ? null : _SelectedModelFile(file);
  }
}

final class _SelectedModelFile implements SongFileSource {
  const _SelectedModelFile(this._file);

  final XFile _file;

  @override
  String get displayName => _file.name;

  @override
  Future<int> length() => _file.length();

  @override
  Stream<List<int>> openRead() => _file.openRead();
}
