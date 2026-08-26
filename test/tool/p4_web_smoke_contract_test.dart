import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web smoke builds and CDP targets remain deterministic', () {
    final captureSmoke = File('tool/p4_09_web_smoke.ps1').readAsStringSync();
    expect(captureSmoke, contains('--no-web-resources-cdn'));

    for (final path in <String>[
      'tool/p4_09_edge_capture_gate.mjs',
      'tool/p4_10_edge_persistence_gate.mjs',
      'tool/p4_11_edge_lifecycle_gate.mjs',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains("item.url === 'about:blank'"), reason: path);
      expect(source, contains('item.url.startsWith('), reason: path);
      expect(
        source,
        isNot(contains("targets.find((item) => item.type === 'page');")),
        reason: path,
      );
    }
  });

  test('failed Web smoke runs clean up the verified listener process', () {
    for (final path in <String>[
      'tool/p4_09_web_smoke.ps1',
      'tool/p4_10_web_persistence_smoke.ps1',
      'tool/p4_11_web_lifecycle_smoke.ps1',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains(r'$serverListenerPid'), reason: path);
      expect(source, contains('Get-NetTCPConnection'), reason: path);
      expect(source, contains('Get-CimInstance Win32_Process'), reason: path);
      expect(source, contains('CommandLine -like'), reason: path);
    }
  });
}
