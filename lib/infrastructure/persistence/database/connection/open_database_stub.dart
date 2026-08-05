import 'package:drift/drift.dart';

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

Future<DatabaseOpenResult> openAppDatabase() =>
    throw UnsupportedError('No database backend');
