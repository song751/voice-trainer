import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/analysis/voice_comparison.dart';

final activeVoiceComparisonTakeProvider =
    StateProvider<VoiceComparisonTakeContext?>((ref) => null);
