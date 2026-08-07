import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../tool/p3_07_evidence.dart';

void main() {
  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('tool/p3_07_fixtures/$name').readAsStringSync())
          as Map<String, dynamic>;

  test('known partial capture fixture is valid but remains pending', () {
    final report = fixture('partial_capture.json');

    expect(validateP3_07Evidence(report), isEmpty);
    expect(
      (report['scenarios'] as List).every(
        (scenario) =>
            (scenario as Map<String, dynamic>)['result']['status'] == 'pending',
      ),
      isTrue,
    );
  });

  test('damaged privacy fixture fails validation', () {
    expect(validateP3_07Evidence(fixture('invalid_privacy.json')), isNotEmpty);
  });

  test('rejects an unknown scenario and invalid percentiles', () {
    final report = fixture('partial_capture.json');
    final scenario =
        (report['scenarios'] as List).first as Map<String, dynamic>;
    scenario['scenario_id'] = 'unknown';
    scenario['pipeline_latency_ms'] = <String, Object>{'p50': 180, 'p95': 120};

    expect(validateP3_07Evidence(report), isNotEmpty);
  });

  test('blank checklist has all known scenarios pending', () {
    final report = createBlankP3_07Evidence(
      commit: 'e80e028',
      capturedOn: '2026-08-07',
      buildMode: 'release',
    );

    expect(validateP3_07Evidence(report), isEmpty);
    expect((report['scenarios'] as List), hasLength(p3_07ScenarioIds.length));
  });
}
