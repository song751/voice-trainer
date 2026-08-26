import 'dart:convert';
import 'dart:io';

const p4_08AndroidEvidenceSchemaVersion = 'P4_08_ANDROID_EMULATOR_BASELINE_V1';

const p4_08AndroidScenarioIds = <String>{
  'cold_start',
  'permission_denied',
  'permission_granted',
  'synthetic_session_start_pause_resume_stop',
  'result_history_recording_delete',
  'background_foreground',
  'process_force_stop_relaunch',
  'ten_minute_stability',
  'real_microphone',
};

List<String> validateP408AndroidEvidence(Object? value) {
  final issues = <String>[];
  if (value is! Map<String, dynamic>) {
    return const ['Evidence bundle must be a JSON object.'];
  }
  _forbidPrivateData(value, r'$', issues);
  _expect(
    value['schema_version'] == p4_08AndroidEvidenceSchemaVersion,
    'schema_version is invalid.',
    issues,
  );
  _expect(
    value['commit'] is String &&
        RegExp(r'^[0-9a-f]{7,64}$').hasMatch(value['commit'] as String),
    'commit must be a Git SHA.',
    issues,
  );
  _expect(
    value['build_mode'] == 'release',
    'build_mode must be release.',
    issues,
  );

  final environment = value['environment'];
  if (environment is! Map<String, dynamic>) {
    issues.add('environment must be an object.');
  } else {
    _expect(
      environment['evidence_type'] == 'emulator' &&
          environment['emulator'] == true &&
          environment['real_device'] == false &&
          environment['real_microphone'] == false,
      'environment must remain emulator/synthetic-only.',
      issues,
    );
    _expect(
      environment['endpoint'] == '127.0.0.1:16384',
      'endpoint must identify the approved vertical emulator.',
      issues,
    );
    _expect(environment['api_level'] == 35, 'api_level must be 35.', issues);
    _expect(environment['abi'] == 'x86_64', 'abi must be x86_64.', issues);
    _expect(
      environment['physical_size'] == '1080x1920' &&
          environment['density_dpi'] == 480,
      'the approved vertical emulator display profile is required.',
      issues,
    );
    _expect(
      environment['root_used'] == false,
      'P4-08 must not require root.',
      issues,
    );
  }

  final artifact = value['artifact'];
  if (artifact is! Map<String, dynamic>) {
    issues.add('artifact must be an object.');
  } else {
    _expect(
      artifact['sha256'] is String &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch(artifact['sha256'] as String),
      'artifact.sha256 must be a lowercase SHA-256.',
      issues,
    );
    _expect(
      artifact['byte_length'] is int && artifact['byte_length'] as int > 0,
      'artifact.byte_length must be positive.',
      issues,
    );
    _expect(
      artifact['x86_64_rust_library'] == true,
      'artifact must contain the x86_64 Rust library.',
      issues,
    );
  }

  final scenarios = value['scenarios'];
  if (scenarios is! List || scenarios.isEmpty) {
    issues.add('scenarios must be a non-empty array.');
  } else {
    final seen = <String>{};
    for (var index = 0; index < scenarios.length; index += 1) {
      final scenario = scenarios[index];
      if (scenario is! Map<String, dynamic>) {
        issues.add('scenarios[$index] must be an object.');
        continue;
      }
      final id = scenario['scenario_id'];
      _expect(
        id is String && p4_08AndroidScenarioIds.contains(id),
        'scenarios[$index].scenario_id is invalid.',
        issues,
      );
      if (id is String && !seen.add(id)) {
        issues.add('scenarios[$index].scenario_id is duplicated.');
      }
      _expect(
        const {
          'release_emulator',
          'synthetic',
          'capture_only',
        }.contains(scenario['evidence_kind']),
        'scenarios[$index].evidence_kind is invalid.',
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
            uncovered.every(
              (item) => item is String && item.trim().isNotEmpty,
            ) &&
            (!pending || uncovered.isNotEmpty),
        'scenarios[$index].uncovered_reasons is invalid.',
        issues,
      );
      if (id == 'real_microphone') {
        _expect(
          scenario['evidence_kind'] == 'capture_only' && pending,
          'real_microphone must remain capture_only and pending.',
          issues,
        );
      } else if (id is String && p4_08AndroidScenarioIds.contains(id)) {
        _expect(
          result is Map<String, dynamic> && result['status'] == 'pass',
          '$id must pass the deterministic release gate.',
          issues,
        );
      }
    }
    _expect(
      seen.containsAll(p4_08AndroidScenarioIds),
      'all P4-08 scenarios must be present.',
      issues,
    );
  }

  final stability = value['stability_metrics'];
  if (stability is! Map<String, dynamic>) {
    issues.add('stability_metrics must be an object.');
  } else {
    _expect(
      _finiteAtLeast(stability['active_duration_seconds'], 600),
      'active_duration_seconds must be at least 600.',
      issues,
    );
    _expect(
      stability['generated_samples'] == 28800000,
      'generated_samples must represent ten minutes at 48 kHz.',
      issues,
    );
    _expect(
      stability['analysis_queue_dropped_samples'] == 0 &&
          stability['recording_queue_dropped_samples'] == 0,
      'stable run must not drop analysis or recording samples.',
      issues,
    );
    _expect(
      stability['worker_state'] == 'primary' &&
          stability['worker_restart_count'] == 0,
      'stable run must retain the primary worker without restart.',
      issues,
    );
    _expect(
      stability['manual_pause_resume'] == true &&
          stability['background_observed'] == true &&
          stability['foreground_observed'] == true,
      'pause/resume and background/foreground metrics must be observed.',
      issues,
    );
    _expect(
      _finiteAtLeast(stability['pipeline_p95_ms'], 0) &&
          _finiteAtLeast(stability['ui_build_p95_ms'], 0) &&
          _finiteAtLeast(stability['ui_raster_p95_ms'], 0),
      'latency and UI frame P95 metrics must be finite and non-negative.',
      issues,
    );
    final memory = stability['memory_samples'];
    _expect(
      memory is List &&
          memory.length >= 2 &&
          memory.every(
            (sample) =>
                sample is Map<String, dynamic> &&
                _finiteAtLeast(sample['elapsed_seconds'], 0) &&
                _positiveFinite(sample['rss_mib']) &&
                _positiveFinite(sample['pss_mib']),
          ),
      'at least two bounded RSS/PSS memory samples are required.',
      issues,
    );
  }
  return issues;
}

void main(List<String> arguments) {
  if (arguments.length != 2 || arguments.first != 'validate') {
    stderr.writeln(
      'Usage: dart run tool/p4_08_android_evidence.dart validate <json>',
    );
    exitCode = 64;
    return;
  }
  final decoded = jsonDecode(File(arguments[1]).readAsStringSync());
  final issues = validateP408AndroidEvidence(decoded);
  if (issues.isNotEmpty) {
    for (final issue in issues) {
      stderr.writeln(issue);
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('P4_08_ANDROID_EVIDENCE_VALID');
}

bool _positiveFinite(Object? value) => _finiteAtLeast(value, 0.000001);

bool _finiteAtLeast(Object? value, num minimum) =>
    value is num && value.isFinite && value >= minimum;

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
    'model',
    'product',
    'serial',
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
