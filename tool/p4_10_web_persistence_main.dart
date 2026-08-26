import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:voice_trainer/app/default_persistence.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/analysis/feature_series.dart';
import 'package:voice_trainer/core/domain/analysis/session_summary.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/domain/persistence/recording_sink.dart';
import 'package:voice_trainer/core/domain/persistence/recording_locator.dart';
import 'package:voice_trainer/core/domain/persistence/persistence_storage_report.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/core/errors/failure.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';

void main() => runApp(const _P410WebPersistenceGate());

final class _P410WebPersistenceGate extends StatefulWidget {
  const _P410WebPersistenceGate();

  @override
  State<_P410WebPersistenceGate> createState() =>
      _P410WebPersistenceGateState();
}

final class _P410WebPersistenceGateState
    extends State<_P410WebPersistenceGate> {
  String _status = 'P4_10_WEB_PERSISTENCE_RUNNING';

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    const capabilities = PlatformCapabilities(
      target: PlatformTarget.web,
      capture: PlatformAdapterMode.production,
      persistence: PlatformAdapterMode.production,
      analysisWorker: AnalysisWorkerCapability.dedicatedWebWorker,
      maximumRecordingDuration: Duration(seconds: 1),
      supportsDeviceSelection: false,
      supportsLifecycleEvents: false,
    );
    final adapters = createDefaultPersistenceAdapters(capabilities);
    var stage = 'storage-open';
    try {
      final storage = await adapters.storageReport();
      if (!storage.isPersistent ||
          storage.recordingStorageKind.name == 'none') {
        throw const PersistenceFailure(
          reason: PersistenceFailureReason.unavailable,
        );
      }
      final existing = await adapters.sessionRepository.findById(_sessionId);
      final action = Uri.base.queryParameters['action'];
      if (action == 'delete') {
        stage = 'delete';
        if (existing != null) {
          final locator = existing.recording;
          await adapters.sessionRepository.delete(_sessionId);
          if (locator != null &&
              await adapters.recordingStore.exists(locator)) {
            throw StateError('Deleted recording blob is still present.');
          }
        }
        if (await adapters.sessionRepository.findById(_sessionId) != null) {
          throw StateError('Deleted session is still present.');
        }
        _complete('P4_10_WEB_DELETE_OK', storage, <String, Object?>{
          'historyCount':
              (await adapters.sessionRepository.listRecent()).length,
        });
        return;
      }
      if (existing != null) {
        stage = 'reload-verify';
        final recording = existing.recording;
        if (recording == null ||
            !await adapters.recordingStore.exists(recording)) {
          throw StateError(
            'Reloaded session has a broken recording reference.',
          );
        }
        final history = await adapters.sessionRepository.listRecent();
        if (history.every((record) => record.id != _sessionId)) {
          throw StateError('Reloaded session is absent from history.');
        }
        _complete('P4_10_WEB_RESTORED_OK', storage, <String, Object?>{
          'historyCount': history.length,
          'recordingKind': recording.storageKind.name,
        });
        return;
      }

      stage = 'recording';
      await adapters.recordingSink.open(
        RecordingMetadata(sessionId: _sessionId, startedAt: _startedAt),
      );
      await adapters.recordingSink.append(
        _chunk(firstSampleIndex: 100, frameCount: 30000),
      );
      await adapters.recordingSink.append(
        _chunk(
          firstSampleIndex: 30100,
          frameCount: 20000,
          captureTime: const Duration(hours: 2),
        ),
      );
      final locator = await adapters.recordingSink.finalize();
      if (!await adapters.recordingStore.exists(locator)) {
        throw StateError('Finalized recording blob does not exist.');
      }

      stage = 'database-save';
      await adapters.sessionRepository.save(_record(locator));
      final restored = await adapters.sessionRepository.findById(_sessionId);
      if (restored?.recording?.value != locator.value) {
        throw StateError('Database did not retain the BlobStore locator.');
      }
      _complete('P4_10_WEB_CREATED_OK', storage, <String, Object?>{
        'recordingKind': locator.storageKind.name,
        'sampleLimitSeconds': 60,
        'gateLimitSeconds': 1,
        'pauseWallClockIgnored': true,
      });
    } on PersistenceFailure catch (failure) {
      _setStatus(
        'P4_10_WEB_PERSISTENCE_TYPED_FAILURE '
        '${jsonEncode(<String, String>{'stage': stage, 'reason': failure.reason.name})}',
      );
    } catch (error, stackTrace) {
      _setStatus(
        'P4_10_WEB_PERSISTENCE_FAILED '
        '${jsonEncode(<String, String>{'stage': stage, 'error': '$error', 'stack': '$stackTrace'})}',
      );
    } finally {
      await adapters.dispose();
    }
  }

  void _complete(
    String sentinel,
    PersistenceStorageReport storage,
    Map<String, Object?> extra,
  ) {
    _setStatus(
      '$sentinel '
      '${jsonEncode(<String, Object?>{'evidenceType': 'synthetic_browser_storage', 'structuredStorageKind': storage.structuredDataKind, 'recordingStorageKind': storage.recordingStorageKind.name, 'persistent': storage.isPersistent, ...extra})}',
    );
  }

  void _setStatus(String value) {
    globalContext.setProperty('voiceTrainerP410Status'.toJS, value.toJS);
    debugPrint(value);
    if (mounted) setState(() => _status = value);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: Center(child: SelectableText(_status))),
  );
}

const _sessionId = 'p4-10-web-persistence-gate';
final _startedAt = DateTime.utc(2026, 8, 27);
const _format = CaptureFormat(sampleRate: 48000, channels: 1);

PcmChunk _chunk({
  required int firstSampleIndex,
  required int frameCount,
  Duration captureTime = Duration.zero,
}) => PcmChunk(
  sequenceNumber: firstSampleIndex,
  firstSampleIndex: firstSampleIndex,
  format: _format,
  bytes: Uint8List(frameCount * _format.bytesPerFrame),
  captureMonotonicTime: captureTime,
);

PracticeSessionRecord _record(RecordingLocator locator) =>
    PracticeSessionRecord(
      id: _sessionId,
      template: const PracticeTemplate(
        id: 'p4-10-storage-gate',
        version: 1,
        kind: PracticeKind.sustainedNote,
        target: PracticeTarget(targetMidiNote: 57),
        reviewStatus: ContentReviewStatus.draft,
      ),
      startedAt: _startedAt,
      summary: SessionSummary(
        validFrameCount: 1,
        totalFrameCount: 1,
        qualityFlags: const {},
      ),
      features: FeatureSeries(
        frameRateHz: 100,
        frames: <AnalysisFrame>[
          AnalysisFrame(
            sampleIndex: 100,
            rmsDbfs: -24,
            peakDbfs: -6,
            pitchClarity: 0.8,
            voiced: true,
            f0Hz: 220,
            algorithmVersion: 'p4-10-gate-v1',
          ),
        ],
      ),
      recording: locator,
    );
