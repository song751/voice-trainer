import 'dart:typed_data';

const redactedValue = '[REDACTED]';
const redactedPath = '[REDACTED_PATH]';

final class LogRedactor {
  const LogRedactor();

  Map<String, Object?> redact(Map<String, Object?> fields) {
    return Map<String, Object?>.unmodifiable(
      fields.map((key, value) => MapEntry(key, _redactValue(key, value))),
    );
  }

  Object? _redactValue(String key, Object? value) {
    if (_isSensitiveKey(key)) return redactedValue;
    if (value == null || value is num || value is bool) return value;
    if (value is String) {
      return _looksLikeAbsolutePath(value) ? redactedPath : value;
    }
    if (value is Map<String, Object?>) return redact(value);
    if (value is Uint8List || value is Iterable) {
      return '[COLLECTION_REDACTED]';
    }
    return '[${value.runtimeType}]';
  }

  bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    return _sensitiveKeyFragments.any(normalized.contains);
  }

  bool _looksLikeAbsolutePath(String value) {
    if (value.startsWith('/') || value.startsWith(r'\\')) return true;
    return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value);
  }
}

const _sensitiveKeyFragments = <String>[
  'audio',
  'pcm',
  'bytes',
  'recordingpath',
  'filepath',
  'deviceid',
  'hardwareid',
  'userid',
  'note',
  'comment',
  'token',
  'secret',
  'password',
];
