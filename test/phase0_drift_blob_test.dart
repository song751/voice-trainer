import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/phase0/persistence/feature_blob_codec.dart';
import 'package:voice_trainer/phase0/persistence/phase0_database.dart';

void main() {
  test('feature BLOB v1 round-trips Float32 bits and validity bitset', () {
    const codec = FeatureBlobCodec();
    final values = Float32List.fromList([0, -0.0, 220.25, double.nan]);
    final validity = [true, false, true, false];
    final encoded = codec.encode(
      values: values,
      validity: validity,
      samplePeriodMicros: 50000,
    );
    final decoded = codec.decode(encoded);

    expect(decoded.values.buffer.asUint8List(), values.buffer.asUint8List());
    expect(decoded.validity, validity);
    expect(decoded.samplePeriodMicros, 50000);
  });

  test(
    'migration v1 creates only run and packed series domain tables',
    () async {
      final database = Phase0Database(NativeDatabase.memory());
      addTearDown(database.close);
      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      final tables = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
          )
          .get();

      expect(version.data.values.first, 1);
      expect(
        tables.map((row) => row.read<String>('name')),
        containsAll(['analysis_runs', 'feature_series']),
      );
      expect(
        tables.map((row) => row.read<String>('name')),
        isNot(contains('feature_frames')),
      );
    },
  );
}
