import 'dart:convert';
import 'dart:io';

const _defaultEndpoint = '127.0.0.1:7555';

Future<void> main(List<String> arguments) async {
  try {
    final options = _parseOptions(arguments);
    final endpoint = options['--endpoint'] ?? _defaultEndpoint;
    parseAdbEndpoint(endpoint);
    final adbPath = resolveSdkAdbPath(explicitPath: options['--adb-path']);
    final report = await collectAndroidPreflight(
      adbPath: adbPath,
      endpoint: endpoint,
    );
    stdout.writeln(report.toJsonString());
  } on AndroidPreflightException catch (error) {
    stderr.writeln('P4-00 Android preflight failed: ${error.message}');
    exitCode = 1;
  } on ArgumentError catch (error) {
    stderr.writeln('P4-00 Android preflight failed: ${error.message}');
    _usage();
    exitCode = 64;
  } on ProcessException {
    stderr.writeln(
      'P4-00 Android preflight failed: a required SDK command could not start. '
      'Check Android SDK Platform-Tools and Flutter installation paths.',
    );
    exitCode = 1;
  }
}

/// Resolves the SDK-owned ADB executable without depending on a shell PATH
/// entry or a vendor-specific emulator installation.
String resolveSdkAdbPath({
  String? explicitPath,
  Map<String, String>? environment,
  bool Function(String path)? fileExists,
}) {
  final exists = fileExists ?? FileSystemEntity.isFileSync;
  if (explicitPath != null && explicitPath.trim().isNotEmpty) {
    final explicit = explicitPath.trim();
    if (!exists(explicit)) {
      throw AndroidPreflightException(
        'The explicit SDK adb path does not exist: $explicit. '
        'Install Android SDK Platform-Tools or pass --adb-path <...\\adb.exe>.',
      );
    }
    return explicit;
  }

  final env = environment ?? Platform.environment;
  final candidates = <String>[
    for (final root in [
      env['ANDROID_SDK_ROOT'],
      env['ANDROID_HOME'],
      if (env['LOCALAPPDATA'] != null) '${env['LOCALAPPDATA']}\\Android\\Sdk',
    ])
      if (root != null && root.trim().isNotEmpty)
        '${root.replaceAll('/', '\\').replaceAll(RegExp(r'\\+$'), '')}\\platform-tools\\adb.exe',
  ];

  for (final candidate in candidates) {
    if (exists(candidate)) return candidate;
  }
  throw AndroidPreflightException(
    'Android SDK Platform-Tools adb.exe was not found. Set ANDROID_SDK_ROOT '
    'or pass --adb-path <SDK\\platform-tools\\adb.exe>; do not use a vendor ADB.',
  );
}

/// Finds Flutter without relying on the child Dart process inheriting the
/// PowerShell command resolution used by an interactive terminal.
String resolveFlutterExecutable({
  String? resolvedDartExecutable,
  Map<String, String>? environment,
  bool Function(String path)? fileExists,
}) {
  final exists = fileExists ?? FileSystemEntity.isFileSync;
  final env = environment ?? Platform.environment;
  final dartExecutable = resolvedDartExecutable ?? Platform.resolvedExecutable;
  final candidates = <String>[
    if (env['FLUTTER_ROOT'] case final flutterRoot?)
      '${flutterRoot.replaceAll('/', '\\').replaceAll(RegExp(r'\\+$'), '')}\\bin\\flutter.bat',
    '${File(dartExecutable).parent.parent.parent.parent.path}\\flutter.bat',
  ];
  for (final candidate in candidates) {
    if (exists(candidate)) return candidate;
  }
  throw AndroidPreflightException(
    'Flutter executable was not found. Set FLUTTER_ROOT or run the preflight '
    'from a Flutter SDK installation.',
  );
}

/// Validates the endpoint before it is passed to ADB, making the connection
/// target visible in the resulting report.
(String, int) parseAdbEndpoint(String value) {
  final match = RegExp(r'^([A-Za-z0-9.-]+):(\d{1,5})$').firstMatch(value);
  if (match == null) {
    throw ArgumentError('--endpoint must be an explicit host:port value.');
  }
  final port = int.parse(match.group(2)!);
  if (port == 0 || port > 65535) {
    throw ArgumentError('--endpoint port must be between 1 and 65535.');
  }
  return (match.group(1)!, port);
}

Future<AndroidPreflightReport> collectAndroidPreflight({
  required String adbPath,
  required String endpoint,
}) async {
  await _runAdb(adbPath, ['connect', endpoint], 'connect to $endpoint');

  final apiLevel = int.tryParse(
    await _adbShell(adbPath, endpoint, ['getprop', 'ro.build.version.sdk']),
  );
  if (apiLevel == null) {
    throw AndroidPreflightException(
      'The emulator did not return an Android API level.',
    );
  }
  final abi = await _adbShell(adbPath, endpoint, [
    'getprop',
    'ro.product.cpu.abi',
  ]);
  if (abi.isEmpty) {
    throw AndroidPreflightException('The emulator did not return a CPU ABI.');
  }
  final resolution = _physicalValue(
    await _adbShell(adbPath, endpoint, ['wm', 'size']),
    RegExp(r'(\d+x\d+)'),
    'display resolution',
  );
  final density = int.tryParse(
    _physicalValue(
      await _adbShell(adbPath, endpoint, ['wm', 'density']),
      RegExp(r'(\d+)'),
      'display density',
    ),
  );
  if (density == null) {
    throw AndroidPreflightException(
      'The emulator returned an invalid display density.',
    );
  }
  final features = await _adbShell(adbPath, endpoint, [
    'pm',
    'list',
    'features',
  ]);
  final shellIdentity = await _adbShell(adbPath, endpoint, ['id']);
  final flutterDevices = await _runFlutterDevices();
  final flutterDeviceId = flutterDeviceIdFromMachineOutput(
    flutterDevices,
    endpoint,
  );
  if (flutterDeviceId == null) {
    throw AndroidPreflightException(
      'Flutter did not detect $endpoint. Run "flutter devices --device-timeout 10" '
      'after confirming the SDK ADB connection.',
    );
  }

  return AndroidPreflightReport(
    endpoint: endpoint,
    flutterDeviceId: flutterDeviceId,
    apiLevel: apiLevel,
    abi: abi,
    resolution: resolution,
    densityDpi: density,
    microphoneFeature: features.contains('android.hardware.microphone'),
    lowLatencyAudioFeature: features.contains(
      'android.hardware.audio.low_latency',
    ),
    rootShellObserved: RegExp(r'uid=0(?:\b|\()').hasMatch(shellIdentity),
  );
}

