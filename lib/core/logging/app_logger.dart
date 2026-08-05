import 'log_redaction.dart';

enum AppLogLevel { debug, info, warning, error }

final class AppLogRecord {
  AppLogRecord({
    required this.level,
    required this.event,
    required Map<String, Object?> fields,
  }) : fields = Map<String, Object?>.unmodifiable(fields);

  final AppLogLevel level;
  final String event;
  final Map<String, Object?> fields;
}

typedef AppLogSink = void Function(AppLogRecord record);

/// Structured logger that redacts data before it reaches a platform sink.
final class AppLogger {
  AppLogger({AppLogSink? sink}) : _sink = sink ?? _discard;

  final AppLogSink _sink;
  final LogRedactor _redactor = const LogRedactor();

  void log(
    AppLogLevel level,
    String event, {
    Map<String, Object?> fields = const {},
    Object? error,
  }) {
    final safeFields = <String, Object?>{
      ...fields,
      if (error != null) 'errorType': error.runtimeType.toString(),
    };
    _sink(
      AppLogRecord(
        level: level,
        event: event,
        fields: _redactor.redact(safeFields),
      ),
    );
  }
}

void _discard(AppLogRecord _) {}
