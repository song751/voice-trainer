import 'dart:convert';

const p3_07EvidenceSchemaVersion = 'P3_07_EVIDENCE_V1';

const p3_07ScenarioIds = <String>{
  'windows_realtek_capture',
  'windows_usb_capture',
  'windows_permission_initial_denied',
  'windows_permission_revoked',
  'windows_no_input_devices',
  'windows_usb_unplug_replug',
  'windows_effective_format_change',
  'windows_disk_write_failure',
  'windows_crash_recovery',
  'windows_production_performance_realtek',
  'windows_production_performance_usb',
};

const p3_07EvidenceKinds = <String>{'real_device', 'capture_only', 'synthetic'};

const p3_07Results = <String>{'pass', 'fail', 'pending'};

/// Validates the versioned, privacy-safe P3-07 evidence bundle.
///
/// The returned messages are user-facing and deliberately avoid echoing values
/// from a report, because an invalid report might itself contain private data.
List<String> validateP3_07Evidence(Object? value) {
  final issues = <String>[];
  if (value is! Map<String, dynamic>) {
    return const ['Evidence bundle must be a JSON object.'];
  }

  _forbidSensitiveData(value, r'$', issues);
  _expect(
    value['schema_version'] == p3_07EvidenceSchemaVersion,
    'schema_version must be $p3_07EvidenceSchemaVersion.',
    issues,
  );
  _expect(
    _isCommit(value['commit']),
    'commit must be a 7–64 character Git SHA.',
    issues,
  );
  _expect(
    _isIsoDate(value['captured_on']),
    'captured_on must be an ISO date.',
    issues,
  );
  _expect(
    value['build_mode'] == 'debug' || value['build_mode'] == 'release',
    'build_mode must be debug or release.',
    issues,
  );

  final scenarios = value['scenarios'];
  if (scenarios is! List || scenarios.isEmpty) {
    issues.add('scenarios must be a non-empty JSON array.');
    return issues;
  }

  final ids = <String>{};
  for (var index = 0; index < scenarios.length; index += 1) {
    final scenario = scenarios[index];
    if (scenario is! Map<String, dynamic>) {
      issues.add('scenarios[$index] must be an object.');
      continue;
    }
    _validateScenario(scenario, index, ids, issues);
  }
  return issues;
}

Map<String, dynamic> createBlankP3_07Evidence({
  required String commit,
  required String capturedOn,
  required String buildMode,
}) {
  return <String, dynamic>{
    'schema_version': p3_07EvidenceSchemaVersion,
    'commit': commit,
    'captured_on': capturedOn,
    'build_mode': buildMode,
    'scenarios': p3_07ScenarioIds
        .map(
          (id) => <String, dynamic>{
            'scenario_id': id,
            'evidence_kind': 'real_device',
            'device_category': 'pending',
            'requested_format': _blankFormat(),
            'effective_format': _blankFormat(),
            'processing': _blankProcessing(),
            'duration_seconds': null,
            'sample_count': null,
            'dropped_samples': null,
            'discontinuity_count': null,
            'pipeline_latency_ms': _blankQuantiles(),
            'ui_frame_ms': _blankQuantiles(),
            'memory_samples': <Object?>[],
            'result': <String, String>{
              'status': 'pending',
              'reason': 'Not yet measured on a real device.',
            },
            'uncovered_reasons': <String>[
              'Real-device evidence has not been collected.',
            ],
          },
        )
        .toList(growable: false),
  };
}

Map<String, dynamic> mergeP3_07Scenario({
  required Map<String, dynamic> bundle,
  required Map<String, dynamic> scenario,
}) {
  final copied = jsonDecode(jsonEncode(bundle)) as Map<String, dynamic>;
  final scenarios = copied['scenarios']! as List<dynamic>;
  final scenarioId = scenario['scenario_id'];
  if (scenarioId is! String || !p3_07ScenarioIds.contains(scenarioId)) {
    throw ArgumentError('Scenario fragment has an unknown scenario_id.');
  }
  final index = scenarios.indexWhere(
    (item) => item is Map && item['scenario_id'] == scenarioId,
  );
  if (index < 0) {
    scenarios.add(scenario);
  } else {
    scenarios[index] = scenario;
  }
  return copied;
}

Map<String, dynamic> _blankFormat() => <String, Object?>{
  'sample_rate_hz': null,
  'channels': null,
  'encoding': null,
};

Map<String, dynamic> _blankProcessing() => <String, Object?>{
  'agc': null,
  'echo_cancellation': null,
  'noise_suppression': null,
};

Map<String, dynamic> _blankQuantiles() => <String, Object?>{
  'p50': null,
  'p95': null,
};

