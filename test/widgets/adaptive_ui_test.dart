import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/app/app.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/app/router/app_router.dart';
import 'package:voice_trainer/app/router/route_names.dart';
import 'package:voice_trainer/app/theme/app_theme.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_session_repository.dart';

void main() {
  Future<void> pumpAt(
    WidgetTester tester, {
    required Size logicalSize,
    double devicePixelRatio = 1,
    double textScaleFactor = 1,
    String initialLocation = RoutePaths.home,
    PlatformCapabilities capabilities = PlatformCapabilities.android,
  }) async {
    tester.view.devicePixelRatio = devicePixelRatio;
    tester.view.physicalSize = logicalSize * devicePixelRatio;
    tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appInitialLocationProvider.overrideWithValue(initialLocation),
          platformCapabilitiesProvider.overrideWithValue(capabilities),
          sessionRepositoryProvider.overrideWithValue(
            InMemorySessionRepository(),
          ),
        ],
        child: const VoiceTrainerApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('compact view uses bottom navigation without overflow', (
    tester,
  ) async {
    await pumpAt(tester, logicalSize: const Size(360, 640));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('开始练习'), findsOneWidget);
    expect(find.textContaining('模拟练习'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide view uses navigation rail', (tester) async {
    await pumpAt(tester, logicalSize: const Size(1280, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide navigation rail can reach settings by keyboard', (
    tester,
  ) async {
    await pumpAt(tester, logicalSize: const Size(1280, 800));

    final settingsLabel = find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text('设置'),
    );
    Focus.of(tester.element(settingsLabel)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('设置与能力'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone density and 200 percent text remain scrollable', (
    tester,
  ) async {
    await pumpAt(
      tester,
      logicalSize: const Size(360, 640),
      devicePixelRatio: 3,
      textScaleFactor: 2,
      initialLocation: RoutePaths.livePractice,
    );

    expect(find.byKey(const Key('live-page-scroll')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Web fallback uses an explicit test-practice action', (
    tester,
  ) async {
    await pumpAt(
      tester,
      logicalSize: const Size(393, 852),
      capabilities: PlatformCapabilities.web,
    );

    expect(find.text('开始测试练习'), findsOneWidget);
    expect(find.text('开始练习'), findsNothing);
    expect(find.textContaining('真实麦克风链路尚未通过'), findsOneWidget);
  });

  testWidgets('all five pages remain scrollable at 200 percent text', (
    tester,
  ) async {
    for (final route in <String>[
      RoutePaths.home,
      RoutePaths.livePractice,
      RoutePaths.result,
      RoutePaths.history,
      RoutePaths.settings,
    ]) {
      await pumpAt(
        tester,
        logicalSize: const Size(393, 852),
        textScaleFactor: 2,
        initialLocation: route,
        capabilities: PlatformCapabilities.web,
      );
      expect(tester.takeException(), isNull, reason: 'route $route');
    }
  });

  test('theme exposes distinct light, dark, and high contrast schemes', () {
    expect(AppTheme.light.colorScheme.brightness, Brightness.light);
    expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
    expect(
      AppTheme.highContrastLight.colorScheme,
      isNot(AppTheme.light.colorScheme),
    );
    expect(
      AppTheme.highContrastDark.colorScheme,
      isNot(AppTheme.dark.colorScheme),
    );
  });
}
