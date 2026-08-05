import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_trainer/app/app.dart';
import 'package:voice_trainer/src/rust/api/simple.dart';
import 'package:voice_trainer/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('Can call rust function', (WidgetTester tester) async {
    final rustGreeting = greet(name: 'Tom');
    await tester.pumpWidget(const ProviderScope(child: VoiceTrainerApp()));
    expect(rustGreeting, 'Hello, Tom!');
    expect(find.text('练声助手'), findsOneWidget);
  });
}
