import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:voice_trainer/app/app_lifecycle_observer.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/domain/persistence/recording_sink.dart';
import 'package:voice_trainer/core/errors/app_exception.dart';
import 'package:voice_trainer/core/platform/application_lifecycle.dart';
import 'package:voice_trainer/infrastructure/persistence/recordings/native_recording_sink.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: _LifecycleGateApp()));
}

final class _LifecycleGateApp extends ConsumerStatefulWidget {
  const _LifecycleGateApp();

  @override
  ConsumerState<_LifecycleGateApp> createState() => _LifecycleGateAppState();
}

final class _LifecycleGateAppState extends ConsumerState<_LifecycleGateApp> {
  Directory? _gateRoot;
  bool _ready = false;
  bool _backgroundObserved = false;
  bool _roundTripObserved = false;
  bool _processRestored = false;
  bool _partialRecovered = false;
  String _storageResult = 'pending';
  bool _testingStorage = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(
      '${support.path}${Platform.pathSeparator}p4_05_gate',
    );
    final recordings = Directory(
      '${root.path}${Platform.pathSeparator}recordings',
    );
    final faultTarget = Directory(
      '${root.path}${Platform.pathSeparator}fault_target',
    );
    await root.create(recursive: true);
    await recordings.create(recursive: true);
    await faultTarget.create(recursive: true);

    final launchMarker = File(
      '${root.path}${Platform.pathSeparator}launch.marker',
    );
    final existingPartial = File(
      '${recordings.path}${Platform.pathSeparator}recovery.partial',
    );
    final restored = await launchMarker.exists();
    final hadPartial = await existingPartial.exists();
    await NativeRecordingStore(recordings).recoverIncompleteRecordings();
    final recovered = hadPartial && !await existingPartial.exists();
    await launchMarker.writeAsString('gate-v1', flush: true);
    await existingPartial.writeAsBytes(const <int>[1, 2, 3], flush: true);

    if (!mounted) return;
    setState(() {
      _gateRoot = root;
      _processRestored = restored;
      _partialRecovered = recovered;
      _ready = true;
    });
  }

  Future<void> _onPhase(ApplicationLifecyclePhase phase) async {
    final root = _gateRoot;
    if (!_ready || root == null) return;
    final backgroundMarker = File(
      '${root.path}${Platform.pathSeparator}background.marker',
    );
    if (phase == ApplicationLifecyclePhase.background) {
      _backgroundObserved = true;
      await backgroundMarker.writeAsString('background-v1', flush: true);
      return;
    }
    if (phase != ApplicationLifecyclePhase.foreground || _testingStorage) {
      return;
    }
    final wasBackgrounded =
        _backgroundObserved || await backgroundMarker.exists();
    if (!wasBackgrounded) return;
    _testingStorage = true;
    var storageResult = 'writable';
    final faultTarget = Directory(
      '${root.path}${Platform.pathSeparator}fault_target',
    );
    final sink = NativeRecordingSink(faultTarget);
    try {
      await sink.open(
        RecordingMetadata(
          sessionId: 'p4-05-storage-fault',
          startedAt: DateTime.utc(2026, 8, 27),
        ),
      );
      await sink.append(
        PcmChunk(
          sequenceNumber: 0,
          firstSampleIndex: 0,
          format: const CaptureFormat(sampleRate: 48000, channels: 1),
          bytes: Uint8List(8),
          captureMonotonicTime: Duration.zero,
        ),
      );
      await sink.abort();
    } catch (error) {
      final mapped = const AppErrorMapper().map(
        error,
        operation: FailureOperation.recording,
      );
      storageResult = mapped.failure.code.name;
      try {
        await sink.abort();
      } catch (_) {
        // The script restores the exact gate directory mode in its finally.
      }
    }
    if (!mounted) return;
    setState(() {
      _roundTripObserved = true;
      _storageResult = storageResult;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(applicationLifecycleBindingProvider);
    ref.listen(applicationLifecyclePhaseProvider, (_, next) {
      final phase = next.valueOrNull;
      if (phase != null) unawaited(_onPhase(phase));
    });
    final phase = ref.watch(applicationLifecyclePhaseProvider).valueOrNull;
    final sentinels = <String>[
      if (_ready) 'P4_05_READY',
      'P4_05_PHASE_${phase?.name.toUpperCase() ?? 'LOADING'}',
      if (_roundTripObserved) 'P4_05_BACKGROUND_FOREGROUND_OK',
      'P4_05_STORAGE_${_storageResult.toUpperCase()}',
      if (_processRestored) 'P4_05_PROCESS_RESTORED',
      if (_partialRecovered) 'P4_05_PARTIAL_RECOVERED',
    ];
    debugPrint('P4_05_GATE ${sentinels.join(' ')}');
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(sentinels.join('\n'), textDirection: TextDirection.ltr),
        ),
      ),
    );
  }
}
