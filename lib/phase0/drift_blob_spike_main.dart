import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';

import 'capture_process_exit.dart';
import 'persistence/feature_blob_codec.dart';
import 'persistence/phase0_connection.dart';
import 'persistence/phase0_database.dart';

const _frameCount = 24000;
const _autoStart = bool.fromEnvironment('AUTO_START_DRIFT');
const _autoExit = bool.fromEnvironment('AUTO_EXIT_DRIFT');

void main() => runApp(const MaterialApp(home: DriftBlobSpikePage()));

class DriftBlobSpikePage extends StatefulWidget {
  const DriftBlobSpikePage({super.key});

  @override
  State<DriftBlobSpikePage> createState() => _DriftBlobSpikePageState();
}

class _DriftBlobSpikePageState extends State<DriftBlobSpikePage> {
  String _status = 'Ready';
  bool _running = false;

  @override
  void initState() {
    super.initState();
    if (_autoStart) unawaited(_run());
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _status = 'Running…';
    });
    Phase0Database? database;
    try {
      final values = Float32List(_frameCount);
      final validity = List<bool>.filled(_frameCount, false);
      for (var index = 0; index < _frameCount; index++) {
        values[index] = 220 + 12 * math.sin(index * math.pi * 2 / 137);
        validity[index] = index % 97 != 0;
      }
      const codec = FeatureBlobCodec();
      final encodeClock = Stopwatch()..start();
      final blob = codec.encode(
        values: values,
        validity: validity,
        samplePeriodMicros: 50000,
      );
      encodeClock.stop();
      final checksum = sha256.convert(blob).toString();

      final connection = await openPhase0Connection();
      database = Phase0Database(connection.executor);
      final writeClock = Stopwatch()..start();
      final row = await database.replaceSpikeBlob(
        frameCount: _frameCount,
        payload: blob,
        checksum: checksum,
      );
      writeClock.stop();
      final readClock = Stopwatch()..start();
      final decoded = codec.decode(row.payload);
      readClock.stop();
      final roundTripBytes = _bytesEqual(blob, row.payload);
      final roundTripValues = _floatBitsEqual(values, decoded.values);
      final roundTripValidity = _boolsEqual(validity, decoded.validity);
      final checksumMatches =
          sha256.convert(row.payload).toString() == row.sha256;
      final tables = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
          )
          .get();
      final userVersion = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      final seriesCount = await database
          .customSelect(
            'SELECT COUNT(*) AS count FROM feature_series WHERE run_id = ?',
            variables: [Variable<int>(row.runId)],
          )
          .getSingle();
      final report = <String, Object?>{
        'schema': 'voice-trainer.drift-blob-spike.v1',
        'storageImplementation': connection.storageImplementation,
        'missingFeatures': connection.missingFeatures,
        'schemaVersion': userVersion.data.values.first,
        'tables': tables.map((row) => row.read<String>('name')).toList(),
        'analysisRunRows': 1,
        'featureSeriesRows': seriesCount.read<int>('count'),
        'perFrameSqlRows': 0,
        'frameCount': _frameCount,
        'samplePeriodMicros': decoded.samplePeriodMicros,
        'blobBytes': blob.lengthInBytes,
        'floatPayloadBytes': values.lengthInBytes,
        'validityBitsetBytes': (_frameCount + 7) ~/ 8,
        'sha256': checksum,
        'roundTripBytes': roundTripBytes,
        'roundTripFloatBits': roundTripValues,
        'roundTripValidity': roundTripValidity,
        'checksumMatches': checksumMatches,
        'timingMs': {
          'encode': encodeClock.elapsedMicroseconds / 1000,
          'write': writeClock.elapsedMicroseconds / 1000,
          'readDecode': readClock.elapsedMicroseconds / 1000,
        },
      };
      if (!(roundTripBytes &&
          roundTripValues &&
          roundTripValidity &&
          checksumMatches)) {
        throw StateError('Packed BLOB round-trip validation failed.');
      }
      final encoded = jsonEncode(report);
      debugPrint('PHASE0_DRIFT_REPORT=$encoded');
      if (mounted) {
        setState(
          () => _status = const JsonEncoder.withIndent('  ').convert(report),
        );
      }
      if (_autoExit) exitCaptureProcess();
    } catch (error, stack) {
      debugPrint('PHASE0_DRIFT_ERROR=$error\n$stack');
      if (mounted) setState(() => _status = 'ERROR: $error');
    } finally {
      await database?.close();
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phase 0 Drift packed BLOB spike')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('24,000 frames · 20 Hz · Float32 + validity bitset'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _running ? null : _run,
              child: Text(_running ? 'Running…' : 'Start Drift BLOB spike'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(child: SelectableText(_status)),
            ),
          ],
        ),
      ),
    );
  }
}

bool _bytesEqual(Uint8List first, Uint8List second) {
  if (first.lengthInBytes != second.lengthInBytes) return false;
  for (var index = 0; index < first.lengthInBytes; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

bool _floatBitsEqual(Float32List first, Float32List second) =>
    _bytesEqual(first.buffer.asUint8List(), second.buffer.asUint8List());

bool _boolsEqual(List<bool> first, List<bool> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
