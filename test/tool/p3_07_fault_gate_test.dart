import 'package:flutter_test/flutter_test.dart';
import '../../tool/p3_07_fault_gate.dart';

void main() {
  test('accepts only an explicit disposable Windows directory', () {
    expect(
      validateDiscardableRecordingRoot(r'E:\P3-07-disposable-recordings'),
      r'E:\P3-07-disposable-recordings',
    );
  });

  test('rejects root, workspace-like, profile, and unresolved targets', () {
    expect(() => validateDiscardableRecordingRoot(r'E:\'), throwsArgumentError);
    expect(
      () => validateDiscardableRecordingRoot(
        r'D:\project\voice-trainer\recordings',
      ),
      throwsArgumentError,
    );
    expect(
      () => validateDiscardableRecordingRoot(r'%TEMP%\voice'),
      throwsArgumentError,
    );
    expect(
      () => validateDiscardableRecordingRoot(r'relative\voice'),
      throwsArgumentError,
    );
  });
}
