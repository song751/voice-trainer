import 'package:flutter_test/flutter_test.dart';

import '../../tool/p4_08_android_evidence.dart';

void main() {
  test('accepts a release emulator bundle with pending real microphone', () {
    expect(validateP408AndroidEvidence(_bundle()), isEmpty);
  });

  test('rejects another emulator and any root dependency', () {
    final bundle = _bundle();
    final environment = bundle['environment']! as Map<String, dynamic>;
    environment['endpoint'] = '127.0.0.1:7555';
    environment['root_used'] = true;

    expect(
      validateP408AndroidEvidence(bundle),
      containsAll(<String>[
        'endpoint must identify the approved vertical emulator.',
        'P4-08 must not require root.',
      ]),
    );
  });

  test('rejects a shortened run, queue drops, and missing memory evidence', () {
    final bundle = _bundle();
    final metrics = bundle['stability_metrics']! as Map<String, dynamic>;
    metrics['active_duration_seconds'] = 599.9;
    metrics['analysis_queue_dropped_samples'] = 1024;
    metrics['memory_samples'] = <Object?>[];

    expect(
      validateP408AndroidEvidence(bundle),
      containsAll(<String>[
        'active_duration_seconds must be at least 600.',
        'stable run must not drop analysis or recording samples.',
        'at least two bounded RSS/PSS memory samples are required.',
      ]),
    );
  });

  test('real microphone must remain pending capture-only evidence', () {
    final bundle = _bundle();
    final scenarios = bundle['scenarios']! as List<dynamic>;
    final realMicrophone = scenarios.cast<Map<String, dynamic>>().firstWhere(
      (scenario) => scenario['scenario_id'] == 'real_microphone',
    );
    realMicrophone['result'] = <String, dynamic>{
      'status': 'pass',
      'reason': 'An invalid emulator-only claim.',
    };
    realMicrophone['evidence_kind'] = 'synthetic';

    expect(
      validateP408AndroidEvidence(bundle),
      contains('real_microphone must remain capture_only and pending.'),
    );
  });

  test('requires lifecycle and manual pause metrics', () {
    final bundle = _bundle();
    final metrics = bundle['stability_metrics']! as Map<String, dynamic>;
    metrics['background_observed'] = false;

    expect(
      validateP408AndroidEvidence(bundle),
      contains(
        'pause/resume and background/foreground metrics must be observed.',
      ),
    );
  });

  test('rejects private paths, device identifiers, and audio payloads', () {
    final bundle = _bundle();
    bundle['absolute_path'] = '/data/user/0/private';
    bundle['device_id'] = 'identifier';
    bundle['pcm'] = <int>[1, 2, 3];

    expect(
      validateP408AndroidEvidence(
        bundle,
      ).where((issue) => issue.contains('prohibited private-data field')),
      hasLength(3),
    );
  });
}

Map<String, dynamic> _bundle() => <String, dynamic>{
  'schema_version': p4_08AndroidEvidenceSchemaVersion,
  'commit': 'abcdef1',
  'captured_on': '2026-08-27',
  'build_mode': 'release',
  'environment': <String, dynamic>{
    'evidence_type': 'emulator',
    'endpoint': '127.0.0.1:16384',
    'emulator': true,
    'real_device': false,
    'real_microphone': false,
    'root_used': false,
    'api_level': 35,
    'abi': 'x86_64',
    'physical_size': '1080x1920',
    'density_dpi': 480,
  },
  'artifact': <String, dynamic>{
    'sha256':
        '0000000000000000000000000000000000000000000000000000000000000000',
    'byte_length': 1,
    'x86_64_rust_library': true,
  },
  'scenarios': p4_08AndroidScenarioIds.map((id) {
    final pending = id == 'real_microphone';
    return <String, dynamic>{
      'scenario_id': id,
      'evidence_kind': pending ? 'capture_only' : 'synthetic',
      'result': <String, dynamic>{
        'status': pending ? 'pending' : 'pass',
        'reason': pending
            ? 'The emulator cannot establish a real microphone result.'
            : 'The deterministic release gate passed.',
      },
      'uncovered_reasons': pending
          ? <String>['A physical Android microphone was not exercised.']
          : <String>[],
    };
  }).toList(),
  'stability_metrics': <String, dynamic>{
    'active_duration_seconds': 600,
    'wall_duration_seconds': 604,
    'generated_samples': 28800000,
    'analysis_queue_dropped_samples': 0,
    'recording_queue_dropped_samples': 0,
    'discontinuity_count': 2,
    'worker_state': 'primary',
    'worker_restart_count': 0,
    'pipeline_p95_ms': 8.2,
    'ui_build_p95_ms': 2.1,
    'ui_raster_p95_ms': 1.4,
    'manual_pause_resume': true,
    'background_observed': true,
    'foreground_observed': true,
    'memory_samples': <Map<String, dynamic>>[
      <String, dynamic>{
        'elapsed_seconds': 30,
        'rss_mib': 120.0,
        'pss_mib': 90.0,
      },
      <String, dynamic>{
        'elapsed_seconds': 600,
        'rss_mib': 126.0,
        'pss_mib': 95.0,
      },
    ],
  },
};
