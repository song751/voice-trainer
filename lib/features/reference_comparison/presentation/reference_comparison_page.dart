import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/route_names.dart';
import '../../../core/domain/reference/reference_comparison.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_page_body.dart';
import '../../song_reference/application/song_reference_controller.dart';
import '../application/reference_comparison_controller.dart';

class ReferenceComparisonPage extends ConsumerStatefulWidget {
  const ReferenceComparisonPage({super.key});

  @override
  ConsumerState<ReferenceComparisonPage> createState() =>
      _ReferenceComparisonPageState();
}

class _ReferenceComparisonPageState
    extends ConsumerState<ReferenceComparisonPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref
          .read(referenceComparisonControllerProvider.notifier)
          .loadSessions(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(songReferenceControllerProvider).reference;
    final state = ref.watch(referenceComparisonControllerProvider);
    final controller = ref.read(referenceComparisonControllerProvider.notifier);
    if (song?.vocals == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('歌曲短句 A/B 对比')),
        body: EmptyState(
          icon: Icons.graphic_eq,
          title: '请先完成人声分离。',
          action: FilledButton(
            onPressed: () => context.go(RoutePaths.songImport),
            child: const Text('返回歌曲导入'),
          ),
        ),
      );
    }
    final referenceDuration = song!.durationSamples / song.sampleRate;
    final selected = state.selectedSession;
    final userDuration = selected == null
        ? 0.0
        : selected.features.frames.length / selected.features.frameRateHz;
    final busy = state.status == ReferenceComparisonStatus.analyzing;
    return Scaffold(
      appBar: AppBar(title: const Text('歌曲短句 A/B 对比')),
      body: ResponsivePageBody(
        child: ListView(
          key: const Key('reference-comparison-scroll'),
          children: <Widget>[
            Semantics(
              label: '歌曲短句参考对比',
              header: true,
              child: Text(
                song.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 4),
            const Text('参考来源：歌曲分离估计（没有逐句真人标签）。原唱是艺术参考，不是唯一正确答案。'),
            const SizedBox(height: 16),
            if (state.status == ReferenceComparisonStatus.loading)
              const LinearProgressIndicator()
            else if (state.sessions.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.mic_none),
                  title: Text('没有可回放的练习会话'),
                  subtitle: Text('先完成并保存一段录音；仅保存指标的会话仍保留历史，但不能用于本地 A/B 回放。'),
                ),
              )
            else ...<Widget>[
              DropdownButtonFormField<String>(
                key: const Key('comparison-session-picker'),
                isExpanded: true,
                initialValue: state.selectedSessionId,
                decoration: const InputDecoration(labelText: '练习会话'),
                items: state.sessions
                    .map(
                      (session) => DropdownMenuItem<String>(
                        value: session.id,
                        child: Text(
                          '${session.startedAt.toLocal()} · ${session.id}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) {
                        if (value != null) controller.selectSession(value);
                      },
              ),
              const SizedBox(height: 16),
              _PhraseSelector(
                title: '原唱人声窗口',
                durationSeconds: referenceDuration,
                range: state.referenceRange,
                enabled: !busy,
                onChanged: controller.setReferenceRange,
                onPreview: ref.watch(audioPreviewProvider).available
                    ? controller.previewReference
                    : null,
              ),
              _PhraseSelector(
                title: '我的练唱窗口',
                durationSeconds: userDuration,
                range: state.userRange,
                enabled: !busy,
                onChanged: controller.setUserRange,
                onPreview: ref.watch(audioPreviewProvider).available
                    ? controller.previewUser
                    : null,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: controller.stopPreview,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('停止回放'),
                ),
              ),
              if (state.previewFailure != null)
                Text(
                  '本地回放失败：${_previewFailure(state.previewFailure!)}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const Divider(height: 28),
              CheckboxListTile(
                key: const Key('artifact-review-confirmed'),
                value: state.artifactsAcceptable,
                onChanged: busy
                    ? null
                    : (value) =>
                          controller.setArtifactsAcceptable(value ?? false),
                title: const Text('我已试听：该窗口的分离伪影不妨碍比较'),
                subtitle: const Text('若有明显伴奏串音、混响拖尾或错分，请换窗口；算法不会代替这项听检。'),
              ),
              CheckboxListTile(
                key: const Key('monophonic-review-confirmed'),
                value: state.monophonicLeadConfirmed,
                onChanged: busy
                    ? null
                    : (value) =>
                          controller.setMonophonicLeadConfirmed(value ?? false),
                title: const Text('我已试听：该窗口以单一主旋律人声为主'),
                subtitle: const Text('和声、叠唱或多人声会让参考音高不可靠，因此必须抑制解释。'),
              ),
              FilledButton.icon(
                key: const Key('run-reference-comparison'),
                onPressed: busy ? null : controller.compare,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('分析这两个窗口'),
              ),
            ],
            if (busy) ...<Widget>[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: state.progress == 0 ? null : state.progress,
              ),
              Text('正在离线提取参考特征 ${(state.progress * 100).toStringAsFixed(0)}%'),
              TextButton(onPressed: controller.cancel, child: const Text('取消')),
            ],
            if (state.failure != null) ...<Widget>[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('参考特征分析不可用'),
                  subtitle: Text(_analysisFailure(state.failure!)),
                ),
              ),
            ],
            if (state.report case final report?) ...<Widget>[
              const SizedBox(height: 20),
              _ReportView(report: report),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhraseSelector extends StatelessWidget {
  const _PhraseSelector({
    required this.title,
    required this.durationSeconds,
    required this.range,
    required this.enabled,
    required this.onChanged,
    required this.onPreview,
  });

  final String title;
  final double durationSeconds;
  final PhraseRange range;
  final bool enabled;
  final ValueChanged<PhraseRange> onChanged;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final maximum = durationSeconds.clamp(1.0, 300.0).toDouble();
    final start = range.startSeconds.clamp(0.0, maximum - 0.5).toDouble();
    final end = range.endSeconds.clamp(start + 0.5, maximum).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('${start.toStringAsFixed(1)}–${end.toStringAsFixed(1)} s'),
                IconButton(
                  tooltip: '回放这个窗口',
                  onPressed: onPreview,
                  icon: const Icon(Icons.play_arrow),
                ),
              ],
            ),
            RangeSlider(
              values: RangeValues(start, end),
              min: 0,
              max: maximum,
              divisions: (maximum * 2).round().clamp(2, 600),
              labels: RangeLabels(
                '${start.toStringAsFixed(1)} s',
                '${end.toStringAsFixed(1)} s',
              ),
              onChanged: !enabled || maximum <= 1
                  ? null
                  : (values) {
                      if (values.end - values.start >= 1) {
                        onChanged(
                          PhraseRange(
                            startSeconds: values.start,
                            endSeconds: values.end,
                          ),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});

  final ReferenceComparisonReport report;

  @override
  Widget build(BuildContext context) {
    final metrics = report.metrics;
    final alignment = report.alignment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('对比观察', style: Theme.of(context).textTheme.headlineSmall),
        Text(report.referenceProvenanceLabel),
        Text(
          '内容 ID：参考 ${report.referenceContentId ?? "未验证"} · '
          '练唱 ${report.userContentId ?? "未验证"}',
        ),
        Text('范围：${report.scopeLabel}'),
        Text('置信度：${(report.confidence * 100).toStringAsFixed(0)}%'),
        Text(
          '版本：${report.algorithmVersion} · reference ${report.referenceAnalysisVersion} · '
          'user ${report.userAnalysisVersion} · separator ${report.separationAlgorithmVersion}',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: report.qualityFlags
              .map((flag) => Chip(label: Text(_qualityFlag(flag))))
              .toList(),
        ),
        if (report.suppressed) ...<Widget>[
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('已抑制对比解释：${report.suppressedReason}。请改善窗口或录音后重试。'),
            ),
          ),
        ] else if (metrics != null && alignment != null) ...<Widget>[
          _MetricCard(
            title: '对齐参数（全部公开）',
            lines: <String>[
              '进入时间差：${alignment.userOnsetDeltaSeconds >= 0 ? '+' : ''}${alignment.userOnsetDeltaSeconds.toStringAsFixed(3)} s（正值表示你更晚）',
              '时间伸缩：${alignment.tempoScale.toStringAsFixed(3)}×',
              '原始调性差：${alignment.originalKeyDifferenceCents.toStringAsFixed(1)} cents',
              '轮廓对齐移调：${alignment.transpositionSemitones >= 0 ? '+' : ''}${alignment.transpositionSemitones} 半音（原差值仍保留在上行）',
            ],
          ),
          _MetricCard(
            title: '音高轮廓（移调后）',
            lines: <String>[
              '中位绝对差 ${metrics.pitchContourMedianAbsoluteCents.toStringAsFixed(1)} cents',
              'P90 绝对差 ${metrics.pitchContourP90AbsoluteCents.toStringAsFixed(1)} cents',
            ],
          ),
          _MetricCard(
            title: '时序与有效覆盖',
            lines: <String>[
              '参考 / 练唱 voiced 覆盖 ${(metrics.referenceVoicedCoverage * 100).toStringAsFixed(0)}% / ${(metrics.userVoicedCoverage * 100).toStringAsFixed(0)}%',
              '互相可比覆盖 ${(metrics.mutuallyVoicedCoverage * 100).toStringAsFixed(0)}%，${metrics.matchedFrameCount} 帧',
              '参考 / 练唱 voiced 时长 ${metrics.referenceVoicedSpanSeconds.toStringAsFixed(2)} / ${metrics.userVoicedSpanSeconds.toStringAsFixed(2)} s',
            ],
          ),
          _MetricCard(
            title: '相对电平轮廓与稳定性',
            lines: <String>[
              '去中位电平后的包络差 ${metrics.levelEnvelopeMedianAbsoluteDb.toStringAsFixed(2)} dB',
              '参考 / 练唱段内电平 MAD ${metrics.referenceLevelMadDb.toStringAsFixed(2)} / ${metrics.userLevelMadDb.toStringAsFixed(2)} dB',
            ],
          ),
          _MetricCard(
            title: '周期性（YIN clarity）',
            lines: <String>[
              '参考 / 练唱中位数 ${metrics.referencePeriodicityMedian.toStringAsFixed(2)} / ${metrics.userPeriodicityMedian.toStringAsFixed(2)}',
              '这里只描述周期性证据，不推断漏气、闭合、声区或病理。',
            ],
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.replay),
              title: const Text('下一步：REFERENCE-AB-01'),
              subtitle: const Text(
                '先听参考，再听自己的同句；只选音高轮廓、进入时机或动态轮廓中的一个目标重练。当前内容为未审核产品假设，不标作专家建议。',
              ),
            ),
          ),
        ],
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('本页不给总分，也不自动分类假声、头声、强混、弱混或金属性；不会推断闭合、喉位、挤压、漏气或健康状态。'),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final line in lines) Text(line),
        ],
      ),
    ),
  );
}

