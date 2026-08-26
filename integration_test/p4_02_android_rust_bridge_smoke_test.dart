import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voice_trainer/src/rust/frb_generated.dart';

import '../tool/p4_02_bridge_probe.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(RustLib.init);

  testWidgets('native Rust bridge returns a bounded production DTO', (
    tester,
  ) async {
    // Device integration tests still need a mounted widget tree so Flutter's
    // focus lifecycle is torn down in the same order as the application.
    await tester.pumpWidget(const SizedBox.shrink());

    final result = await runP402BridgeProbe();

    expect(result.greeting, 'Hello, Android!');
    expect(result.frameCount, 94);
    expect(result.sampleChecksum, 2098080);
    expect(result.rmsChecksum, closeTo(-868.26486, 0.001));
    expect(result.pitchChecksum, closeTo(20681.109375, 0.001));
    expect(result.hasBoundedDtos, isTrue);
    expect(result.hasConsistentVoicing, isTrue);
    expect(result.matchesExpectedContract, isTrue);
  });
}
