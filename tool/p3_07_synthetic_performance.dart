import 'dart:convert';
import 'dart:io';

import 'package:voice_trainer/core/metrics/p3_performance_observer.dart';

import 'p3_07_evidence.dart';

void main(List<String> arguments) {
  if (arguments.length != 3) {
    stderr.writeln(
      'Usage: dart run tool/p3_07_synthetic_performance.dart <output> <commit> <YYYY-MM-DD>',
    );
    exit(64);
  }
  final snapshot = P3PerformanceSnapshot(
    pipelineLatency: const P3Quantiles(p50: 42, p95: 58, count: 2),
    uiBuild: const P3Quantiles(p50: 2, p95: 3, count: 2),
    uiRaster: const P3Quantiles(p50: 3, p95: 5, count: 2),
    analysisQueueDroppedSamples: 0,
    recordingQueueDroppedSamples: 0,
    discontinuityCount: 0,
    memorySamples: const <P3MemorySample>[
      P3MemorySample(
        elapsed: Duration(seconds: 60),
        workingSetMib: 100,
        privateMib: 80,
      ),
    ],
    workerState: 'primary',
    workerRestartCount: 0,
  );
  final report = <String, dynamic>{
    'schema_version': p3_07EvidenceSchemaVersion,
    'commit': arguments[1],
    'captured_on': arguments[2],
    'build_mode': 'debug',
    'scenarios': <Object>[scenarioFromSnapshot(snapshot)],
  };
  final issues = validateP3_07Evidence(report);
  if (issues.isNotEmpty) {
    stderr.writeln(issues.join('\n'));
    exit(1);
  }
  File(arguments[0]).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(
    'Created synthetic P3-07 performance evidence (pending real-device gate).',
  );
}

Map<String, dynamic> scenarioFromSnapshot(
  P3PerformanceSnapshot snapshot,
) => <String, dynamic>{
  'scenario_id': 'windows_production_performance_usb',
  'evidence_kind': 'synthetic',
  'device_category': 'pending',
  'requested_format': <String, Object>{
    'sample_rate_hz': 48000,
    'channels': 1,
    'encoding': 'pcm16le',
  },
  'effective_format': <String, Object?>{
    'sample_rate_hz': null,
    'channels': null,
    'encoding': null,
  },
  'processing': <String, Object?>{
    'agc': null,
    'echo_cancellation': null,
    'noise_suppression': null,
  },
  'duration_seconds': 1,
  'sample_count': 48000,
  'dropped_samples':
      snapshot.analysisQueueDroppedSamples +
      snapshot.recordingQueueDroppedSamples,
  'discontinuity_count': snapshot.discontinuityCount,
  'pipeline_latency_ms': _quantiles(snapshot.pipelineLatency),
  'ui_build_ms': _quantiles(snapshot.uiBuild),
  'ui_raster_ms': _quantiles(snapshot.uiRaster),
  'memory_samples': snapshot.memorySamples
      .map(
        (sample) => <String, double>{
          'elapsed_seconds':
              sample.elapsed.inMicroseconds / Duration.microsecondsPerSecond,
          'working_set_mib': sample.workingSetMib,
          'private_mib': sample.privateMib,
        },
      )
      .toList(growable: false),
  'result': const <String, String>{
    'status': 'pending',
    'reason': 'Synthetic clock validates instrumentation only.',
  },
  'uncovered_reasons': const <String>[
    'Synthetic measurements cannot satisfy the real-device gate.',
  ],
};

Map<String, double?> _quantiles(P3Quantiles values) => <String, double?>{
  'p50': values.p50,
  'p95': values.p95,
};