String _qualityFlag(ReferenceComparisonQualityFlag flag) => switch (flag) {
  ReferenceComparisonQualityFlag.referenceContentUnverified => '参考内容未验证',
  ReferenceComparisonQualityFlag.userContentUnverified => '练唱内容未验证',
  ReferenceComparisonQualityFlag.referenceContentMismatch => '参考内容已变化',
  ReferenceComparisonQualityFlag.userContentMismatch => '练唱内容已变化',
  ReferenceComparisonQualityFlag.referenceIsSeparationEstimate => '分离估计',
  ReferenceComparisonQualityFlag.separationArtifactPossible => '可能含分离伪影',
  ReferenceComparisonQualityFlag.artifactReviewRequired => '需听检伪影',
  ReferenceComparisonQualityFlag.monophonicLeadReviewRequired => '需确认单旋律',
  ReferenceComparisonQualityFlag.referenceVoicingInsufficient => '参考 voiced 不足',
  ReferenceComparisonQualityFlag.userVoicingInsufficient => '练唱 voiced 不足',
  ReferenceComparisonQualityFlag.mutuallyVoicedCoverageInsufficient => '互相覆盖不足',
  ReferenceComparisonQualityFlag.referenceClipping => '参考削波',
  ReferenceComparisonQualityFlag.userCaptureQualityLimited => '练唱采集质量受限',
  ReferenceComparisonQualityFlag.phraseTooShort => '窗口过短',
  ReferenceComparisonQualityFlag.phraseTooLong => '窗口超过 30 秒',
};

