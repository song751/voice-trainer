import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';

import 'package:voice_trainer/app/default_adapters.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_config.dart';
import 'package:voice_trainer/core/domain/audio/audio_capture.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/errors/failure.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';

void main() => runApp(const _P409WebCaptureGate());

final class _P409WebCaptureGate extends StatefulWidget {
  const _P409WebCaptureGate();

  @override
  State<_P409WebCaptureGate> createState() => _P409WebCaptureGateState();
}

final class _P409WebCaptureGateState extends State<_P409WebCaptureGate> {
  String _status = 'P4_09_WEB_CAPTURE_RUNNING';

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    final deniedOnly = Uri.base.queryParameters['mode'] == 'denied';
    final capture = createDefaultAudioCapture(PlatformCapabilities.web);
    final analysis = createDefaultAnalysisEngine(PlatformCapabilities.web);
    var stage = 'permission';
    try {
      final permission = await capture.requestPermission();
      if (deniedOnly) {
        if (permission is! PermissionDenied) {
          throw StateError('Expected denied browser microphone permission.');
        }
        _complete(<String, Object?>{
          'evidenceType': 'synthetic_browser_permission',
          'realMicrophone': false,
          'permission': 'denied',
          'captureStarted': false,
        }, 'P4_09_WEB_PERMISSION_DENIED_OK');
        return;
      }
      if (permission is! PermissionGranted) {
        throw StateError('Synthetic browser microphone permission was denied.');
      }

      stage = 'capture-start';
      final session = await capture.start(const CaptureRequest());
      final chunks = <PcmChunk>[];
      var samples = 0;
      final enoughPcm = Completer<void>();
      final subscription = session.pcmChunks.listen((chunk) {
        chunks.add(chunk);
        samples += chunk.frameCount;
        if (samples >= 48000 && !enoughPcm.isCompleted) enoughPcm.complete();
      }, onError: enoughPcm.completeError);
      try {
        stage = 'capture-stream';
        await enoughPcm.future.timeout(const Duration(seconds: 10));
      } finally {
        await session.stop();
        await subscription.cancel();
      }

      stage =
          'analysis-initialize-${session.effectiveFormat.sampleRate}hz-'
          '${session.effectiveFormat.channels}ch';
      try {
        await analysis.initialize(
          AnalysisConfig(inputFormat: session.effectiveFormat),
        );
      } on AnalysisFailure catch (failure) {
        if (failure.reason != AnalysisFailureReason.unsupportedFormat) rethrow;
        _complete(<String, Object?>{
          'evidenceType': 'synthetic_browser_capture',
          'realMicrophone': false,
          'permission': 'granted',
          'requestedSampleRate': 48000,
          'requestedChannels': 1,
          'requestedStreamBufferSamples': 512,
          'effectiveSampleRate': session.effectiveFormat.sampleRate,
          'effectiveChannels': session.effectiveFormat.channels,
          'chunkCount': chunks.length,
          'capturedSamples': samples,
          'chunkSampleSizes':
              chunks.map((chunk) => chunk.frameCount).toSet().toList()..sort(),
          'typedAnalysisFailure': failure.reason.name,
          'dedicatedWorkerValidatedSeparately': true,
        }, 'P4_09_WEB_CAPTURE_UNSUPPORTED_OK');
        return;
      }
      var frameCount = 0;
      stage = 'analysis-push';
      for (final chunk in chunks) {
        frameCount += (await analysis.pushPcm(
          PcmBatch(
            firstSampleIndex: chunk.firstSampleIndex,
            format: chunk.format,
            bytes: chunk.bytes,
          ),
        )).frames.length;
      }
      stage = 'analysis-finish';
      final finalized = await analysis.finish();
      _complete(<String, Object?>{
        'evidenceType': 'synthetic_browser_capture',
        'realMicrophone': false,
        'permission': 'granted',
        'requestedSampleRate': 48000,
        'requestedChannels': 1,
        'requestedStreamBufferSamples': 512,
        'effectiveSampleRate': session.effectiveFormat.sampleRate,
        'effectiveChannels': session.effectiveFormat.channels,
        'chunkCount': chunks.length,
        'capturedSamples': samples,
        'chunkSampleSizes':
            chunks.map((chunk) => chunk.frameCount).toSet().toList()..sort(),
        'analysisFrameCount': frameCount,
        'validFrameCount': finalized.segmentSummary.validFrameCount,
        'dedicatedWorkerExpected': true,
      }, 'P4_09_WEB_CAPTURE_OK');
    } catch (error, stackTrace) {
      _setStatus(
        'P4_09_WEB_CAPTURE_FAILED '
        '${jsonEncode(<String, String>{'stage': stage, 'error': '$error', 'stack': '$stackTrace'})}',
      );
    } finally {
      await analysis.dispose();
    }
  }

  void _complete(Map<String, Object?> report, String sentinel) {
    _setStatus('$sentinel ${jsonEncode(report)}');
  }

  void _setStatus(String value) {
    // The release smoke reads both this visible sentinel and browser console.
    globalContext.setProperty('voiceTrainerP409Status'.toJS, value.toJS);
    debugPrint(value);
    if (mounted) setState(() => _status = value);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: Center(child: SelectableText(_status))),
  );
}
