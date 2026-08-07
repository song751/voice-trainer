import 'dart:io';

import 'p3_07_evidence.dart';

void main(List<String> arguments) {
  if (arguments.isEmpty || !arguments.contains('--dry-run')) _usage();
  final command = arguments.first;
  try {
    switch (command) {
      case 'plan':
        if (arguments.length < 3 || arguments[1].startsWith('--')) _usage();
        final scenario = arguments[1];
        if (!p3_07ScenarioIds.contains(scenario)) {
          stderr.writeln('Unknown P3-07 scenario.');
          exit(64);
        }
        final root = _option(arguments, '--recording-root');
        if (root != null) {
          final resolved = validateDiscardableRecordingRoot(root);
          stdout.writeln(
            'Validated explicit discardable recording root: $resolved',
          );
        }
        stdout.writeln('DRY RUN ONLY: ${_instructionsFor(scenario)}');
        stdout.writeln(
          'No permission, device, process, or file-system state was changed.',
        );
      case 'validate-recording-root':
        final root = _option(arguments, '--recording-root');
        if (root == null) _usage();
        stdout.writeln(validateDiscardableRecordingRoot(root));
      default:
        _usage();
    }
  } on ArgumentError catch (error) {
    stderr.writeln(error.message);
    exit(64);
  }
}

/// Validates an explicitly supplied disposable recording directory without
/// creating, deleting, or modifying it.  A human must still confirm the target
/// in the documented Windows runbook before a real disk-failure exercise.
String validateDiscardableRecordingRoot(String suppliedPath) {
  final trimmed = suppliedPath.trim();
  if (trimmed.isEmpty ||
      trimmed.contains(RegExp(r'[%$]')) ||
      trimmed.startsWith('~')) {
    throw ArgumentError('Recording root must be an explicit absolute path.');
  }
  final windowsAbsolute = RegExp(r'^[A-Za-z]:[\\/]');
  if (!windowsAbsolute.hasMatch(trimmed)) {
    throw ArgumentError(
      'Recording root must be an explicit Windows absolute path.',
    );
  }
  final normalized = trimmed
      .replaceAll('/', '\\')
      .replaceAll(RegExp(r'\\+$'), '');
  if (RegExp(r'^[A-Za-z]:$').hasMatch(normalized)) {
    throw ArgumentError('Drive roots are never safe recording targets.');
  }
  final workspace = Directory.current.absolute.path
      .replaceAll('/', '\\')
      .toLowerCase();
  final userProfile = Platform.environment['USERPROFILE']
      ?.replaceAll('/', '\\')
      .toLowerCase();
  final candidate = normalized.toLowerCase();
  if (candidate == workspace || candidate.startsWith('$workspace\\')) {
    throw ArgumentError('Workspace paths are never safe recording targets.');
  }
  if (userProfile != null &&
      (candidate == userProfile || candidate.startsWith('$userProfile\\'))) {
    throw ArgumentError('User-profile paths are never safe recording targets.');
  }
  return normalized;
}

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}

String _instructionsFor(String scenario) => switch (scenario) {
  'windows_permission_initial_denied' =>
    'Open Windows microphone privacy settings, deny access before app launch, then start the release app.',
  'windows_permission_revoked' =>
    'Start a release capture, revoke microphone access manually, and observe the typed failure.',
  'windows_no_input_devices' =>
    'Manually disable or disconnect inputs, confirm the endpoint list is empty, then start the release app.',
  'windows_usb_unplug_replug' =>
    'Start with an explicit USB selection, physically unplug/replug it, and choose the re-enumerated endpoint.',
  'windows_effective_format_change' =>
    'Select an input whose requested and effective formats can differ; retain pending if Windows resamples invisibly.',
  'windows_disk_write_failure' =>
    'Use only the human-confirmed disposable recording root, interrupt writable storage, then restore it before cleanup.',
  'windows_crash_recovery' =>
    'Terminate only the voice_trainer test process, restart it, and inspect partial/tombstone/history recovery.',
  _ =>
    'Collect the named scenario with the release product and the P3-07 evidence runner.',
};

Never _usage() {
  stderr.writeln('Usage:');
  stderr.writeln(
    '  dart run tool/p3_07_fault_gate.dart plan <scenario-id> --dry-run [--recording-root <absolute-disposable-path>]',
  );
  stderr.writeln(
    '  dart run tool/p3_07_fault_gate.dart validate-recording-root --recording-root <absolute-disposable-path> --dry-run',
  );
  exit(64);
}
