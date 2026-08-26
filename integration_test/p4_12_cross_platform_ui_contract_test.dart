import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voice_trainer/app/platform_capabilities.dart';
import 'package:voice_trainer/app/router/route_names.dart';
import 'package:voice_trainer/core/domain/audio/audio_capture.dart';
import 'package:voice_trainer/core/errors/failure.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';
import 'package:voice_trainer/infrastructure/audio/fake_audio_capture.dart';

import 'support/p4_12_ui_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'actual Flutter target renders the portrait page and typed-error contract',
    (tester) async {
      final capabilities = createDefaultPlatformCapabilities();
      if (capabilities.target == PlatformTarget.otherNative) return;
      final profile = P412UiProfile(
        name: 'integration-${capabilities.target.name}',
        capabilities: capabilities,
        size: const Size(393, 852),
        devicePixelRatio: capabilities.target == PlatformTarget.android ? 3 : 1,
      );
      final fixture = P412UiFixture(tester);
      for (final route in const <String>[
        RoutePaths.home,
        RoutePaths.livePractice,
        RoutePaths.result,
        RoutePaths.history,
        RoutePaths.settings,
        RoutePaths.songImport,
        RoutePaths.voiceComparison,
        RoutePaths.referenceComparison,
      ]) {
        await fixture.pump(
          profile: profile,
          route: route,
          textScaleFactor: 2,
          brightness: Brightness.dark,
        );
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(tester.takeException(), isNull, reason: route);
      }

      await fixture.pump(
        profile: profile,
        route: RoutePaths.livePractice,
        capture: FakeAudioCapture(
          permissionResult: const PermissionDenied(
            PermissionDeniedFailure(canRequestAgain: true),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('start-practice')));
      await tester.pumpAndSettle();
      expect(find.text('无法开始：未授予麦克风权限。'), findsOneWidget);
    },
  );
}
