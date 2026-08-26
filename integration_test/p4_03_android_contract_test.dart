import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_engine.dart';
import 'package:voice_trainer/core/domain/audio/audio_capture.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/core/errors/failure.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';
import 'package:voice_trainer/features/live_practice/application/practice_session_coordinator.dart';
import 'package:voice_trainer/features/live_practice/domain/practice_session_state.dart';
import 'package:voice_trainer/infrastructure/audio/fake_audio_capture.dart';
import 'package:voice_trainer/infrastructure/audio/record_audio_capture.dart';
import 'package:voice_trainer/infrastructure/dsp/fake_analysis_engine.dart';
import 'package:voice_trainer/infrastructure/dsp/rust_analysis_engine.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_recording_store.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_session_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Android composition promotes capture and DSP but keeps fake overrides',
    () {
      final production = ProviderContainer(
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(
            PlatformCapabilities.android,
          ),
        ],
      );
      addTearDown(production.dispose);

      expect(production.read(audioCaptureProvider), isA<RecordAudioCapture>());
      expect(
        production.read(analysisEngineProvider),
        isA<RustAnalysisEngine>(),
      );
      expect(
        production
            .read(defaultPersistenceAdaptersProvider)
            .usesNativePersistence,
        isFalse,
      );

      final fakeCapture = FakeAudioCapture();
      final fakeAnalysis = FakeAnalysisEngine();
      final overridden = ProviderContainer(
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(
            PlatformCapabilities.android,
          ),
          audioCaptureProvider.overrideWithValue(fakeCapture),
          analysisEngineProvider.overrideWithValue(fakeAnalysis),
        ],
      );
      addTearDown(overridden.dispose);
      expect(overridden.read(audioCaptureProvider), same(fakeCapture));
      expect(overridden.read(analysisEngineProvider), same(fakeAnalysis));
    },
  );

  test(
    'permission allow and deny remain typed through the coordinator',
    () async {
      final deniedCapture = FakeAudioCapture(
        permissionResult: const PermissionDenied(PermissionDeniedFailure()),
      );
      final denied = _coordinator(
        capture: deniedCapture,
        analysis: FakeAnalysisEngine(),
      );
      addTearDown(denied.dispose);

      final deniedState = await denied.start(_request('p4-03-denied'));
      expect(deniedState, isA<Failed>());
      expect((deniedState as Failed).failure, isA<PermissionDeniedFailure>());
      expect(deniedCapture.startCallCount, 0);

      final allowed = _coordinator(
        capture: FakeAudioCapture(),
        analysis: FakeAnalysisEngine(),
      );
      addTearDown(allowed.dispose);
      expect(await allowed.start(_request('p4-03-allowed')), isA<Running>());
      expect(await allowed.pause(), isA<Paused>());
      expect(await allowed.resume(), isA<Running>());
      expect(await allowed.stop(), isA<Completed>());
    },
  );

  test('unsupported and changed effective formats remain typed', () async {
    final unsupported = _coordinator(
      capture: FakeAudioCapture(
        effectiveFormat: const CaptureFormat(sampleRate: 44100, channels: 1),
      ),
      analysis: FakeAnalysisEngine(
        initializeFailure: const AnalysisFailure(
          AnalysisFailureReason.unsupportedFormat,
        ),
      ),
    );
    addTearDown(unsupported.dispose);
    final unsupportedState = await unsupported.start(
      _request('p4-03-unsupported'),
    );
    expect(unsupportedState, isA<Failed>());
    expect(
      (unsupportedState as Failed).failure,
      isA<AnalysisFailure>().having(
        (failure) => failure.reason,
        'reason',
        AnalysisFailureReason.unsupportedFormat,
      ),
    );

    final changedCapture = FakeAudioCapture();
    final changed = _coordinator(
      capture: changedCapture,
      analysis: FakeAnalysisEngine(),
    );
    addTearDown(changed.dispose);
    expect(await changed.start(_request('p4-03-changed')), isA<Running>());
    changedCapture.emit(
      _chunk(
        sequence: 0,
        firstSample: 0,
        format: const CaptureFormat(sampleRate: 44100, channels: 1),
      ),
    );
    await _drainMicrotasks();
    expect(changed.state, isA<Failed>());
    expect(
      (changed.state as Failed).failure,
      isA<AnalysisFailure>().having(
        (failure) => failure.reason,
        'reason',
        AnalysisFailureReason.formatChanged,
      ),
    );
  });

  test(
    'worker failure and queue drop produce typed bounded outcomes',
    () async {
      final failedCapture = FakeAudioCapture();
      final failed = _coordinator(
        capture: failedCapture,
        analysis: FakeAnalysisEngine(failPushes: 1),
      );
      addTearDown(failed.dispose);
      expect(
        await failed.start(_request('p4-03-worker-failure')),
        isA<Running>(),
      );
      failedCapture.emit(_chunk(sequence: 0, firstSample: 0));
      await _drainMicrotasks();
      expect(failed.state, isA<Failed>());
      expect(
        (failed.state as Failed).failure,
        isA<AnalysisFailure>().having(
          (failure) => failure.reason,
          'reason',
          AnalysisFailureReason.processing,
        ),
      );

      final gate = Completer<void>();
      final overflowCapture = FakeAudioCapture();
      final overflowAnalysis = FakeAnalysisEngine(
        beforePush: () => gate.future,
      );
      final overflow = _coordinator(
        capture: overflowCapture,
        analysis: overflowAnalysis,
        maxQueuedSamples: 8,
      );
      addTearDown(overflow.dispose);
      expect(
        await overflow.start(_request('p4-03-queue-drop')),
        isA<Running>(),
      );
      overflowCapture.emit(_chunk(sequence: 0, firstSample: 0));
      await _drainMicrotasks();
      overflowCapture.emit(_chunk(sequence: 1, firstSample: 4));
      overflowCapture.emit(_chunk(sequence: 2, firstSample: 8));
      overflowCapture.emit(_chunk(sequence: 3, firstSample: 12));
      final stopped = overflow.stop();
      gate.complete();
      expect(await stopped, isA<Completed>());
      expect(overflow.analysisQueueAccounting.droppedSamples, 4);
      expect(overflow.analysisQueueAccounting.hasDiscontinuity, isTrue);
      expect(
        overflowAnalysis.receivedBatches.map((batch) => batch.firstSampleIndex),
        <int>[0, 8, 12],
      );
    },
  );
}

