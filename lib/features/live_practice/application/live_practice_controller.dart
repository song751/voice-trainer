import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/domain/persistence/session_repository.dart';
import '../../../core/domain/practice/practice_template.dart';
import '../domain/practice_session_state.dart';
import 'practice_session_coordinator.dart';

final latestPracticeSessionProvider = StateProvider<PracticeSessionRecord?>(
  (ref) => null,
);

final livePracticeControllerProvider =
    NotifierProvider<LivePracticeController, PracticeSessionState>(
      LivePracticeController.new,
    );

final class LivePracticeController extends Notifier<PracticeSessionState> {
  late final PracticeSessionCoordinator _coordinator;
  late final PracticeTemplate _template;
  late final SessionRepository _repository;
  late final String Function() _newSessionId;
  String? _activeSessionId;

  @override
  PracticeSessionState build() {
    _coordinator = ref.watch(practiceSessionCoordinatorProvider);
    _template = ref.watch(practiceTemplateProvider);
    _repository = ref.watch(sessionRepositoryProvider);
    _newSessionId = ref.watch(sessionIdGeneratorProvider);
    return _coordinator.state;
  }

  Future<void> start() async {
    final id = _newSessionId();
    _activeSessionId = id;
    ref.read(latestPracticeSessionProvider.notifier).state = null;
    state = await _coordinator.start(
      PracticeSessionRequest(
        sessionId: id,
        template: _template,
        startedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> pause() async {
    state = await _coordinator.pause();
  }

  Future<void> resume() async {
    state = await _coordinator.resume();
  }

  Future<void> stop() async {
    state = await _coordinator.stop();
    final id = _activeSessionId;
    if (state is Completed && id != null) {
      ref.read(latestPracticeSessionProvider.notifier).state = await _repository
          .findById(id);
    }
  }

  Future<void> retry() async {
    state = await _coordinator.retry();
  }
}
