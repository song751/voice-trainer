import 'dart:async';

import 'package:flutter/material.dart';

import 'capture_inspector.dart';
import 'capture_process_exit.dart';

const _durationSeconds = int.fromEnvironment(
  'CAPTURE_SECONDS',
  defaultValue: 60,
);
const _pauseAfterSeconds = int.fromEnvironment(
  'PAUSE_AFTER_SECONDS',
  defaultValue: 0,
);
const _pauseSeconds = int.fromEnvironment('PAUSE_SECONDS', defaultValue: 20);
const _bufferSize = int.fromEnvironment(
  'STREAM_BUFFER_SIZE',
  defaultValue: 1024,
);
const _deviceId = String.fromEnvironment('CAPTURE_DEVICE_ID');
const _autoStart = bool.fromEnvironment('AUTO_START_CAPTURE');
const _autoExit = bool.fromEnvironment('AUTO_EXIT_CAPTURE');

void main() {
  runApp(const MaterialApp(home: CaptureInspectorPage()));
}

class CaptureInspectorPage extends StatefulWidget {
  const CaptureInspectorPage({super.key});

  @override
  State<CaptureInspectorPage> createState() => _CaptureInspectorPageState();
}

class _CaptureInspectorPageState extends State<CaptureInspectorPage> {
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
      _status = 'Requesting microphone and capturing…';
    });
    try {
      final report = await CaptureInspector().run(
        CaptureInspectorOptions(
          captureDuration: const Duration(seconds: _durationSeconds),
          pauseAfter: _pauseAfterSeconds > 0
              ? const Duration(seconds: _pauseAfterSeconds)
              : null,
          pauseDuration: const Duration(seconds: _pauseSeconds),
          streamBufferSize: _bufferSize,
          deviceId: _deviceId.isEmpty ? null : _deviceId,
        ),
      );
      final pretty = report.toPrettyJson();
      debugPrint('PHASE0_CAPTURE_REPORT=${report.toCompactJson()}');
      if (mounted) setState(() => _status = pretty);
      if (_autoExit) exitCaptureProcess();
    } catch (error, stack) {
      debugPrint('PHASE0_CAPTURE_ERROR=$error\n$stack');
      if (mounted) setState(() => _status = 'ERROR: $error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phase 0 CaptureInspector')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PCM16 mono 48 kHz · buffer $_bufferSize · ${_durationSeconds}s'
              '${_pauseAfterSeconds > 0 ? ' · pause ${_pauseSeconds}s' : ''}',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _running ? null : _run,
              child: Text(_running ? 'Running…' : 'Start capture'),
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