String? flutterDeviceIdFromMachineOutput(String output, String endpoint) {
  final jsonStart = output.indexOf('[');
  if (jsonStart < 0) return null;
  try {
    final decoded = jsonDecode(output.substring(jsonStart));
    if (decoded is! List) return null;
    for (final device in decoded.whereType<Map>()) {
      final id = device['id'];
      if (id is String && id == endpoint) return id;
    }
  } on FormatException {
    return null;
  }
  return null;
}

class AndroidPreflightReport {
  const AndroidPreflightReport({
    required this.endpoint,
    required this.flutterDeviceId,
    required this.apiLevel,
    required this.abi,
    required this.resolution,
    required this.densityDpi,
    required this.microphoneFeature,
    required this.lowLatencyAudioFeature,
    required this.rootShellObserved,
  });

  final String endpoint;
  final String flutterDeviceId;
  final int apiLevel;
  final String abi;
  final String resolution;
  final int densityDpi;
  final bool microphoneFeature;
  final bool lowLatencyAudioFeature;
  final bool rootShellObserved;

  String toJsonString() => jsonEncode({
    'schemaVersion': 1,
    'evidenceType': 'emulator',
    'emulator': true,
    'realDevice': false,
    'adb': {
      'endpoint': endpoint,
      'pathKind': 'androidSdkPlatformTools',
      'sdkAdbFound': true,
    },
    'flutterDeviceId': flutterDeviceId,
    'android': {
      'apiLevel': apiLevel,
      'abi': abi,
      'resolution': resolution,
      'densityDpi': densityDpi,
    },
    'audioFeatures': {
      'microphone': microphoneFeature,
      'lowLatency': lowLatencyAudioFeature,
    },
    'rootShellObserved': rootShellObserved,
    'privacyAndAuthenticityBoundary':
        'This report intentionally omits model/product/serial properties. '
        'It is emulator-only evidence and never satisfies a real-device or '
        'real-microphone requirement.',
  });
}

class AndroidPreflightException implements Exception {
  const AndroidPreflightException(this.message);

  final String message;
}

Future<void> _runAdb(
  String adbPath,
  List<String> arguments,
  String operation,
) async {
  final result = await Process.run(adbPath, arguments);
  if (result.exitCode != 0) {
    throw AndroidPreflightException(
      'Unable to $operation with Android SDK adb. Check that the emulator is '
      'running and retry: "$adbPath connect ${arguments.last}".',
    );
  }
}

Future<String> _adbShell(
  String adbPath,
  String endpoint,
  List<String> command,
) async {
  final result = await Process.run(adbPath, [
    '-s',
    endpoint,
    'shell',
    ...command,
  ]);
  if (result.exitCode != 0) {
    throw AndroidPreflightException(
      'Unable to read ${command.join(' ')} from $endpoint. Reconnect with '
      'Android SDK adb and retry the preflight.',
    );
  }
  return (result.stdout as String).trim();
}

Future<String> _runFlutterDevices() async {
  final flutter = resolveFlutterExecutable();
  final result = await Process.run(flutter, [
    'devices',
    '--machine',
    '--device-timeout',
    '10',
  ]);
  if (result.exitCode != 0) {
    throw AndroidPreflightException(
      'Flutter device detection failed. Run "flutter doctor -v" and then '
      '"flutter devices --device-timeout 10" to inspect the SDK connection.',
    );
  }
  return result.stdout as String;
}

String _physicalValue(String output, RegExp value, String description) {
  final physicalLine = output
      .split(RegExp(r'\r?\n'))
      .firstWhere(
        (line) => line.toLowerCase().contains('physical'),
        orElse: () => output,
      );
  final match = value.firstMatch(physicalLine);
  if (match == null) {
    throw AndroidPreflightException(
      'The emulator did not return a valid $description.',
    );
  }
  return match.group(1)!;
}

Map<String, String> _parseOptions(List<String> arguments) {
  final options = <String, String>{};
  for (var index = 0; index < arguments.length; index += 1) {
    final argument = arguments[index];
    if (argument != '--endpoint' && argument != '--adb-path') {
      throw ArgumentError('Unknown argument: $argument');
    }
    if (index + 1 == arguments.length ||
        arguments[index + 1].startsWith('--')) {
      throw ArgumentError('$argument requires a value.');
    }
    options[argument] = arguments[index + 1];
    index += 1;
  }
  return options;
}

void _usage() {
  stderr.writeln('Usage:');
  stderr.writeln(
    '  dart run tool/p4_00_android_preflight.dart '
    '[--endpoint 127.0.0.1:7555] [--adb-path <SDK\\platform-tools\\adb.exe>]',
  );
}
