import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../application/live_practice_controller.dart';
import '../domain/practice_session_state.dart';

class LivePracticePage extends ConsumerWidget {
  const LivePracticePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(livePracticeControllerProvider);
    final completedSession = ref.watch(latestPracticeSessionProvider);
    final controller = ref.read(livePracticeControllerProvider.notifier);
    final hasNoData =
        sessionState is Completed &&
        (completedSession == null || completedSession.features.frames.isEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('实时练习')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_messageFor(sessionState), key: const Key('practice-status')),
            const SizedBox(height: 16),
            if (hasNoData)
              const Text(
                '暂无分析数据。请开始新的练习并确认麦克风输入正常。',
                key: Key('no-analysis-data'),
              ),
            if (sessionState is Failed) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _failureMessage(sessionState.failure),
                key: const Key('practice-error'),
              ),
            ],
            const Spacer(),
            _controls(sessionState, controller),
          ],
        ),
      ),
    );
  }

  Widget _controls(
    PracticeSessionState state,
    LivePracticeController controller,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: switch (state) {
        Idle() => <Widget>[
          FilledButton(
            key: const Key('start-practice'),
            onPressed: controller.start,
            child: const Text('开始'),
          ),
        ],
        Running() => <Widget>[
          OutlinedButton(
            key: const Key('pause-practice'),
            onPressed: controller.pause,
            child: const Text('暂停'),
          ),
          FilledButton(
            key: const Key('stop-practice'),
            onPressed: controller.stop,
            child: const Text('结束'),
          ),
        ],
        Paused() => <Widget>[
          OutlinedButton(
            key: const Key('resume-practice'),
            onPressed: controller.resume,
            child: const Text('继续'),
          ),
          FilledButton(
            key: const Key('stop-practice'),
            onPressed: controller.stop,
            child: const Text('结束'),
          ),
        ],
        Failed(:final canRetry) when canRetry => <Widget>[
          FilledButton(
            key: const Key('retry-practice'),
            onPressed: controller.retry,
            child: const Text('重试'),
          ),
        ],
        _ => const <Widget>[],
      },
    );
  }

  String _messageFor(PracticeSessionState state) => switch (state) {
    Idle() => '准备开始模拟练习。',
    RequestingPermission() => '正在请求麦克风权限。',
    Ready() => '正在准备音频会话。',
    Running() => '模拟练习进行中。',
    Paused() => '练习已暂停。',
    Finalizing() => '正在保存练习结果。',
    Completed() => '练习已完成。',
    Failed() => '练习未完成。',
  };

  String _failureMessage(DomainFailure failure) => switch (failure.code) {
    FailureCode.permissionDenied => '无法开始：未授予麦克风权限。',
    FailureCode.captureUnavailable ||
    FailureCode.captureInterrupted => '无法开始：音频采集发生错误。',
    FailureCode.analysisUnavailable => '分析服务暂时不可用。',
    FailureCode.recordingUnavailable ||
    FailureCode.finalizationFailed ||
    FailureCode.persistenceFailed => '保存练习结果时发生错误。',
    FailureCode.invalidTransition => '当前操作不可用。',
    FailureCode.unexpected => '发生未预期的错误，请重试。',
  };
}
