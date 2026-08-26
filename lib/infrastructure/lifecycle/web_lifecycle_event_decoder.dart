import 'dart:convert';

import '../../core/platform/application_lifecycle.dart';

final class WebLifecycleEventDecoder {
  const WebLifecycleEventDecoder();

  ApplicationLifecycleEvent decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?> || decoded['kind'] is! String) {
      throw const FormatException('Invalid Web lifecycle event envelope.');
    }
    final kind = switch (decoded['kind']) {
      'pageHidden' => ApplicationLifecycleEventKind.pageHidden,
      'pageVisible' => ApplicationLifecycleEventKind.pageVisible,
      'microphonePermissionGranted' =>
        ApplicationLifecycleEventKind.microphonePermissionGranted,
      'microphonePermissionPrompt' =>
        ApplicationLifecycleEventKind.microphonePermissionPrompt,
      'microphonePermissionDenied' =>
        ApplicationLifecycleEventKind.microphonePermissionDenied,
      'inputDevicesChanged' =>
        ApplicationLifecycleEventKind.inputDevicesChanged,
      'audioContextRunning' =>
        ApplicationLifecycleEventKind.audioContextRunning,
      'audioContextSuspended' =>
        ApplicationLifecycleEventKind.audioContextSuspended,
      'audioContextInterrupted' =>
        ApplicationLifecycleEventKind.audioContextInterrupted,
      'audioContextClosed' => ApplicationLifecycleEventKind.audioContextClosed,
      'workerInterrupted' => ApplicationLifecycleEventKind.workerInterrupted,
      'workerRecovered' => ApplicationLifecycleEventKind.workerRecovered,
      _ => throw FormatException(
        'Unknown Web lifecycle event kind: ${decoded['kind']}',
      ),
    };
    final detail = decoded['detail'];
    if (detail != null && detail is! String) {
      throw const FormatException('Web lifecycle detail must be a string.');
    }
    return ApplicationLifecycleEvent(kind: kind, detail: detail as String?);
  }
}
