import 'dart:convert';
import 'dart:io';

import 'p3_07_evidence.dart';

void main(List<String> arguments) {
  if (arguments.isEmpty) _usage();
  switch (arguments.first) {
    case 'create':
      if (arguments.length != 5) _usage();
      final report = createBlankP3_07Evidence(
        commit: arguments[2],
        capturedOn: arguments[3],
        buildMode: arguments[4],
      );
      _write(arguments[1], report);
      stdout.writeln('Created blank P3-07 evidence checklist.');
    case 'merge':
      if (arguments.length != 4) _usage();
      final bundle = _readObject(arguments[1]);
      final scenario = _readObject(arguments[2]);
      final merged = mergeP3_07Scenario(bundle: bundle, scenario: scenario);
      final issues = validateP3_07Evidence(merged);
      if (issues.isNotEmpty) _fail(issues);
      _write(arguments[3], merged);
      stdout.writeln('Merged P3-07 scenario fragment.');
    case 'validate':
      if (arguments.length != 2) _usage();
      final issues = validateP3_07Evidence(_readObject(arguments[1]));
      if (issues.isNotEmpty) _fail(issues);
      stdout.writeln('P3-07 evidence bundle is valid.');
    default:
      _usage();
  }
}

Map<String, dynamic> _readObject(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('Input JSON must be an object.');
    exit(1);
  }
  return decoded;
}

void _write(String path, Map<String, dynamic> value) {
  File(
    path,
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(value)}\n');
}

Never _fail(List<String> issues) {
  for (final issue in issues) {
    stderr.writeln(issue);
  }
  exit(1);
}

Never _usage() {
  stderr.writeln('Usage:');
  stderr.writeln(
    '  dart run tool/p3_07_evidence_runner.dart create <output> <commit> <YYYY-MM-DD> <debug|release>',
  );
  stderr.writeln(
    '  dart run tool/p3_07_evidence_runner.dart merge <bundle> <scenario-fragment> <output>',
  );
  stderr.writeln(
    '  dart run tool/p3_07_evidence_runner.dart validate <bundle>',
  );
  exit(64);
}
