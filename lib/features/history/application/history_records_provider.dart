import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/domain/persistence/session_repository.dart';

final historyRecordsProvider =
    AutoDisposeAsyncNotifierProvider<
      HistoryController,
      List<PracticeSessionRecord>
    >(HistoryController.new);

final class HistoryController
    extends AutoDisposeAsyncNotifier<List<PracticeSessionRecord>> {
  @override
  Future<List<PracticeSessionRecord>> build() =>
      ref.watch(sessionRepositoryProvider).listRecent();

  Future<void> refresh() async {
    state = const AsyncLoading<List<PracticeSessionRecord>>();
    state = await AsyncValue.guard(
      () => ref.read(sessionRepositoryProvider).listRecent(),
    );
  }

  Future<bool> deleteSession(String id) async {
    try {
      final repository = ref.read(sessionRepositoryProvider);
      await repository.delete(id);
      state = AsyncData(await repository.listRecent());
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
