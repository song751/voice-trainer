import 'practice_target.dart';

enum ContentReviewStatus { draft, reviewed, approved }

final class PracticeTemplate {
  const PracticeTemplate({
    required this.id,
    required this.version,
    required this.kind,
    required this.target,
    required this.reviewStatus,
  }) : assert(id != ''),
       assert(version > 0);

  final String id;
  final int version;
  final PracticeKind kind;
  final PracticeTarget target;
  final ContentReviewStatus reviewStatus;
}
