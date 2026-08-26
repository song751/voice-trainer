import '../../core/domain/reference/song_reference.dart';
import '../../core/platform/platform_capabilities.dart';
import 'native_rust_song_separator.dart';

SongSeparator createPlatformSongSeparator(PlatformCapabilities capabilities) =>
    switch (capabilities.target) {
      PlatformTarget.windows ||
      PlatformTarget.android => NativeRustSongSeparator(),
      PlatformTarget.web ||
      PlatformTarget.otherNative => const UnavailableSongSeparator(),
    };
