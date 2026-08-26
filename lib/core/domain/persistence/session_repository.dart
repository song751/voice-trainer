import '../analysis/feature_series.dart';
import '../analysis/session_summary.dart';
import '../analysis/voice_comparison.dart';
import '../practice/practice_template.dart';
import '../practice/subjective_check_in.dart';
import 'recording_locator.dart';

final class PracticeSessionRecord {
  const PracticeSessionRecord({
    required this.id,
    required this.template,
    required this.startedAt,
    required this.summary,
    required this.features,
    this.checkIn,
    this.recording,
    this.voiceComparison,
  });

  final String id;
  final PracticeTemplate template;
  final DateTime startedAt;
  final SubjectiveCheckIn? checkIn;
  final SessionSummary summary;
  final FeatureSeries features;
  final RecordingLocator? recording;
  final VoiceComparisonTakeContext? voiceComparison;
}

abstract interface class SessionRepository {
  Future<void> save(PracticeSessionRecord record);

  Future<PracticeSessionRecord?> findById(String id);

  Future<List<PracticeSessionRecord>> listRecent({int limit = 20});

  /// Removes the recording through its durable deletion path before removing
  /// the session metadata.
  Future<void> delete(String id);

  /// Removes only the recording while retaining a session's feature history.
  Future<void> deleteRecording(String id);
}
