import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final root = Directory(arguments.isEmpty ? '.' : arguments.single).absolute;
  final failures = <String>[];

  void requireFile(String relative, [String? contains]) {
    final file = File(_join(root.path, relative));
    if (!file.existsSync()) {
      failures.add('missing required release file: $relative');
      return;
    }
    if (contains != null && !file.readAsStringSync().contains(contains)) {
      failures.add('$relative does not contain required marker: $contains');
    }
  }

  requireFile(
    'licenses/THIRD_PARTY_NOTICES.md',
    'Symphonia MPL source availability',
  );
  final notice = File(_join(root.path, 'licenses/THIRD_PARTY_NOTICES.md'));
  if (notice.existsSync()) {
    final contents = notice.readAsStringSync();
    for (final marker in <String>[
      'tract-onnx',
      'audioplayers_android',
      'file_selector_android',
      '5773a4c030a19d9bfaa090f49746ff35c75dfddfa700df7a5939d5e076a57039',
    ]) {
      if (!contents.contains(marker)) {
        failures.add('third-party notice is missing required marker: $marker');
      }
    }
  }
  requireFile('third_party/audioplayers_android/LICENSE', 'MIT License');
  requireFile('third_party/audioplayers_android/UPSTREAM.md', '5.3.0');
  requireFile(
    'third_party/file_selector_android/LICENSE',
    'Redistribution and use in source and binary forms',
  );
  requireFile('third_party/file_selector_android/UPSTREAM.md', '0.5.2+9');

  await _auditCargoGraph(root, 'rust/Cargo.toml', failures);
  await _auditCargoGraph(root, 'tool/song_separation/Cargo.toml', failures);
  _auditWorkflows(root, failures);

  if (failures.isNotEmpty) {
    for (final failure in failures) {
      stderr.writeln('P4-13 release audit: $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln(
    jsonEncode(<String, Object>{
      'schemaVersion': 1,
      'result': 'passed',
      'cargoGraphs': 2,
      'vendoredFlutterPackages': 2,
      'workflows': 4,
    }),
  );
}

Future<void> _auditCargoGraph(
  Directory root,
  String manifest,
  List<String> failures,
) async {
  final result = await Process.run(
    'cargo',
    <String>[
      'metadata',
      '--locked',
      '--format-version',
      '1',
      '--manifest-path',
      manifest,
    ],
    workingDirectory: root.path,
    runInShell: Platform.isWindows,
  );
  if (result.exitCode != 0) {
    failures.add('cargo metadata failed for $manifest');
    return;
  }
  final metadata = jsonDecode(result.stdout as String) as Map<String, Object?>;
  final packages = metadata['packages']! as List<Object?>;
  for (final value in packages) {
    final package = value! as Map<String, Object?>;
    if (package['source'] == null) {
      continue;
    }
    final name = package['name']! as String;
    final version = package['version']! as String;
    final license = package['license'] as String?;
    final licenseFile = package['license_file'] as String?;
    if ((license == null || license.trim().isEmpty) &&
        (licenseFile == null || licenseFile.trim().isEmpty)) {
      failures.add(
        '$manifest dependency $name $version has no license metadata',
      );
      continue;
    }
    final normalized = (license ?? '').toUpperCase();
    final hasBlockedTerm = RegExp(
      r'(^|[^A-Z])(?:GPL|AGPL|SSPL)(?:[^A-Z]|$)|COMMONS[ -]CLAUSE',
    ).hasMatch(normalized);
    final hasPermissiveChoice = RegExp(
      r'MIT|APACHE-2\.0|BSD|MPL-2\.0|ISC|ZLIB|UNICODE',
    ).hasMatch(normalized);
    if (hasBlockedTerm && !hasPermissiveChoice) {
      failures.add('$manifest dependency $name $version uses blocked $license');
    }
    if (name.startsWith('symphonia') && !normalized.contains('MPL-2.0')) {
      failures.add('$name $version must retain MPL-2.0 metadata');
    }
    if (name.startsWith('tract-') &&
        !(normalized.contains('MIT') && normalized.contains('APACHE-2.0'))) {
      failures.add('$name $version has unexpected tract license: $license');
    }
  }
}

void _auditWorkflows(Directory root, List<String> failures) {
  const workflowMarkers = <String, List<String>>{
    '.github/workflows/android_build.yml': <String>[
      'flutter build apk --release',
      'licenses/THIRD_PARTY_NOTICES.md',
    ],
    '.github/workflows/web_build.yml': <String>[
      '--no-web-resources-cdn --csp',
      'p4_11_prepare_web_release.dart',
      'p4_11_deployment_validator.mjs',
      'nightly-2026-08-02',
      'THIRD_PARTY_NOTICES.md',
    ],
    '.github/workflows/windows_build.yml': <String>[
      'p4_12_cross_platform_ui_contract_test.dart',
      'reference_comparison_windows_test.dart',
      'THIRD_PARTY_NOTICES.md',
    ],
    '.github/workflows/dart_rust_checks.yml': <String>[
      'tool/song_separation/Cargo.toml',
      'p4_13_release_audit.dart',
    ],
  };
  for (final entry in workflowMarkers.entries) {
    final file = File(_join(root.path, entry.key));
    if (!file.existsSync()) {
      failures.add('missing workflow: ${entry.key}');
      continue;
    }
    final contents = file.readAsStringSync();
    for (final marker in entry.value) {
      if (!contents.contains(marker)) {
        failures.add('${entry.key} is missing release gate: $marker');
      }
    }
    for (final match in RegExp(r'uses:\s+([^\s#]+)').allMatches(contents)) {
      final reference = match.group(1)!;
      final revision = reference.split('@').last;
      if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(revision)) {
        failures.add(
          '${entry.key} action is not pinned to a full SHA: $reference',
        );
      }
    }
    if (contents.contains('subosito/flutter-action@') &&
        !RegExp(r'cache:\s*false').hasMatch(contents)) {
      failures.add(
        '${entry.key} must disable flutter-action cache until its movable '
        'transitive actions/cache reference is eliminated',
      );
    }
  }
}

String _join(String root, String relative) =>
    '$root${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}';