PracticeSessionCoordinator _coordinator({
  required AudioCapture capture,
  required AnalysisEngine analysis,
  int maxQueuedSamples = 12000,
}) {
  final store = InMemoryRecordingStore();
  return PracticeSessionCoordinator(
    audioCapture: capture,
    analysisEngine: analysis,
    recordingSink: InMemoryRecordingSink(store),
    recordingStore: store,
    sessionRepository: InMemorySessionRepository(recordingStore: store),
    maxQueuedSamples: maxQueuedSamples,
  );
}

PracticeSessionRequest _request(String sessionId) => PracticeSessionRequest(
  sessionId: sessionId,
  template: const PracticeTemplate(
    id: 'p4-03-target-note',
    version: 1,
    kind: PracticeKind.targetNote,
    target: PracticeTarget(targetMidiNote: 57),
    reviewStatus: ContentReviewStatus.approved,
  ),
  startedAt: DateTime.utc(2026, 8, 26),
);

PcmChunk _chunk({
  required int sequence,
  required int firstSample,
  CaptureFormat format = const CaptureFormat(sampleRate: 48000, channels: 1),
}) => PcmChunk(
  sequenceNumber: sequence,
  firstSampleIndex: firstSample,
  format: format,
  bytes: Uint8List(8),
  captureMonotonicTime: Duration(microseconds: firstSample),
);

Future<void> _drainMicrotasks() => Future<void>.delayed(Duration.zero);
