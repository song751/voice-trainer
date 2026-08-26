import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/app/app.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/app/router/app_router.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_engine.dart';
import 'package:voice_trainer/core/domain/audio/audio_capture.dart';
import 'package:voice_trainer/core/domain/persistence/recording_sink.dart';
import 'package:voice_trainer/core/domain/persistence/recording_store.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/domain/persistence/voice_comparison_plan_store.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';
import 'package:voice_trainer/infrastructure/audio/fake_audio_capture.dart';
import 'package:voice_trainer/infrastructure/dsp/fake_analysis_engine.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_recording_store.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_session_repository.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_voice_comparison_plan_store.dart';

final class P412UiProfile {
  const P412UiProfile({
    required this.name,
    required this.capabilities,
    required this.size,
    this.devicePixelRatio = 1,
  });

  final String name;
  final PlatformCapabilities capabilities;
  final Size size;
  final double devicePixelRatio;

  static const windowsPortrait = P412UiProfile(
    name: 'windows-portrait-contract',
    capabilities: PlatformCapabilities.windows,
    size: Size(393, 852),
  );

  static const androidPortrait = P412UiProfile(
    name: 'android-portrait-contract',
    capabilities: PlatformCapabilities.android,
    size: Size(393, 852),
    devicePixelRatio: 3,
  );

  static const webPortrait = P412UiProfile(
    name: 'web-portrait-contract',
    capabilities: PlatformCapabilities.web,
    size: Size(393, 852),
  );

  static const windowsWide = P412UiProfile(
    name: 'windows-wide-contract',
    capabilities: PlatformCapabilities.windows,
    size: Size(1280, 800),
  );
}

final class P412UiFixture {
  const P412UiFixture(this.tester);

  final WidgetTester tester;

  Future<void> pump({
    required P412UiProfile profile,
    required String route,
    double textScaleFactor = 1,
    Brightness brightness = Brightness.light,
    AudioCapture? capture,
    AnalysisEngine? analysis,
    RecordingStore? recordingStore,
    RecordingSink? recordingSink,
    SessionRepository? repository,
    VoiceComparisonPlanStore? voiceComparisonPlanStore,
    List<Override> extraOverrides = const <Override>[],
  }) async {
    // Dispose the previous route tree between matrix cases so scroll offsets,
    // provider state, and asynchronous adapter teardown cannot leak forward.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final store = recordingStore ?? InMemoryRecordingStore();
    final sessionRepository =
        repository ?? InMemorySessionRepository(recordingStore: store);
    tester.view.devicePixelRatio = profile.devicePixelRatio;
    tester.view.physicalSize = profile.size * profile.devicePixelRatio;
    tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appInitialLocationProvider.overrideWithValue(route),
          platformCapabilitiesProvider.overrideWithValue(profile.capabilities),
          audioCaptureProvider.overrideWithValue(capture ?? FakeAudioCapture()),
          analysisEngineProvider.overrideWithValue(
            analysis ?? FakeAnalysisEngine(),
          ),
          recordingStoreProvider.overrideWithValue(store),
          recordingSinkProvider.overrideWithValue(
            recordingSink ??
                (store is InMemoryRecordingStore
                    ? InMemoryRecordingSink(store)
                    : throw ArgumentError(
                        'A recording sink is required for a custom store.',
                      )),
          ),
          sessionRepositoryProvider.overrideWithValue(sessionRepository),
          voiceComparisonPlanStoreProvider.overrideWithValue(
            voiceComparisonPlanStore ?? InMemoryVoiceComparisonPlanStore(),
          ),
          sessionIdGeneratorProvider.overrideWithValue(
            () => 'p4-12-fixture-session',
          ),
          ...extraOverrides,
        ],
        child: const VoiceTrainerApp(),
      ),
    );
    await tester.pumpAndSettle();
  }
}
