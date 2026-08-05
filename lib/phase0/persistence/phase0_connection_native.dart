import 'package:drift/drift.dart';
import 'package:drift/native.dart';

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

Future<Phase0ConnectionInfo> openPhase0Connection() async =>
    Phase0ConnectionInfo(
      executor: NativeDatabase.memory(),
      storageImplementation: 'native-sqlite-memory',
      missingFeatures: const [],
    );
