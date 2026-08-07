import '../core/domain/analysis/analysis_engine.dart';
import '../core/domain/audio/audio_capture.dart';
import 'default_adapters_native.dart'
    if (dart.library.js_interop) 'default_adapters_web.dart';

AudioCapture createDefaultAudioCapture() => createPlatformAudioCapture();

AnalysisEngine createDefaultAnalysisEngine() => createPlatformAnalysisEngine();
