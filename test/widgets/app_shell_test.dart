import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_trainer/app/app.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/app/router/app_router.dart';
import 'package:voice_trainer/app/router/route_names.dart';
import 'package:voice_trainer/core/domain/audio/audio_capture.dart';
import 'package:voice_trainer/core/errors/failure.dart';
import 'package:voice_trainer/infrastructure/audio/fake_audio_capture.dart';
import 'package:voice_trainer/infrastructure/dsp/fake_analysis_engine.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_recording_store.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_session_repository.dart';

void main() {
  test('composition root accepts replacements for every external adapter', () {
    final capture = FakeAudioCapture();
    final analysis = FakeAnalysisEngine();
    final store = InMemoryRecordingStore();
    final sink = InMemoryRecordingSink(store);
    final repository = InMemorySessionRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        audioCaptureProvider.overrideWithValue(capture),
        analysisEngineProvider.overrideWithValue(analysis),
        recordingStoreProvider.overrideWithValue(store),
        recordingSinkProvider.overrideWithValue(sink),
        sessionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(audioCaptureProvider), same(capture));
    expect(container.read(analysisEngineProvider), same(analysis));
    expect(container.read(recordingSinkProvider), same(sink));
    expect(container.read(sessionRepositoryProvider), same(repository));
  });

  Future<void> pumpPracticeApp(
    WidgetTester tester, {
    List<Override> overrides = const <Override>[],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appInitialLocationProvider.overrideWithValue(RoutePaths.livePractice),
          ...overrides,
        ],
        child: const VoiceTrainerApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a permission error from an overridden capture adapter', (
    tester,
  ) async {
    await pumpPracticeApp(
      tester,
      overrides: <Override>[
        audioCaptureProvider.overrideWithValue(
          FakeAudioCapture(
            permissionResult: const PermissionDenied(
              PermissionDeniedFailure(canRequestAgain: true),
            ),
          ),
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('start-practice')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('practice-error')), findsOneWidget);
    expect(find.text('无法开始：未授予麦克风权限。'), findsOneWidget);
  });

  testWidgets('shows a capture error from an overridden capture adapter', (
    tester,
  ) async {
    await pumpPracticeApp(
      tester,
      overrides: <Override>[
        audioCaptureProvider.overrideWithValue(
          FakeAudioCapture(
            startFailure: const CaptureFailure(
              CaptureFailureReason.deviceUnavailable,
            ),
          ),
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('start-practice')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('practice-error')), findsOneWidget);
    expect(find.text('无法开始：音频采集发生错误。'), findsOneWidget);
  });

  testWidgets('shows the no-data result placeholder', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appInitialLocationProvider.overrideWithValue(RoutePaths.result),
        ],
        child: const VoiceTrainerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('result-no-data')), findsOneWidget);
  });

  testWidgets('shell navigation reaches the minimal placeholder pages', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: VoiceTrainerApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();

    expect(find.text('暂无历史练习记录。'), findsOneWidget);
  });
}
