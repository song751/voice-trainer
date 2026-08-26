import '../../core/domain/reference/song_reference.dart';
import '../../core/platform/platform_capabilities.dart';
import 'default_song_separator_stub.dart'
    if (dart.library.io) 'default_song_separator_native.dart';

SongSeparator createDefaultSongSeparator(PlatformCapabilities capabilities) =>
    createPlatformSongSeparator(capabilities);
