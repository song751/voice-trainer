import 'package:flutter/material.dart';
import 'package:voice_trainer/src/rust/frb_generated.dart';

import 'p4_02_bridge_probe.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var status = 'P4_02_RELEASE_BRIDGE_FAILED';
  try {
    await RustLib.init();
    final result = await runP402BridgeProbe();
    if (result.matchesExpectedContract) {
      status =
          'P4_02_RELEASE_BRIDGE_OK '
          'frames=${result.frameCount} samples=${result.sampleChecksum}';
    }
  } catch (_) {
    // The visible sentinel deliberately excludes exception text and paths.
  }

  runApp(_ReleaseProbeApp(status: status));
}

final class _ReleaseProbeApp extends StatelessWidget {
  const _ReleaseProbeApp({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: Center(child: Text(status))),
  );
}
