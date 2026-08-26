import 'recording_locator.dart';

/// Sanitized storage facts suitable for settings UI and gate evidence.
///
/// Browser-specific paths, database names and device identifiers are never
/// exposed. A production Web composition reports only durable storage kinds.
final class PersistenceStorageReport {
  const PersistenceStorageReport({
    required this.structuredDataKind,
    required this.recordingStorageKind,
    required this.isPersistent,
    this.missingFeatures = const <String>[],
  });

  final String structuredDataKind;
  final RecordingStorageKind recordingStorageKind;
  final bool isPersistent;
  final List<String> missingFeatures;
}
