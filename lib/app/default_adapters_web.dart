import '../core/domain/analysis/analysis_engine.dart';
import '../core/domain/audio/audio_capture.dart';
import '../core/platform/platform_capabilities.dart';
import '../infrastructure/audio/fake_audio_capture.dart';
import '../infrastructure/audio/record_audio_capture.dart';
import '../infrastructure/dsp/fake_analysis_engine.dart';
import '../infrastructure/dsp/rust_analysis_engine.dart';

AudioCapture createPlatformAudioCapture(PlatformCapabilities capabilities) =>
    capabilities.capture == PlatformAdapterMode.production
    ? RecordAudioCapture(fallbackStreamBufferSamples: 1024)
    : FakeAudioCapture();

AnalysisEngine createPlatformAnalysisEngine(
  PlatformCapabilities capabilities,
) => capabilities.analysisWorker == AnalysisWorkerCapability.dedicatedWebWorker
    ? RustAnalysisEngine()
    : FakeAnalysisEngine();
