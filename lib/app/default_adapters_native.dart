import 'dart:io' show Platform;

import '../core/domain/analysis/analysis_engine.dart';
import '../core/domain/audio/audio_capture.dart';
import '../infrastructure/audio/fake_audio_capture.dart';
import '../infrastructure/audio/record_audio_capture.dart';
import '../infrastructure/dsp/fake_analysis_engine.dart';
import '../infrastructure/dsp/rust_analysis_engine.dart';

/// P3-03 promotes the tested Windows adapters only. Other native platforms
/// remain on the deterministic fallback until their own device contracts are
/// accepted.
AudioCapture createPlatformAudioCapture() =>
    Platform.isWindows ? RecordAudioCapture() : FakeAudioCapture();

AnalysisEngine createPlatformAnalysisEngine() =>
    Platform.isWindows ? RustAnalysisEngine() : FakeAnalysisEngine();
