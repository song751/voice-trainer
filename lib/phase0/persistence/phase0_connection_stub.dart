import 'package:drift/drift.dart';

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

Future<Phase0ConnectionInfo> openPhase0Connection() =>
    throw UnsupportedError('Phase 0 Drift spike is not supported here.');