void _validateScenario(
  Map<String, dynamic> scenario,
  int index,
  Set<String> ids,
  List<String> issues,
) {
  final prefix = 'scenarios[$index]';
  final id = scenario['scenario_id'];
  _expect(
    id is String && p3_07ScenarioIds.contains(id),
    '$prefix.scenario_id is unknown.',
    issues,
  );
  if (id is String && !ids.add(id)) {
    issues.add('$prefix.scenario_id is duplicated.');
  }
  _expect(
    scenario['evidence_kind'] is String &&
        p3_07EvidenceKinds.contains(scenario['evidence_kind']),
    '$prefix.evidence_kind is invalid.',
    issues,
  );
  _expect(
    scenario['device_category'] is String &&
        const {
          'built_in',
          'usb',
          'none',
          'pending',
        }.contains(scenario['device_category']),
    '$prefix.device_category is invalid.',
    issues,
  );
  _validateFormat(
    scenario['requested_format'],
    '$prefix.requested_format',
    issues,
  );
  _validateFormat(
    scenario['effective_format'],
    '$prefix.effective_format',
    issues,
  );
  _validateProcessing(scenario['processing'], '$prefix.processing', issues);
  _nullableNonNegative(
    scenario['duration_seconds'],
    '$prefix.duration_seconds',
    issues,
  );
  _nullableNonNegativeInt(
    scenario['sample_count'],
    '$prefix.sample_count',
    issues,
  );
  _nullableNonNegativeInt(
    scenario['dropped_samples'],
    '$prefix.dropped_samples',
    issues,
  );
  _nullableNonNegativeInt(
    scenario['discontinuity_count'],
    '$prefix.discontinuity_count',
    issues,
  );
  _validateQuantiles(
    scenario['pipeline_latency_ms'],
    '$prefix.pipeline_latency_ms',
    issues,
  );
  _validateQuantiles(scenario['ui_frame_ms'], '$prefix.ui_frame_ms', issues);
  _validateMemory(scenario['memory_samples'], '$prefix.memory_samples', issues);

  final result = scenario['result'];
  if (result is! Map<String, dynamic> ||
      result['status'] is! String ||
      !p3_07Results.contains(result['status']) ||
      result['reason'] is! String ||
      (result['reason'] as String).trim().isEmpty) {
    issues.add('$prefix.result must have a status and a non-empty reason.');
  }
  final uncovered = scenario['uncovered_reasons'];
  if (uncovered is! List ||
      uncovered.any((item) => item is! String || item.trim().isEmpty)) {
    issues.add(
      '$prefix.uncovered_reasons must be an array of non-empty strings.',
    );
  }
  if (result is Map<String, dynamic> &&
      result['status'] == 'pending' &&
      uncovered is List &&
      uncovered.isEmpty) {
    issues.add('$prefix pending evidence must name an uncovered reason.');
  }
}

void _validateFormat(Object? value, String path, List<String> issues) {
  if (value is! Map<String, dynamic>) {
    issues.add('$path must be an object.');
    return;
  }
  _nullablePositiveInt(value['sample_rate_hz'], '$path.sample_rate_hz', issues);
  _nullablePositiveInt(value['channels'], '$path.channels', issues);
  final encoding = value['encoding'];
  _expect(
    encoding == null || encoding == 'pcm16le',
    '$path.encoding must be pcm16le or null.',
    issues,
  );
}

void _validateProcessing(Object? value, String path, List<String> issues) {
  if (value is! Map<String, dynamic>) {
    issues.add('$path must be an object.');
    return;
  }
  for (final field in const ['agc', 'echo_cancellation', 'noise_suppression']) {
    _expect(
      value[field] == null || value[field] is bool,
      '$path.$field must be boolean or null.',
      issues,
    );
  }
}

void _validateQuantiles(Object? value, String path, List<String> issues) {
  if (value is! Map<String, dynamic>) {
    issues.add('$path must be an object.');
    return;
  }
  final p50 = value['p50'];
  final p95 = value['p95'];
  _nullableNonNegative(p50, '$path.p50', issues);
  _nullableNonNegative(p95, '$path.p95', issues);
  if (p50 is num && p95 is num && p95 < p50) {
    issues.add('$path.p95 must be greater than or equal to p50.');
  }
}

void _validateMemory(Object? value, String path, List<String> issues) {
  if (value is! List) {
    issues.add('$path must be an array.');
    return;
  }
  for (var index = 0; index < value.length; index += 1) {
    final sample = value[index];
    if (sample is! Map<String, dynamic>) {
      issues.add('$path[$index] must be an object.');
      continue;
    }
    _nullableNonNegative(
      sample['elapsed_seconds'],
      '$path[$index].elapsed_seconds',
      issues,
    );
    _nullableNonNegative(
      sample['working_set_mib'],
      '$path[$index].working_set_mib',
      issues,
    );
    _nullableNonNegative(
      sample['private_mib'],
      '$path[$index].private_mib',
      issues,
    );
  }
}

void _nullablePositiveInt(Object? value, String path, List<String> issues) {
  _expect(
    value == null || (value is int && value > 0),
    '$path must be a positive integer or null.',
    issues,
  );
}

void _nullableNonNegativeInt(Object? value, String path, List<String> issues) {
  _expect(
    value == null || (value is int && value >= 0),
    '$path must be a non-negative integer or null.',
    issues,
  );
}

void _nullableNonNegative(Object? value, String path, List<String> issues) {
  _expect(
    value == null || (value is num && value >= 0),
    '$path must be non-negative or null.',
    issues,
  );
}

void _forbidSensitiveData(Object? value, String path, List<String> issues) {
  const forbiddenKeys = <String>{
    'device_id',
    'deviceid',
    'device_identifier',
    'recording_path',
    'absolute_path',
    'pcm',
    'audio_bytes',
    'user_note',
    'username',
  };
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is String && forbiddenKeys.contains(key.toLowerCase())) {
        issues.add('$path contains a prohibited private-data field.');
      }
      _forbidSensitiveData(entry.value, '$path.$key', issues);
    }
  } else if (value is List) {
    for (var index = 0; index < value.length; index += 1) {
      _forbidSensitiveData(value[index], '$path[$index]', issues);
    }
  } else if (value is String &&
      RegExp(r'(^[A-Za-z]:[\\/]|^/Users/|^/home/|^\\\\)').hasMatch(value)) {
    issues.add('$path contains an absolute path.');
  }
}

bool _isCommit(Object? value) =>
    value is String && RegExp(r'^[0-9a-f]{7,64}$').hasMatch(value);

bool _isIsoDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return false;
  }
  return DateTime.tryParse(value) != null;
}

void _expect(bool condition, String message, List<String> issues) {
  if (!condition) issues.add(message);
}
