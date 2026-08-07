import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/domain/analysis/analysis_quality_flag.dart';
import '../../../core/domain/persistence/session_repository.dart';
import '../../../core/domain/observation/observation.dart';
import '../../live_practice/application/live_practice_controller.dart';

class SessionResultPage extends ConsumerWidget {
  const SessionResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(latestPracticeSessionProvider);
    if (record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('练习结果')),
        body: const Center(
          child: Text('暂无分析数据。完成练习后将在这里显示结果。', key: Key('result-no-data')),
        ),
      );
    }
    final result = ref
        .watch(observationEngineProvider)
        .evaluate(template: record.template, summary: record.summary);
    return Scaffold(
      appBar: AppBar(title: const Text('练习结果')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(
            '有效分析帧：${record.summary.validFrameCount}/${record.summary.totalFrameCount}',
            key: const Key('result-valid-frames'),
          ),
          const SizedBox(height: 8),
          Text(_hitRateLabel(record), key: const Key('result-hit-rate')),
          if (record.summary.qualityFlags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            const Text('录音质量'),
            ...record.summary.qualityFlags.map(
              (flag) => Text(_qualityLabel(flag)),
            ),
          ],
          const SizedBox(height: 16),
          const Text('本次观察'),
          ...result.observations.map(_observationTile),
          if (result.recommendations.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            const Text('下一步'),
            ...result.recommendations.map(
              (recommendation) =>
                  Text(_recommendationLabel(recommendation.exerciseId)),
            ),
          ],
        ],
      ),
    );
  }

  String _hitRateLabel(PracticeSessionRecord record) {
    final hitRate = record.summary.targetHitRate;
    return hitRate == null
        ? '目标命中率：录音质量不足，暂不计算。'
        : '目标命中率：${(hitRate * 100).toStringAsFixed(0)}%';
  }

  Widget _observationTile(Observation observation) => Text(
    _observationLabel(observation),
    key: Key('result-observation-${observation.ruleId}'),
  );

  String _observationLabel(Observation observation) =>
      switch (observation.labelKey) {
        'recording_quality_limited' => '本次录音质量不足，仅提供录音改善建议。',
        'target_alignment_consistent' => '有效帧大多落在目标音容差内。',
        'target_alignment_practice_needed' => '有效帧落在目标音容差内的比例有限，可重复目标音练习。',
        _ => '本次练习的描述性观察已生成。',
      };

  String _recommendationLabel(String exerciseId) => switch (exerciseId) {
    'improve-recording-input' => '靠近麦克风、避免削波，并在安静环境中保持稳定发声后重试。',
    'repeat-target-note' => '以舒适音量重复目标音，留意音高是否落在目标范围内。',
    _ => '请根据本次练习结果调整下一次练习。',
  };

  String _qualityLabel(AnalysisQualityFlag flag) => switch (flag) {
    AnalysisQualityFlag.clipping => '检测到削波：请降低输入音量或远离麦克风。',
    AnalysisQualityFlag.inputTooLow => '输入偏低：请靠近麦克风并保持环境安静。',
    AnalysisQualityFlag.discontinuity => '采集有间断：稳定度不作解释。',
    AnalysisQualityFlag.droppedSamples => '部分音频未及时分析：稳定度不作解释。',
    AnalysisQualityFlag.processingAdjusted => '采集格式已调整。',
    AnalysisQualityFlag.insufficientValidFrames => '有效信号不足：请保持稳定发声。',
  };
}
