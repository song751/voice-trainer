import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vendored file selector stays on the patched official release', () {
    final packageRoot = Directory('third_party/file_selector_android');
    expect(packageRoot.existsSync(), isTrue);

    final pubspec = File('${packageRoot.path}/pubspec.yaml').readAsStringSync();
    final license = File('${packageRoot.path}/LICENSE').readAsStringSync();
    final provenance = File(
      '${packageRoot.path}/UPSTREAM.md',
    ).readAsStringSync();
    expect(pubspec, contains('version: 0.5.2+9'));
    expect(
      license,
      contains('Redistribution and use in source and binary forms'),
    );
    expect(
      provenance,
      contains(
        '1d45e9910f68c16eb0c74f0b10097ad81aed516ea28054c027137e8f7d75e840',
      ),
    );
    expect(
      File(
        '${packageRoot.path}/lib/src/types/native_illegal_argument_exception.dart',
      ).existsSync(),
      isTrue,
    );
  });

  test('local patch reuses root AGP and cannot resolve private AGP 8.13.1', () {
    final pluginBuild = File(
      'third_party/file_selector_android/android/build.gradle.kts',
    ).readAsStringSync();
    final rootSettings = File('android/settings.gradle.kts').readAsStringSync();
    final lockfile = File('pubspec.lock').readAsStringSync();

    expect(pluginBuild, isNot(contains('buildscript')));
    expect(pluginBuild, isNot(contains('allprojects')));
    expect(pluginBuild, isNot(contains('8.13.1')));
    expect(rootSettings, contains('com.android.application") version "9.0.1'));
    expect(lockfile, contains('path: "third_party/file_selector_android"'));
    expect(lockfile, contains('version: "0.5.2+9"'));
  });
}
