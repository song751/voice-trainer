enum EvidenceBasis { absoluteThreshold, personalBaseline, compatibleHistory }

final class Evidence {
  const Evidence({
    required this.metric,
    required this.value,
    required this.basis,
  });

  final String metric;
  final double value;
  final EvidenceBasis basis;
}
