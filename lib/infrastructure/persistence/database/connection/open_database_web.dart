import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

final class DatabaseOpenResult {
  const DatabaseOpenResult({
    required this.executor,
    required this.chosenImplementation,
    required this.missingFeatures,
  });
  final QueryExecutor executor;
  final String chosenImplementation;
  final List<String> missingFeatures;
  String? get persistenceWarning =>
      chosenImplementation == 'unsafeIndexedDb' ||
          chosenImplementation == 'inMemory'
      ? '此浏览器无法提供可靠的本地持久化；练习记录可能在关闭页面后丢失。'
      : null;
}

Future<DatabaseOpenResult> openAppDatabase() async {
  final result = await WasmDatabase.open(
    databaseName: 'voice_trainer_v1',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );
  return DatabaseOpenResult(
    executor: result.resolvedExecutor,
    chosenImplementation: result.chosenImplementation.name,
    missingFeatures: result.missingFeatures.map((item) => item.name).toList(),
  );
}