String _analysisFailure(
  ReferenceAnalysisFailureReason reason,
) => switch (reason) {
  ReferenceAnalysisFailureReason.unavailable => '当前平台没有可用的本地 reference 分析运行时。',
  ReferenceAnalysisFailureReason.inputMissing => '分离人声文件已不存在。',
  ReferenceAnalysisFailureReason.unsupportedFormat =>
    '人声 stem 格式不符合 44.1 kHz WAV 合同。',
  ReferenceAnalysisFailureReason.decodeFailed => '人声 stem 解码失败。',
  ReferenceAnalysisFailureReason.resourceLimitExceeded => '人声文件超过本设备离线分析上限。',
  ReferenceAnalysisFailureReason.cancelled => '已取消分析。',
  ReferenceAnalysisFailureReason.insufficientAudio => '所选音频短于分析窗口。',
  ReferenceAnalysisFailureReason.processingFailed => '离线参考分析失败。',
};

String _previewFailure(AudioPreviewFailureReason reason) => switch (reason) {
  AudioPreviewFailureReason.unavailable => '当前平台没有本地播放器。',
  AudioPreviewFailureReason.sourceMissing => '音频文件已不存在。',
  AudioPreviewFailureReason.unsupportedLocator => '这份录音的存储类型暂不支持回放。',
  AudioPreviewFailureReason.playbackFailed => '播放器无法打开这个窗口。',
};
