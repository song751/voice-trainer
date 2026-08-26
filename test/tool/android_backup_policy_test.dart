import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android source manifest disables backup and all transfer rules', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));

    final legacy = File(
      'android/app/src/main/res/xml/backup_rules.xml',
    ).readAsStringSync();
    final extraction = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();
    for (final domain in <String>[
      'root',
      'file',
      'database',
      'sharedpref',
      'external',
    ]) {
      expect(legacy, contains('<exclude domain="$domain" path="." />'));
      expect(
        RegExp(
          RegExp.escape('<exclude domain="$domain" path="." />'),
        ).allMatches(extraction),
        hasLength(2),
        reason:
            '$domain must be excluded from cloud backup and device transfer',
      );
    }
    for (final domain in <String>[
      'device_root',
      'device_file',
      'device_database',
      'device_sharedpref',
    ]) {
      expect(
        RegExp(
          RegExp.escape('<exclude domain="$domain" path="." />'),
        ).allMatches(extraction),
        hasLength(2),
        reason:
            '$domain must be excluded from cloud backup and device transfer',
      );
    }
  });
}
