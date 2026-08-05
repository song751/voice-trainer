import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

final class DatabaseOpenResult {
  const DatabaseOpenResult({
    required this.executor,
    required this.chosenImplementation,
    required this.missingFeatures,
  });
  final QueryExecutor executor;
  final String chosenImplementation;
  final List<String> missingFeatures;
  String? get persistenceWarning => null;
}

Future<DatabaseOpenResult> openAppDatabase() async {
  final directory = await getApplicationSupportDirectory();
  final file = File(
    '${directory.path}${Platform.pathSeparator}voice_trainer.sqlite',
  );
  return DatabaseOpenResult(
    executor: NativeDatabase.createInBackground(file),
    chosenImplementation: 'native-file-background-isolate',
    missingFeatures: const [],
  );
}
