import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/platform/application_lifecycle.dart';
import '../../../core/domain/persistence/session_repository.dart';
import '../../../core/domain/practice/practice_template.dart';
import '../../../core/domain/analysis/ui_analysis_frame.dart';
import '../domain/practice_session_state.dart';
import 'practice_session_coordinator.dart';
import 'ui_frame_decimator.dart';

final latestPracticeSessionProvider = StateProvider<PracticeSessionRecord?>(
  (ref) => null,
);

final livePracticeControllerProvider =
    NotifierProvider<LivePracticeController, PracticeSessionState>(
      LivePracticeController.new,
    );

/// The presentation layer watches only this 25 Hz stream. The coordinator's
/// 100 Hz raw stream remains an input to the decimator, never a page state.
final liveUiAnalysisFrameProvider = StreamProvider.autoDispose<UiAnalysisFrame>(
  (ref) {
    final coordinator = ref.watch(practiceSessionCoordinatorProvider);
    final target = ref.watch(practiceTemplateProvider).target;
    return decimateUiAnalysisFrames(coordinator.realtimeFrames, target: target);
  },
);

final class LivePracticeController extends Notifier<PracticeSessionState> {
  // Notifier.build may run again when a watched composition dependency changes
  // (for example a Web/Windows profile override in the same app lifetime).
  // These references must therefore be rebound instead of initialized once.
  late PracticeSessionCoordinator _coordinator;
  late PracticeTemplate _template;
  late SessionRepository _repository;
  late String Function() _newSessionId;
  String? _activeSessionId;
  Future<void> _lifecycleSerial = Future<void>.value();
  bool _pausedByLifecycle = false;

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
    state = RequestingPermission(sessionId: id);
    state = await _coordinator.start(
      PracticeSessionRequest(
        sessionId: id,
        template: _template,
        startedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> pause() async {
    _pausedByLifecycle = false;
    state = await _coordinator.pause();
  }

  Future<void> resume() async {
    _pausedByLifecycle = false;
    state = await _coordinator.resume();
  }

  Future<void> handleApplicationLifecycle(ApplicationLifecyclePhase phase) {
    final operation = _lifecycleSerial.then((_) async {
      switch (phase) {
        case ApplicationLifecyclePhase.background:
          if (state is Running) {
            state = await _coordinator.pause();
            _pausedByLifecycle = true;
          }
        case ApplicationLifecyclePhase.detached:
          if (state is Running) {
            state = await _coordinator.pause();
          }
          _pausedByLifecycle = false;
        case ApplicationLifecyclePhase.foreground:
          if (_pausedByLifecycle && state is Paused) {
            state = await _coordinator.resume();
            _pausedByLifecycle = false;
          }
      }
    });
    _lifecycleSerial = operation.catchError((_) {});
    return operation;
  }

  Future<void> stop() async {
    final current = state;
    if (current is Running || current is Paused) {
      state = Finalizing(sessionId: _activeSessionId!);
    }
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
