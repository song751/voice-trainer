import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          platformCapabilitiesProvider.overrideWithValue(
            PlatformCapabilities.android,
          ),
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
