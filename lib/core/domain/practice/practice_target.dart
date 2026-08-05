enum PracticeKind { sustainedNote, targetNote, glide }

final class PracticeTarget {
  const PracticeTarget({required this.targetMidiNote, this.toleranceCents = 25})
    : assert(targetMidiNote >= 0 && targetMidiNote <= 127),
      assert(toleranceCents > 0);

  final int targetMidiNote;
  final double toleranceCents;
}
