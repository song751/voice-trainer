import '../core/platform/application_lifecycle.dart';
import '../core/platform/platform_capabilities.dart';
import '../infrastructure/lifecycle/web_application_lifecycle.dart';

ApplicationLifecycle createPlatformApplicationLifecycle(
  PlatformCapabilities capabilities,
) => capabilities.supportsLifecycleEvents
    ? WebApplicationLifecycle()
    : const InactiveApplicationLifecycle();
