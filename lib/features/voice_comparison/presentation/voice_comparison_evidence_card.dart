import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/analysis/analysis_quality_flag.dart';
import '../../../core/domain/analysis/voice_comparison.dart';
import '../../../core/domain/analysis/voice_production_profile.dart';
import '../application/voice_comparison_controller.dart';
import '../application/voice_comparison_evidence.dart';

class VoiceComparisonEvidenceCard extends ConsumerWidget {
  const VoiceComparisonEvidenceCard({required this.plan, super.key});

  final VoiceComparisonPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evidence = ref.watch(voiceComparisonEvidenceProvider(plan));
    return Semantics(
      container: true,
      label: '发声对比的描述性声学证据',
      child: Card(
        key: const Key('voice-comparison-evidence-card'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: evidence.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('发声对比记录暂时无法读取。'),
            data: (value) => _EvidenceBody(evidence: value),
          ),
        ),
      ),
    );
  }
}

class _EvidenceBody extends StatelessWidget {
  const _EvidenceBody({required this.evidence});

  final VoiceComparisonEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final plan = evidence.plan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('发声对比证据', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'A：${voiceIntentLabel(plan.labelA.labelKey)} · '
          'B：${voiceIntentLabel(plan.labelB.labelKey)}',
          key: const Key('voice-comparison-labels'),
        ),
        Text(
          '词表：${plan.labelA.vocabularyId} ${plan.labelA.vocabularyVersion} · '
          '${labelSourceLabel(plan.labelA.source)}',
        ),
        Text('合格样本：A ${evidence.takeCountA} 次 · B ${evidence.takeCountB} 次'),
        if (evidence.rejectedTakeCount > 0)
          Semantics(
            liveRegion: true,
            child: Text(
              '已排除 ${evidence.rejectedTakeCount} 个质量不合格样本：'
              '${evidence.qualityFlags.isEmpty ? '有效帧不足' : evidence.qualityFlags.map(_qualityFlagLabel).join('、')}。'
              '这些样本不会永久污染对比结果，可返回本页重新选择 A 或 B 录制。',
              key: const Key('voice-comparison-rejected-takes'),
            ),
          ),
        const SizedBox(height: 8),
        const Text('这里只比较人工意图标签下的消费麦克风声学输出；不会自动识别声区、混声、假声或金属性。'),
        const Text('未测量声带闭合、喉位、肌肉活动或发声机制，也不判断哪一种更正确。'),
        const SizedBox(height: 12),
        switch (evidence.status) {
          VoiceComparisonEvidenceStatus.waitingForTakes => const Text(
            '至少需要 A、B 各一个质量合格样本；建议每侧录制 3 次以观察重复性。',
            key: Key('voice-comparison-waiting'),
          ),
          VoiceComparisonEvidenceStatus.suppressed => Text(
            '已抑制差异解释：${evidence.suppressedReason}。请保持相同音高、元音、响度、风格、设备/麦距和协议后重录。',
            key: const Key('voice-comparison-suppressed'),
          ),
          VoiceComparisonEvidenceStatus.ready => Column(
            key: const Key('voice-comparison-deltas'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('以下均为 B − A；正负只表示方向，不表示优劣：'),
              const SizedBox(height: 6),
              ...evidence.deltas.map(
                (delta) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(_deltaLabel(delta)),
                ),
              ),
            ],
          ),
        },
        const SizedBox(height: 12),
        Text(
          '证据置信度：${_percent(evidence.confidence.conservativeScore)} · '
          '信号 ${_percent(evidence.confidence.signalQuality)} · '
          '任务匹配 ${_percent(evidence.confidence.taskMatch)} · '
          '重复性 ${_percent(evidence.confidence.repeatability)}',
          key: const Key('voice-comparison-confidence'),
        ),
      ],
    );
  }

  String _deltaLabel(VoiceComparisonDelta delta) {
    final value = delta.valueBMinusA;
    final signed = '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}';
    return switch (delta.metricId) {
      'pitch_median' => '音高中位数：$signed cents',
      'level_median' => '输入电平中位数：$signed dBFS',
      'periodicity_median' => '周期性/清晰度：$signed（0–1）',
      'onset_delay' => '稳定音高形成时间：$signed samples',
      'relative_2_4khz' => '2–4 kHz 相对能量：$signed dB',
      _ => '${delta.metricId}：$signed ${delta.unit.name}',
    };
  }

  String _percent(double value) => '${(value * 100).toStringAsFixed(0)}%';

  String _qualityFlagLabel(AnalysisQualityFlag flag) => switch (flag) {
    AnalysisQualityFlag.clipping => '削波',
    AnalysisQualityFlag.inputTooLow => '输入电平过低',
    AnalysisQualityFlag.discontinuity => '音频不连续',
    AnalysisQualityFlag.droppedSamples => '采样丢失',
    AnalysisQualityFlag.processingAdjusted => '处理参数被调整',
    AnalysisQualityFlag.insufficientValidFrames => '有效帧不足',
  };
}

String voiceIntentLabel(String key) => switch (key) {
  'neutral' => '中性',
  'chestVoice' => '胸声',
  'headVoice' => '头声',
  'falsetto' => '假声',
  'weakMix' => '弱混',
  'strongMix' => '强混',
  'metallic' => '金属性',
  _ => key,
};

String labelSourceLabel(PedagogicalLabelSource source) => switch (source) {
  PedagogicalLabelSource.singerIntent => '演唱者意图',
  PedagogicalLabelSource.teacherPrompt => '教师提示',
  PedagogicalLabelSource.blindedListenerConsensus => '盲听共识',
};
