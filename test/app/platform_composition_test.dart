import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/app/default_adapters.dart';
import 'package:voice_trainer/app/default_persistence.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';
import 'package:voice_trainer/infrastructure/audio/fake_audio_capture.dart';
import 'package:voice_trainer/infrastructure/dsp/fake_analysis_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Windows profile preserves native persistence composition', () async {
    final persistence = createDefaultPersistenceAdapters(
      PlatformCapabilities.windows,
    );
    expect(persistence.usesNativePersistence, isTrue);
    await persistence.dispose();
  });

  test('Android promotes adapter modes with in-memory persistence', () async {
    const capabilities = PlatformCapabilities.android;
    expect(capabilities.capture, PlatformAdapterMode.production);
    expect(capabilities.analysisWorker, AnalysisWorkerCapability.nativeWorker);

    final persistence = createDefaultPersistenceAdapters(capabilities);
    expect(persistence.usesNativePersistence, isFalse);
    await persistence.dispose();
  });

  test('Web and other native profiles retain adapter fallbacks', () async {
    for (final capabilities in const [
      PlatformCapabilities.web,
      PlatformCapabilities.otherNative,
    ]) {
      expect(createDefaultAudioCapture(capabilities), isA<FakeAudioCapture>());
      expect(
        createDefaultAnalysisEngine(capabilities),
        isA<FakeAnalysisEngine>(),
      );
      final persistence = createDefaultPersistenceAdapters(capabilities);
      expect(persistence.usesNativePersistence, isFalse);
      await persistence.dispose();
    }
  });
}
