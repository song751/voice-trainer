import '../core/platform/platform_capabilities.dart';
import 'platform_capabilities_native.dart'
    if (dart.library.js_interop) 'platform_capabilities_web.dart';

PlatformCapabilities createDefaultPlatformCapabilities() =>
    createPlatformCapabilities();
