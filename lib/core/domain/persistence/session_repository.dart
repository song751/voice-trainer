import '../analysis/feature_series.dart';
import '../analysis/session_summary.dart';
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
  });

  final String id;
  final PracticeTemplate template;
  final DateTime startedAt;
  final SubjectiveCheckIn? checkIn;
  final SessionSummary summary;
  final FeatureSeries features;
  final RecordingLocator? recording;
}

abstract interface class SessionRepository {
  Future<void> save(PracticeSessionRecord record);

  Future<PracticeSessionRecord?> findById(String id);
}
