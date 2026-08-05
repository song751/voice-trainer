import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:voice_trainer/src/rust/api/realtime.dart';
import 'package:voice_trainer/src/rust/frb_generated.dart';

import 'capture_process_exit.dart';
import 'dsp_report_writer.dart';
import 'process_memory.dart';

const _sampleRate = 48000;
const _seconds = int.fromEnvironment('DSP_SECONDS', defaultValue: 600);
const _batchSize = int.fromEnvironment('DSP_BATCH_SIZE', defaultValue: 512);
const _autoExit = bool.fromEnvironment('AUTO_EXIT_DSP');
const _autoStart = bool.fromEnvironment('AUTO_START_DSP');

Future<void> main() async {
  await RustLib.init();
  runApp(const MaterialApp(home: DspBenchmarkPage()));
}

class DspBenchmarkPage extends StatefulWidget {
  const DspBenchmarkPage({super.key});

  @override
  State<DspBenchmarkPage> createState() => _DspBenchmarkPageState();
}

class _DspBenchmarkPageState extends State<DspBenchmarkPage> {
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
    try {
      final analyzer = RealtimeAnalyzer(sampleRate: _sampleRate);
      final totalSamples = _sampleRate * _seconds;
      final callUs = <int>[];
      final residentBefore = currentResidentBytes();
      var sampleIndex = 0;
      var frameCount = 0;
      var startSampleChecksum = BigInt.zero;
      var rmsChecksum = 0.0;
      var pitchChecksum = 0.0;
      final totalClock = Stopwatch()..start();
      var callCount = 0;
      while (sampleIndex < totalSamples) {
        final count = math.min(_batchSize, totalSamples - sampleIndex);
        final batch = List<int>.generate(count, (offset) {
          final phase =
              math.pi * 2 * 220 * (sampleIndex + offset) / _sampleRate;
          return (math.sin(phase) * 16000).truncate();
        }, growable: false);
        sampleIndex += count;

        final callClock = Stopwatch()..start();
        final frames = analyzer.pushPcm16(pcm: batch);
        callClock.stop();
        callUs.add(callClock.elapsedMicroseconds);
        for (final frame in frames) {
          frameCount++;
          startSampleChecksum += frame.startSample;
          rmsChecksum += frame.rms;
          pitchChecksum += frame.pitchHz ?? 0.0;
        }
        callCount++;
        if (callCount % 64 == 0) await Future<void>.delayed(Duration.zero);
      }
      totalClock.stop();
      final sorted = List<int>.from(callUs)..sort();
      int percentile(double fraction) =>
          sorted[((sorted.length - 1) * fraction).ceil()];
      final residentAfter = currentResidentBytes();
      final report = <String, Object?>{
        'schema': 'voice-trainer.dsp-benchmark.v1',
        'sampleRate': _sampleRate,
        'simulatedSeconds': _seconds,
        'batchSize': _batchSize,
        'totalSamples': totalSamples,
        'callCount': callCount,
        'frameCount': frameCount,
        'elapsedMs': totalClock.elapsedMicroseconds / 1000,
        'realtimeMultiple':
            _seconds *
            Duration.microsecondsPerSecond /
            totalClock.elapsedMicroseconds,
        'callMs': {
          'p50': percentile(0.5) / 1000,
          'p95': percentile(0.95) / 1000,
          'max': sorted.last / 1000,
        },
        'checksums': {
          'startSample': startSampleChecksum.toString(),
          'rms': rmsChecksum,
          'pitchHz': pitchChecksum,
        },
        'residentBytesBefore': residentBefore,
        'residentBytesAfter': residentAfter,
        'residentGrowthBytes': residentBefore == null || residentAfter == null
            ? null
            : residentAfter - residentBefore,
      };
      final encoded = jsonEncode(report);
      await writeDspReport(encoded, _batchSize);
      debugPrint('PHASE0_DSP_REPORT=$encoded');
      if (mounted) {
        setState(
          () => _status = const JsonEncoder.withIndent('  ').convert(report),
        );
      }
      if (_autoExit) exitCaptureProcess();
    } catch (error, stack) {
      debugPrint('PHASE0_DSP_ERROR=$error\n$stack');
      if (mounted) setState(() => _status = 'ERROR: $error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phase 0 DSP benchmark')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$_seconds simulated seconds · batch $_batchSize'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _running ? null : _run,
              child: Text(_running ? 'Running…' : 'Start DSP benchmark'),
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
