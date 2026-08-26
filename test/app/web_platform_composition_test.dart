import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/app/default_adapters_web.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';
import 'package:voice_trainer/infrastructure/audio/fake_audio_capture.dart';
import 'package:voice_trainer/infrastructure/audio/record_audio_capture.dart';
import 'package:voice_trainer/infrastructure/dsp/fake_analysis_engine.dart';
import 'package:voice_trainer/infrastructure/dsp/rust_analysis_engine.dart';

void main() {
  test('Web composition selects record capture and Rust analysis', () {
    expect(
      createPlatformAudioCapture(PlatformCapabilities.web),
      isA<RecordAudioCapture>(),
    );
    expect(
      createPlatformAnalysisEngine(PlatformCapabilities.web),
      isA<RustAnalysisEngine>(),
    );
  });

  test('Web composition retains explicit fake overrides by capability', () {
    const fallback = PlatformCapabilities(
      target: PlatformTarget.web,
      capture: PlatformAdapterMode.fallback,
      persistence: PlatformAdapterMode.fallback,
      analysisWorker: AnalysisWorkerCapability.fallback,
      maximumRecordingDuration: Duration(seconds: 60),
      supportsDeviceSelection: false,
      supportsLifecycleEvents: false,
    );
    expect(createPlatformAudioCapture(fallback), isA<FakeAudioCapture>());
    expect(createPlatformAnalysisEngine(fallback), isA<FakeAnalysisEngine>());
  });
}
