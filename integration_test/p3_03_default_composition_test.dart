import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/infrastructure/audio/record_audio_capture.dart';
import 'package:voice_trainer/infrastructure/dsp/rust_analysis_engine.dart';

void main() {
  testWidgets('Windows default composition uses Record capture and Rust DSP', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(audioCaptureProvider), isA<RecordAudioCapture>());
    expect(container.read(analysisEngineProvider), isA<RustAnalysisEngine>());
    expect(
      container.read(defaultPersistenceAdaptersProvider).usesNativePersistence,
      isTrue,
    );
  });
}
