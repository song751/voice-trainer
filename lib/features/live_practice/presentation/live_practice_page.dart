import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/route_names.dart';
import '../../../core/domain/analysis/analysis_quality_flag.dart';
import '../../../core/domain/analysis/ui_analysis_frame.dart';
import '../../../core/errors/failure.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/widgets/responsive_page_body.dart';
import '../application/live_practice_controller.dart';
import '../domain/practice_session_state.dart';

class LivePracticePage extends ConsumerWidget {
  const LivePracticePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(livePracticeControllerProvider);
    final completedSession = ref.watch(latestPracticeSessionProvider);
    final uiFrame = ref.watch(liveUiAnalysisFrameProvider).valueOrNull;
    final targetMidiNote = ref
        .watch(practiceTemplateProvider)
        .target
        .targetMidiNote;
    final controller = ref.read(livePracticeControllerProvider.notifier);
    final capabilities = ref.watch(platformCapabilitiesProvider);
    final hasNoData =
        sessionState is Completed &&
        (completedSession == null || completedSession.features.frames.isEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('实时练习')),
      body: ResponsivePageBody(
        child: ListView(
          key: const Key('live-page-scroll'),
          children: <Widget>[
            if (capabilities.capture == PlatformAdapterMode.fallback)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.science_outlined),
                  title: Text('当前使用测试适配器'),
                  subtitle: Text('页面展示的是确定性测试输入，不代表真实麦克风已通过。'),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _messageFor(sessionState),
                  key: const Key('practice-status'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _LiveReadout(frame: uiFrame, targetMidiNote: targetMidiNote),
            if (hasNoData) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                '暂无分析数据。请开始新的练习并确认麦克风输入正常。',
                key: Key('no-analysis-data'),
              ),
            ],
            if (sessionState is Failed) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _failureMessage(sessionState.failure),
                key: const Key('practice-error'),
              ),
            ],
            const SizedBox(height: 20),
            _controls(context, sessionState, controller),
          ],
        ),
      ),
    );
  }

  Widget _controls(
    BuildContext context,
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
        Completed() => <Widget>[
          FilledButton.icon(
            key: const Key('view-practice-result'),
            onPressed: () => context.go(RoutePaths.result),
            icon: const Icon(Icons.summarize_outlined),
            label: const Text('查看结果'),
          ),
        ],
        _ => const <Widget>[],
      },
    );
  }

  String _messageFor(PracticeSessionState state) => switch (state) {
    Idle() => '准备开始练习。',
    RequestingPermission() => '正在请求麦克风权限。',
    Ready() => '正在准备音频会话。',
    Running() => '练习进行中。',
    Paused(:final interruption) =>
      interruption == null
          ? '练习已暂停。'
          : interruption.recoveryReady
          ? '浏览器音频曾中断；已记录断点，请确认后继续。'
          : '浏览器音频已中断；等待页面或音频恢复。',
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

class _LiveReadout extends StatelessWidget {
  const _LiveReadout({required this.frame, required this.targetMidiNote});

  final UiAnalysisFrame? frame;
  final int targetMidiNote;

  @override
  Widget build(BuildContext context) {
    final targetMidi = frame?.targetMidiNote ?? targetMidiNote;
    final targetName = _noteName(targetMidi);
    final pitch = frame?.pitchCents;
    final offset = frame?.centsFromTarget;
    final qualityLabels = _qualityLabels(frame);
    return Semantics(
      container: true,
      label: '实时音高与信号质量',
      child: Column(
        key: const Key('live-analysis-readout'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('目标音：$targetName', key: const Key('target-note')),
          const SizedBox(height: 8),
          Text(
            pitch == null
                ? '音高：等待稳定音高'
                : '音高：${_noteName((pitch / 100).round())} '
                      '(${_signedCents(offset!)})',
            key: const Key('live-pitch'),
          ),
          Text(
            frame == null
                ? 'RMS：等待输入'
                : 'RMS：${frame!.rmsDbfs.toStringAsFixed(1)} dBFS',
            key: const Key('live-rms'),
          ),
          if (frame != null)
            Text(
              'Peak：${frame!.peakDbfs.toStringAsFixed(1)} dBFS · '
              '清晰度 ${(frame!.pitchClarity * 100).toStringAsFixed(0)}%',
              key: const Key('live-signal-details'),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: qualityLabels
                .map((label) => Chip(label: Text(label)))
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            child: SizedBox(
              height: 96,
              width: double.infinity,
              child: CustomPaint(
                key: const Key('pitch-ring'),
                painter: _PitchRingPainter(
                  points: frame?.pitchHistory ?? const <UiPitchPoint>[],
                  targetCents: targetMidi * 100.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _qualityLabels(UiAnalysisFrame? current) {
    if (current == null) {
      return const <String>['等待分析'];
    }
    if (current.qualityFlags.isEmpty) {
      return <String>[current.isWithinTarget ? '信号良好 · 在目标范围内' : '信号良好'];
    }
    return current.qualityFlags.map(_qualityLabel).toList(growable: false);
  }

  String _qualityLabel(AnalysisQualityFlag flag) => switch (flag) {
    AnalysisQualityFlag.clipping => '检测到输入削波，请降低输入音量或远离麦克风',
    AnalysisQualityFlag.inputTooLow => '输入偏低，请靠近麦克风并保持环境安静',
    AnalysisQualityFlag.discontinuity => '采集出现间断，稳定度不作解释',
    AnalysisQualityFlag.droppedSamples => '部分音频未及时分析，稳定度不作解释',
    AnalysisQualityFlag.processingAdjusted => '采集格式已调整',
    AnalysisQualityFlag.insufficientValidFrames => '有效信号不足，请保持稳定发声',
  };
}

String _noteName(int midi) {
  const names = <String>[
    'C',
    'C♯',
    'D',
    'D♯',
    'E',
    'F',
    'F♯',
    'G',
    'G♯',
    'A',
    'A♯',
    'B',
  ];
  final octave = midi ~/ 12 - 1;
  return '${names[midi % 12]}$octave';
}

String _signedCents(double cents) =>
    '${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(0)} cents';

class _PitchRingPainter extends CustomPainter {
  const _PitchRingPainter({required this.points, required this.targetCents});

  final List<UiPitchPoint> points;
  final double targetCents;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = const Color(0xffa9a9a9)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = const Color(0xff2962ff)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final midY = size.height / 2;
    canvas.drawLine(
      Offset.zero + Offset(0, midY),
      Offset(size.width, midY),
      axisPaint,
    );
    if (points.length < 2) {
      return;
    }
    final path = Path();
    var drawing = false;
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final cents = point.pitchCents;
      if (cents == null || point.discontinuityBefore) {
        drawing = false;
        continue;
      }
      final x = size.width * index / (points.length - 1);
      final y = (midY - (cents - targetCents) * 0.35)
          .clamp(0.0, size.height)
          .toDouble();
      if (!drawing) {
        path.moveTo(x, y);
        drawing = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_PitchRingPainter oldDelegate) =>
      !identical(oldDelegate.points, points) ||
      oldDelegate.targetCents != targetCents;
}
