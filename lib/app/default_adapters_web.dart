import '../core/domain/analysis/analysis_engine.dart';
import '../core/domain/audio/audio_capture.dart';
import '../infrastructure/audio/fake_audio_capture.dart';
import '../infrastructure/dsp/fake_analysis_engine.dart';

/// Web promotion is intentionally deferred to its own Phase 4 device gate.
AudioCapture createPlatformAudioCapture() => FakeAudioCapture();

AnalysisEngine createPlatformAnalysisEngine() => FakeAnalysisEngine();
