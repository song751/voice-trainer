import 'dart:io' show Platform;

import '../core/platform/platform_capabilities.dart';

PlatformCapabilities createPlatformCapabilities() {
  if (Platform.isWindows) return PlatformCapabilities.windows;
  if (Platform.isAndroid) return PlatformCapabilities.android;
  return PlatformCapabilities.otherNative;
}
