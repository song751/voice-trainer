import '../core/platform/application_lifecycle.dart';
import '../core/platform/platform_capabilities.dart';
import 'default_lifecycle_native.dart'
    if (dart.library.js_interop) 'default_lifecycle_web.dart';

ApplicationLifecycle createDefaultApplicationLifecycle(
  PlatformCapabilities capabilities,
) => createPlatformApplicationLifecycle(capabilities);
