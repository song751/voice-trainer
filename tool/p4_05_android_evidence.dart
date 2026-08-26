import 'dart:convert';
import 'dart:io';

const p4_05AndroidEvidenceSchemaVersion = 'P4_05_ANDROID_EVIDENCE_V1';

const p4_05AndroidScenarioIds = <String>{
  'permission_allow_deny',
  'background_foreground',
  'process_force_stop_relaunch',
  'storage_read_only',
  'partial_recovery',
  'incoming_call',
  'bluetooth_route',
  'hardware_route',
};

List<String> validateP405AndroidEvidence(Object? value) {
  final issues = <String>[];
  if (value is! Map<String, dynamic>) {
    return const ['Evidence bundle must be a JSON object.'];
  }
  _forbidPrivateData(value, r'$', issues);
  _expect(
    value['schema_version'] == p4_05AndroidEvidenceSchemaVersion,
    'schema_version is invalid.',
    issues,
  );
  _expect(value['schema_family'] == 'P3', 'schema_family must be P3.', issues);
  _expect(
    value['commit'] is String &&
        RegExp(r'^[0-9a-f]{7,64}$').hasMatch(value['commit'] as String),
    'commit must be a Git SHA.',
    issues,
  );
  _expect(value['build_mode'] == 'debug', 'build_mode must be debug.', issues);

  final environment = value['environment'];
  if (environment is! Map<String, dynamic>) {
    issues.add('environment must be an object.');
  } else {
    _expect(
      environment['evidence_type'] == 'emulator' &&
          environment['emulator'] == true &&
          environment['real_device'] == false,
      'environment must remain emulator-only.',
      issues,
    );
    _expect(
      environment['endpoint'] == '127.0.0.1:16384',
      'endpoint must identify the approved vertical emulator.',
      issues,
    );
    _expect(
      environment['root_used'] is bool,
      'root_used must be explicit.',
      issues,
    );
  }

  final scenarios = value['scenarios'];
  if (scenarios is! List || scenarios.isEmpty) {
    issues.add('scenarios must be a non-empty array.');
    return issues;
  }
  final seen = <String>{};
  for (var index = 0; index < scenarios.length; index += 1) {
    final scenario = scenarios[index];
    if (scenario is! Map<String, dynamic>) {
      issues.add('scenarios[$index] must be an object.');
      continue;
    }
    final id = scenario['scenario_id'];
    _expect(
      id is String && p4_05AndroidScenarioIds.contains(id),
      'scenarios[$index].scenario_id is invalid.',
      issues,
    );
    if (id is String && !seen.add(id)) {
      issues.add('scenarios[$index].scenario_id is duplicated.');
    }
    _expect(
      scenario['evidence_kind'] == 'capture_only' ||
          scenario['evidence_kind'] == 'synthetic',
      'scenarios[$index].evidence_kind is invalid.',
      issues,
    );
    _expect(
      scenario['root_used'] is bool,
      'scenarios[$index].root_used must be explicit.',
      issues,
    );
    final result = scenario['result'];
    final pending =
        result is Map<String, dynamic> && result['status'] == 'pending';
    _expect(
      result is Map<String, dynamic> &&
          const {'pass', 'fail', 'pending'}.contains(result['status']) &&
          result['reason'] is String &&
          (result['reason'] as String).trim().isNotEmpty,
      'scenarios[$index].result is invalid.',
      issues,
    );
    final uncovered = scenario['uncovered_reasons'];
    _expect(
      uncovered is List &&
          uncovered.every((item) => item is String && item.trim().isNotEmpty) &&
          (!pending || uncovered.isNotEmpty),
      'scenarios[$index].uncovered_reasons is invalid.',
      issues,
    );
  }
  _expect(
    seen.containsAll(p4_05AndroidScenarioIds),
    'all P4-05 scenarios must be present.',
    issues,
  );
  return issues;
}

void main(List<String> arguments) {
  if (arguments.length != 2 || arguments.first != 'validate') {
    stderr.writeln(
      'Usage: dart run tool/p4_05_android_evidence.dart validate <json>',
    );
    exitCode = 64;
    return;
  }
  final decoded = jsonDecode(File(arguments[1]).readAsStringSync());
  final issues = validateP405AndroidEvidence(decoded);
  if (issues.isNotEmpty) {
    for (final issue in issues) {
      stderr.writeln(issue);
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('P4_05_ANDROID_EVIDENCE_VALID');
}

void _expect(bool condition, String message, List<String> issues) {
  if (!condition) issues.add(message);
}

void _forbidPrivateData(Object? value, String path, List<String> issues) {
  const prohibited = <String>{
    'device_id',
    'recording_path',
    'absolute_path',
    'pcm',
    'audio_bytes',
    'username',
  };
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (prohibited.contains(key.toLowerCase())) {
        issues.add('$path contains a prohibited private-data field.');
      }
      _forbidPrivateData(entry.value, '$path.$key', issues);
    }
  } else if (value is List) {
    for (var index = 0; index < value.length; index += 1) {
      _forbidPrivateData(value[index], '$path[$index]', issues);
    }
  } else if (value is String &&
      RegExp(
        r'(^[A-Za-z]:[\\/]|^/data/|^/storage/|^/Users/|^/home/)',
      ).hasMatch(value)) {
    issues.add('$path contains an absolute path.');
  }
}
