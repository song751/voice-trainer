final class Recommendation {
  const Recommendation({
    required this.exerciseId,
    required this.reasonKey,
    required this.priority,
  }) : assert(exerciseId != ''),
       assert(priority >= 0);

  final String exerciseId;
  final String reasonKey;
  final int priority;
}
