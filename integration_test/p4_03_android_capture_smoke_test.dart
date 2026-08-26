import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_config.dart';
import 'package:voice_trainer/core/domain/audio/audio_capture.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/capture_health.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/errors/failure.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';
import 'package:voice_trainer/infrastructure/audio/record_audio_capture.dart';
import 'package:voice_trainer/infrastructure/dsp/rust_analysis_engine.dart';

const _permissionExpectation = String.fromEnvironment(
  'P4_03_PERMISSION',
  defaultValue: 'allow',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android record plugin and Rust worker expose honest evidence', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    expect(const {'allow', 'deny'}, contains(_permissionExpectation));

    final evidence = await tester.runAsync(_runCaptureSmoke);
    expect(evidence, isNotNull);
    // A single JSON line is easy for the ADB runner to retain and validate.
    // It contains no PCM, device identifiers, paths, or user content.
    // ignore: avoid_print
    print('P4_03_ANDROID_EVIDENCE=${jsonEncode(evidence)}');
  });
}

Future<Map<String, Object?>> _runCaptureSmoke() async {
  final container = ProviderContainer(
    overrides: [
      platformCapabilitiesProvider.overrideWithValue(
        PlatformCapabilities.android,
      ),
    ],
  );
  try {
    final capture = container.read(audioCaptureProvider);
    final analysis = container.read(analysisEngineProvider);
    expect(capture, isA<RecordAudioCapture>());
    expect(analysis, isA<RustAnalysisEngine>());
    expect(
      container.read(defaultPersistenceAdaptersProvider).usesNativePersistence,
      isFalse,
    );

    final permission = await capture.requestPermission();
    if (_permissionExpectation == 'deny') {
      expect(permission, isA<PermissionDenied>());
      return _baseEvidence(permission: 'denied')..addAll({
        'captureOutcome': 'not-started',
        'zeroInput': true,
        'analysisFrameCount': 0,
      });
    }
    expect(permission, isA<PermissionGranted>());

    const request = CaptureRequest(
      format: CaptureFormat(sampleRate: 48000, channels: 1),
    );
    final session = await capture.start(request);
    final chunks = <PcmChunk>[];
    final health = <CaptureHealth>[];
    var capturedSamples = 0;
    final chunkSubscription = session.pcmChunks.listen((chunk) {
      if (capturedSamples < 48000) {
        chunks.add(chunk);
        capturedSamples += chunk.frameCount;
      }
    });
    final healthSubscription = session.health.listen(health.add);
    try {
      await Future<void>.delayed(const Duration(seconds: 2));
      await session.pause();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await session.resume();
      await Future<void>.delayed(const Duration(seconds: 2));
    } finally {
      await session.stop();
      await chunkSubscription.cancel();
      await healthSubscription.cancel();
    }

    for (var index = 1; index < chunks.length; index += 1) {
      expect(
        chunks[index].firstSampleIndex,
        greaterThanOrEqualTo(chunks[index - 1].endSampleIndexExclusive),
      );
    }

    var analysisOutcome = 'zero-input';
    var analysisFrameCount = 0;
    AnalysisFailureReason? typedFailure;
    try {
      await analysis.initialize(
        AnalysisConfig(inputFormat: session.effectiveFormat),
      );
      for (final chunk in chunks) {
        final batch = await analysis.pushPcm(
          PcmBatch(
            firstSampleIndex: chunk.firstSampleIndex,
            format: chunk.format,
            bytes: chunk.bytes,
            droppedSamplesBefore: chunk.droppedSamplesBefore,
            discontinuityBefore: chunk.discontinuityBefore,
          ),
        );
        analysisFrameCount += batch.frames.length;
      }
      await analysis.finish();
      analysisOutcome = chunks.isEmpty ? 'zero-input' : 'processed-plugin-pcm';
    } on AnalysisFailure catch (failure) {
      typedFailure = failure.reason;
      expect(
        failure.reason,
        anyOf(
          AnalysisFailureReason.unsupportedFormat,
          AnalysisFailureReason.formatChanged,
        ),
      );
      analysisOutcome = 'typed-${failure.reason.name}';
    } finally {
      await analysis.dispose();
    }

    final effective = session.effectiveFormat;
    return _baseEvidence(permission: 'granted')..addAll({
      'captureOutcome': chunks.isEmpty ? 'zero-input' : 'plugin-pcm',
      'requestedSampleRate': request.format.sampleRate,
      'requestedChannels': request.format.channels,
      'effectiveSampleRate': effective.sampleRate,
      'effectiveChannels': effective.channels,
      'chunkCount': chunks.length,
      'sampleCount': chunks.fold<int>(
        0,
        (sum, chunk) => sum + chunk.frameCount,
      ),
      'zeroInput': chunks.isEmpty,
      'analysisOutcome': analysisOutcome,
      'analysisFrameCount': analysisFrameCount,
      'typedFailure': typedFailure?.name,
      'formatChangeEvents': health
          .where(
            (event) =>
                event.effectiveFormat !=
                const CaptureFormat(sampleRate: 48000, channels: 1),
          )
          .length,
    });
  } finally {
    container.dispose();
  }
}

Map<String, Object?> _baseEvidence({required String permission}) => {
  'evidenceType': 'emulator',
  'emulator': true,
  'realDevice': false,
  'synthetic': false,
  'permission': permission,
  'defaultCapture': 'record',
  'defaultAnalysis': 'rust-native-worker',
  'persistence': 'fallback',
};
