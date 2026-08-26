import 'package:flutter_test/flutter_test.dart';

import '../../tool/p4_00_android_preflight.dart';

void main() {
  test('resolves an explicit SDK adb before environment candidates', () {
    final resolved = resolveSdkAdbPath(
      explicitPath: r'E:\sdk\platform-tools\adb.exe',
      environment: const {'ANDROID_SDK_ROOT': r'C:\Android\Sdk'},
      fileExists: (path) => path == r'E:\sdk\platform-tools\adb.exe',
    );

    expect(resolved, r'E:\sdk\platform-tools\adb.exe');
  });

  test(
    'finds adb from Android SDK roots and reports an actionable failure',
    () {
      expect(
        resolveSdkAdbPath(
          environment: const {'ANDROID_SDK_ROOT': r'C:\Android\Sdk'},
          fileExists: (path) =>
              path == r'C:\Android\Sdk\platform-tools\adb.exe',
        ),
        r'C:\Android\Sdk\platform-tools\adb.exe',
      );

      expect(
        () =>
            resolveSdkAdbPath(environment: const {}, fileExists: (_) => false),
        throwsA(
          isA<AndroidPreflightException>().having(
            (error) => error.message,
            'message',
            contains('Android SDK Platform-Tools'),
          ),
        ),
      );
    },
  );

  test('resolves Flutter from the Dart SDK when flutter is not on PATH', () {
    expect(
      resolveFlutterExecutable(
        resolvedDartExecutable:
            r'C:\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe',
        environment: const {},
        fileExists: (path) => path == r'C:\flutter\flutter\bin\flutter.bat',
      ),
      r'C:\flutter\flutter\bin\flutter.bat',
    );
  });

  test('accepts only an explicit host and valid TCP endpoint', () {
    expect(parseAdbEndpoint('127.0.0.1:7555'), ('127.0.0.1', 7555));
    expect(parseAdbEndpoint('localhost:5037'), ('localhost', 5037));
    expect(() => parseAdbEndpoint('127.0.0.1'), throwsArgumentError);
    expect(() => parseAdbEndpoint('127.0.0.1:0'), throwsArgumentError);
    expect(() => parseAdbEndpoint('adb://127.0.0.1:7555'), throwsArgumentError);
  });

  test('extracts only the requested Flutter device id from machine output', () {
    const devices = '''
warning emitted before JSON
[
  {"name":"Windows","id":"windows","targetPlatform":"windows-x64"},
  {"name":"V2362A","id":"127.0.0.1:7555","targetPlatform":"android-x64"}
]
''';

    expect(
      flutterDeviceIdFromMachineOutput(devices, '127.0.0.1:7555'),
      '127.0.0.1:7555',
    );
    expect(flutterDeviceIdFromMachineOutput(devices, 'missing:1'), isNull);
  });

  test('sanitized report never includes spoofed model or raw properties', () {
    final report = AndroidPreflightReport(
      endpoint: '127.0.0.1:7555',
      flutterDeviceId: '127.0.0.1:7555',
      apiLevel: 35,
      abi: 'x86_64',
      resolution: '1080x1920',
      densityDpi: 480,
      microphoneFeature: true,
      lowLatencyAudioFeature: true,
      rootShellObserved: true,
    );

    final json = report.toJsonString();
    expect(json, contains('"emulator":true'));
    expect(json, contains('"realDevice":false'));
    expect(json, isNot(contains('V2362A')));
    expect(json, isNot(contains('ro.product.model')));
    expect(json, isNot(contains(r'C:\\Android')));
  });
}
