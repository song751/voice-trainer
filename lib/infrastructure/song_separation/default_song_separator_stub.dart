import '../../core/domain/reference/song_reference.dart';
import '../../core/platform/platform_capabilities.dart';

SongSeparator createPlatformSongSeparator(PlatformCapabilities capabilities) =>
    const UnavailableSongSeparator();
