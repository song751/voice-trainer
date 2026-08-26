import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';

void main() {
  test('Windows keeps the accepted production composition', () {
    const capabilities = PlatformCapabilities.windows;

    expect(capabilities.capture, PlatformAdapterMode.production);
    expect(capabilities.persistence, PlatformAdapterMode.production);
    expect(capabilities.analysisWorker, AnalysisWorkerCapability.nativeWorker);
    expect(capabilities.maximumRecordingDuration, isNull);
    expect(capabilities.supportsDeviceSelection, isTrue);
    expect(capabilities.supportsLifecycleEvents, isFalse);
  });

  test('Android promotes capture, Rust, and native persistence', () {
    const capabilities = PlatformCapabilities.android;

    expect(capabilities.capture, PlatformAdapterMode.production);
    expect(capabilities.persistence, PlatformAdapterMode.production);
    expect(capabilities.analysisWorker, AnalysisWorkerCapability.nativeWorker);
    expect(capabilities.maximumRecordingDuration, isNull);
    expect(capabilities.supportsDeviceSelection, isFalse);
    expect(capabilities.supportsLifecycleEvents, isFalse);
  });

  test('Web promotes capture and dedicated worker but not persistence', () {
    const capabilities = PlatformCapabilities.web;

    expect(capabilities.capture, PlatformAdapterMode.production);
    expect(capabilities.persistence, PlatformAdapterMode.fallback);
    expect(
      capabilities.analysisWorker,
      AnalysisWorkerCapability.dedicatedWebWorker,
    );
    expect(capabilities.maximumRecordingDuration, const Duration(seconds: 60));
    expect(capabilities.supportsDeviceSelection, isFalse);
    expect(capabilities.supportsLifecycleEvents, isFalse);
  });

  test(
    'other native targets are represented without importing platform APIs',
    () {
      const capabilities = PlatformCapabilities.otherNative;

      expect(capabilities.capture, PlatformAdapterMode.fallback);
      expect(capabilities.persistence, PlatformAdapterMode.fallback);
      expect(capabilities.analysisWorker, AnalysisWorkerCapability.fallback);
      expect(capabilities.maximumRecordingDuration, isNull);
    },
  );
}
