import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/app/default_persistence.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Windows profile preserves native persistence composition', () async {
    final persistence = createDefaultPersistenceAdapters(
      PlatformCapabilities.windows,
    );
    expect(persistence.usesNativePersistence, isTrue);
    await persistence.dispose();
  });

  test('unaccepted profiles receive in-memory persistence fallbacks', () async {
    for (final capabilities in const [
      PlatformCapabilities.android,
      PlatformCapabilities.web,
      PlatformCapabilities.otherNative,
    ]) {
      final persistence = createDefaultPersistenceAdapters(capabilities);
      expect(persistence.usesNativePersistence, isFalse);
      await persistence.dispose();
    }
  });
}
