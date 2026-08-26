import '../core/platform/application_lifecycle.dart';
import '../core/platform/platform_capabilities.dart';

ApplicationLifecycle createPlatformApplicationLifecycle(
  PlatformCapabilities capabilities,
) => const InactiveApplicationLifecycle();
