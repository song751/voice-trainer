import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/domain/persistence/session_repository.dart';

final historyRecordsProvider =
    FutureProvider.autoDispose<List<PracticeSessionRecord>>(
      (ref) => ref.watch(sessionRepositoryProvider).listRecent(),
    );
