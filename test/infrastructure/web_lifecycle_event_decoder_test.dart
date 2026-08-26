import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/core/platform/application_lifecycle.dart';
import 'package:voice_trainer/infrastructure/lifecycle/web_lifecycle_event_decoder.dart';

void main() {
  const decoder = WebLifecycleEventDecoder();

  test('decodes every bounded browser lifecycle kind', () {
    const cases = <String, ApplicationLifecycleEventKind>{
      'pageHidden': ApplicationLifecycleEventKind.pageHidden,
      'pageVisible': ApplicationLifecycleEventKind.pageVisible,
      'microphonePermissionGranted':
          ApplicationLifecycleEventKind.microphonePermissionGranted,
      'microphonePermissionPrompt':
          ApplicationLifecycleEventKind.microphonePermissionPrompt,
      'microphonePermissionDenied':
          ApplicationLifecycleEventKind.microphonePermissionDenied,
      'inputDevicesChanged': ApplicationLifecycleEventKind.inputDevicesChanged,
      'audioContextRunning': ApplicationLifecycleEventKind.audioContextRunning,
      'audioContextSuspended':
          ApplicationLifecycleEventKind.audioContextSuspended,
      'audioContextInterrupted':
          ApplicationLifecycleEventKind.audioContextInterrupted,
      'audioContextClosed': ApplicationLifecycleEventKind.audioContextClosed,
      'workerInterrupted': ApplicationLifecycleEventKind.workerInterrupted,
      'workerRecovered': ApplicationLifecycleEventKind.workerRecovered,
    };
    for (final entry in cases.entries) {
      final event = decoder.decode('{"kind":"${entry.key}"}');
      expect(event.kind, entry.value);
      expect(event.detail, isNull);
    }
  });

  test('keeps only bounded detail and rejects malformed or unknown events', () {
    final event = decoder.decode(
      '{"kind":"audioContextSuspended","detail":"suspended"}',
    );
    expect(event.detail, 'suspended');
    expect(
      () => decoder.decode('{"kind":"futureEvent"}'),
      throwsFormatException,
    );
    expect(
      () => decoder.decode('{"kind":"pageHidden","detail":42}'),
      throwsFormatException,
    );
  });
}
