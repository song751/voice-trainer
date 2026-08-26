import 'package:flutter_test/flutter_test.dart';

import '../../tool/p4_05_android_evidence.dart';

void main() {
  test('accepts emulator-only P3-family lifecycle evidence', () {
    expect(validateP405AndroidEvidence(_bundle()), isEmpty);
  });

  test('rejects another emulator endpoint and implicit root state', () {
    final bundle = _bundle();
    final environment = bundle['environment']! as Map<String, dynamic>;
    environment['endpoint'] = '127.0.0.1:7555';
    environment.remove('root_used');

    expect(
      validateP405AndroidEvidence(bundle),
      containsAll(<String>[
        'endpoint must identify the approved vertical emulator.',
        'root_used must be explicit.',
      ]),
    );
  });

  test('pending hardware scenarios require an uncovered reason', () {
    final bundle = _bundle();
    final scenarios = bundle['scenarios']! as List<dynamic>;
    final incomingCall = scenarios.cast<Map<String, dynamic>>().firstWhere(
      (scenario) => scenario['scenario_id'] == 'incoming_call',
    );
    incomingCall['uncovered_reasons'] = <String>[];

    expect(
      validateP405AndroidEvidence(bundle),
      contains('scenarios[5].uncovered_reasons is invalid.'),
    );
  });

  test('rejects private paths and audio payload fields', () {
    final bundle = _bundle();
    bundle['absolute_path'] = '/data/user/0/private';
    bundle['pcm'] = <int>[1, 2, 3];

    final issues = validateP405AndroidEvidence(bundle);
    expect(
      issues.where((issue) => issue.contains('prohibited private-data field')),
      hasLength(2),
    );
  });
}

Map<String, dynamic> _bundle() => <String, dynamic>{
  'schema_version': p4_05AndroidEvidenceSchemaVersion,
  'schema_family': 'P3',
  'commit': 'abcdef1',
  'captured_on': '2026-08-27',
  'build_mode': 'debug',
  'environment': <String, dynamic>{
    'evidence_type': 'emulator',
    'endpoint': '127.0.0.1:16384',
    'emulator': true,
    'real_device': false,
    'root_used': false,
  },
  'scenarios': p4_05AndroidScenarioIds.map((id) {
    final pending = const {
      'incoming_call',
      'bluetooth_route',
      'hardware_route',
    }.contains(id);
    return <String, dynamic>{
      'scenario_id': id,
      'evidence_kind': pending ? 'capture_only' : 'synthetic',
      'root_used': false,
      'typed_result': pending ? 'pending' : 'typed-result',
      'result': <String, dynamic>{
        'status': pending ? 'pending' : 'pass',
        'reason': pending ? 'Physical hardware is absent.' : 'Gate passed.',
      },
      'uncovered_reasons': pending
          ? <String>['Physical hardware is absent.']
          : <String>[],
    };
  }).toList(),
};
