import 'package:file_selector/file_selector.dart';

import '../../core/domain/reference/song_reference.dart';

final class FileSelectorSongPicker implements SongFilePicker {
  const FileSelectorSongPicker();

  static const _audioTypes = XTypeGroup(
    label: 'audio',
    extensions: <String>['wav', 'mp3', 'flac', 'm4a', 'aac', 'ogg'],
    mimeTypes: <String>[
      'audio/wav',
      'audio/mpeg',
      'audio/flac',
      'audio/mp4',
      'audio/aac',
      'audio/ogg',
    ],
    webWildCards: <String>['audio/*'],
  );

  @override
  Future<SongFileSource?> pickSong() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_audioTypes],
    );
    return file == null ? null : _SelectedSongFile(file);
  }
}

final class _SelectedSongFile implements SongFileSource {
  const _SelectedSongFile(this._file);

  final XFile _file;

  @override
  String get displayName => _file.name;

  @override
  Future<int> length() => _file.length();

  @override
  Stream<List<int>> openRead() => _file.openRead();
}
