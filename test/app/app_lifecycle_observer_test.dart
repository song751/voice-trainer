import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/app/app_lifecycle_observer.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_quality_flag.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/platform/application_lifecycle.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';
import 'package:voice_trainer/features/live_practice/application/live_practice_controller.dart';
import 'package:voice_trainer/features/live_practice/domain/practice_session_state.dart';
import 'package:voice_trainer/infrastructure/audio/fake_audio_capture.dart';
import 'package:voice_trainer/infrastructure/dsp/fake_analysis_engine.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_recording_store.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_session_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Flutter lifecycle states map to the bounded application vocabulary',
    () {
      expect(
        mapFlutterLifecycleState(AppLifecycleState.resumed),
        ApplicationLifecyclePhase.foreground,
      );
      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        expect(
          mapFlutterLifecycleState(state),
          ApplicationLifecyclePhase.background,
        );
      }
      expect(
        mapFlutterLifecycleState(AppLifecycleState.detached),
        ApplicationLifecyclePhase.detached,
      );
    },
  );

  test(
    'Android background pauses, foreground resumes, and marks a discontinuity',
    () async {
      final source = _FakeLifecycleSource();
      final capture = FakeAudioCapture();
      final store = InMemoryRecordingStore();
      final repository = InMemorySessionRepository(recordingStore: store);
      final container = ProviderContainer(
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(
            PlatformCapabilities.android,
          ),
          applicationLifecycleSourceProvider.overrideWith((ref) {
            ref.onDispose(source.dispose);
            return source;
          }),
          audioCaptureProvider.overrideWithValue(capture),
          analysisEngineProvider.overrideWithValue(FakeAnalysisEngine()),
          recordingStoreProvider.overrideWithValue(store),
          recordingSinkProvider.overrideWithValue(InMemoryRecordingSink(store)),
          sessionRepositoryProvider.overrideWithValue(repository),
          sessionIdGeneratorProvider.overrideWithValue(() => 'p4-05-lifecycle'),
        ],
      );
      addTearDown(container.dispose);
      container.read(applicationLifecycleBindingProvider);
      final controller = container.read(
        livePracticeControllerProvider.notifier,
      );

      await controller.start();
      expect(container.read(livePracticeControllerProvider), isA<Running>());
      capture.emit(_chunk(sequence: 0, firstSample: 0));
      await _drainEvents();

      source.emit(ApplicationLifecyclePhase.background);
      await _drainEvents();
      expect(container.read(livePracticeControllerProvider), isA<Paused>());

      source.emit(ApplicationLifecyclePhase.foreground);
      await _drainEvents();
      expect(container.read(livePracticeControllerProvider), isA<Running>());
      capture.emit(_chunk(sequence: 1, firstSample: 4));
      await _drainEvents();
      await controller.stop();

      final record = await repository.findById('p4-05-lifecycle');
      expect(record, isNotNull);
      expect(
        record!.summary.qualityFlags,
        contains(AnalysisQualityFlag.discontinuity),
      );
      expect(source.listenerCount, 1);
      container.dispose();
      expect(source.disposed, isTrue);
      expect(source.listenerCount, 0);
    },
  );

  test('manual pause is not undone by a lifecycle round trip', () async {
    final source = _FakeLifecycleSource();
    final capture = FakeAudioCapture();
    final store = InMemoryRecordingStore();
    final container = ProviderContainer(
      overrides: [
        platformCapabilitiesProvider.overrideWithValue(
          PlatformCapabilities.android,
        ),
        applicationLifecycleSourceProvider.overrideWith((ref) {
          ref.onDispose(source.dispose);
          return source;
        }),
        audioCaptureProvider.overrideWithValue(capture),
        analysisEngineProvider.overrideWithValue(FakeAnalysisEngine()),
        recordingStoreProvider.overrideWithValue(store),
        recordingSinkProvider.overrideWithValue(InMemoryRecordingSink(store)),
        sessionRepositoryProvider.overrideWithValue(
          InMemorySessionRepository(recordingStore: store),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(applicationLifecycleBindingProvider);
    final controller = container.read(livePracticeControllerProvider.notifier);

    await controller.start();
    await controller.pause();
    source.emit(ApplicationLifecyclePhase.background);
    source.emit(ApplicationLifecyclePhase.foreground);
    await _drainEvents();

    expect(container.read(livePracticeControllerProvider), isA<Paused>());
  });
}

PcmChunk _chunk({required int sequence, required int firstSample}) => PcmChunk(
  sequenceNumber: sequence,
  firstSampleIndex: firstSample,
  format: const CaptureFormat(sampleRate: 48000, channels: 1),
  bytes: Uint8List(8),
  captureMonotonicTime: Duration(microseconds: firstSample),
);

Future<void> _drainEvents() async {
  for (var index = 0; index < 8; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _FakeLifecycleSource implements ApplicationLifecycleSource {
  final StreamController<ApplicationLifecyclePhase> _controller =
      StreamController<ApplicationLifecyclePhase>.broadcast(
        sync: true,
        onListen: null,
      );
  ApplicationLifecyclePhase _phase = ApplicationLifecyclePhase.foreground;
  bool disposed = false;
  int listenerCount = 0;

  _FakeLifecycleSource() {
    _controller.onListen = () => listenerCount += 1;
    _controller.onCancel = () => listenerCount -= 1;
  }

  @override
  ApplicationLifecyclePhase get currentPhase => _phase;

  @override
  Stream<ApplicationLifecyclePhase> get phases => _controller.stream;

  void emit(ApplicationLifecyclePhase phase) {
    _phase = phase;
    _controller.add(phase);
  }

  @override
  void dispose() {
    if (disposed) return;
    disposed = true;
    unawaited(_controller.close());
  }
}
