import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

class Phase0ConnectionInfo {
  const Phase0ConnectionInfo({
    required this.executor,
    required this.storageImplementation,
    required this.missingFeatures,
  });

  final QueryExecutor executor;
  final String storageImplementation;
  final List<String> missingFeatures;
}

Future<Phase0ConnectionInfo> openPhase0Connection() async {
  final result = await WasmDatabase.open(
    databaseName: 'voice_trainer_phase0_gate0e',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );
  return Phase0ConnectionInfo(
    executor: result.resolvedExecutor,
    storageImplementation: result.chosenImplementation.name,
    missingFeatures: result.missingFeatures
        .map((feature) => feature.name)
        .toList(),
  );
}
