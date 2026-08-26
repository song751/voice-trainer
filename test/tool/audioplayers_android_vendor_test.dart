import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vendored Android player retains official version and MIT license', () {
    final packageRoot = Directory('third_party/audioplayers_android');
    expect(packageRoot.existsSync(), isTrue);
    final pubspec = File('${packageRoot.path}/pubspec.yaml').readAsStringSync();
    final license = File('${packageRoot.path}/LICENSE').readAsStringSync();
    final provenance = File(
      '${packageRoot.path}/UPSTREAM.md',
    ).readAsStringSync();

    expect(pubspec, contains('version: 5.3.0'));
    expect(license, contains('MIT License'));
    expect(
      provenance,
      contains(
        'f5ff5b15620fbab8cb0849e9636c48e2b96c3f0f71723bbbe2ad3c761b205f05',
      ),
    );
    expect(
      File(
        '${packageRoot.path}/android/src/main/kotlin/'
        'xyz/luan/audioplayers/AudioplayersPlugin.kt',
      ).existsSync(),
      isTrue,
    );
  });

  test(
    'local build patch cannot resolve embedded AGP or Kotlin toolchains',
    () {
      final pluginBuild = File(
        'third_party/audioplayers_android/android/build.gradle',
      ).readAsStringSync();
      final rootSettings = File(
        'android/settings.gradle.kts',
      ).readAsStringSync();
      final lockfile = File('pubspec.lock').readAsStringSync();

      expect(pluginBuild, isNot(contains('buildscript')));
      expect(pluginBuild, isNot(contains('rootProject.allprojects')));
      expect(pluginBuild, isNot(contains('com.android.tools.build:gradle')));
      expect(pluginBuild, isNot(contains('kotlin-gradle-plugin')));
      expect(
        rootSettings,
        contains('com.android.application") version "9.0.1'),
      );
      expect(lockfile, contains('path: "third_party/audioplayers_android"'));
      expect(lockfile, contains('version: "5.3.0"'));
    },
  );
}
