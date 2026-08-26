import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/domain/analysis/analysis_quality_flag.dart';
import '../../../core/domain/analysis/session_summary.dart';
import '../../../core/domain/observation/evidence.dart';
import '../../../core/domain/observation/observation.dart';
import '../../../core/domain/observation/recommendation.dart';
import '../../../core/domain/persistence/session_repository.dart';
import '../../../core/domain/practice/practice_template.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_page_body.dart';
import '../../live_practice/application/live_practice_controller.dart';

class SessionResultPage extends ConsumerWidget {
  const SessionResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(latestPracticeSessionProvider);
    if (record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('练习结果')),
        body: const EmptyState(
          key: Key('result-no-data'),
          icon: Icons.summarize_outlined,
          title: '暂无分析数据。',
          message: '完成练习或从历史记录中选择一次练习后，这里会显示结果。',
        ),
      );
    }
    final result = ref
        .watch(observationEngineProvider)
        .evaluate(template: record.template, summary: record.summary);
    return Scaffold(
      appBar: AppBar(title: const Text('练习结果')),
      body: ResponsivePageBody(
        child: ListView(
          children: <Widget>[
            _SummaryCard(record: record),
            const SizedBox(height: 12),
            _MeasurementsCard(summary: record.summary),
            if (record.summary.qualityFlags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _QualityCard(flags: record.summary.qualityFlags),
            ],
            const SizedBox(height: 20),
            Text('本次观察', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...result.observations.map(
              (observation) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ObservationCard(observation: observation),
              ),
            ),
            const SizedBox(height: 12),
            Text('下一步', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (result.recommendations.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('本次没有额外练习建议，可保持舒适音量继续练习。'),
                ),
              )
            else
              ...result.recommendations.map(
                (recommendation) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecommendationCard(recommendation: recommendation),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.record});

  final PracticeSessionRecord record;

  @override
  Widget build(BuildContext context) {
    final hitRate = record.summary.targetHitRate;
    final targetDeviation = record.summary.targetDeviationMedianCents;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('结果有效性', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '有效分析帧：${record.summary.validFrameCount}/${record.summary.totalFrameCount}',
              key: const Key('result-valid-frames'),
            ),
            Text(
              hitRate == null
                  ? '目标命中率：录音质量不足，暂不计算。'
                  : '目标命中率：${(hitRate * 100).toStringAsFixed(0)}%',
              key: const Key('result-hit-rate'),
            ),
            if (targetDeviation != null)
              Text(
                '目标音高中位偏差：${_signedValue(targetDeviation, 1)} cents',
                key: const Key('result-target-deviation'),
              ),
            Text('录音状态：${record.recording == null ? '仅保存指标' : '已保存录音'}'),
          ],
        ),
      ),
    );
  }
}

class _MeasurementsCard extends StatelessWidget {
  const _MeasurementsCard({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('描述性测量', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('这些是物理测量，不代表医疗诊断或发声机理判断。'),
          const SizedBox(height: 12),
          _StabilityLine(
            key: const Key('result-pitch-stability'),
            label: '音高稳定度',
            value: summary.pitchStability,
            unit: 'cents',
          ),
          const SizedBox(height: 8),
          _StabilityLine(
            key: const Key('result-level-stability'),
            label: '音量稳定度',
            value: summary.levelStability,
            unit: 'dB',
          ),
          const SizedBox(height: 8),
          Text(
            summary.onsetDelaySamples == null
                ? '起音稳定时间：数据不足'
                : '起音稳定时间：${summary.onsetDelaySamples} 样本',
            key: const Key('result-onset'),
          ),
        ],
      ),
    ),
  );
}

class _StabilityLine extends StatelessWidget {
  const _StabilityLine({
    required this.label,
    required this.value,
    required this.unit,
    super.key,
  });

  final String label;
  final StabilitySummary? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final measurement = value;
    if (measurement == null) return Text('$label：数据不足');
    return Text(
      '$label：MAD ${measurement.medianAbsoluteDeviation.toStringAsFixed(1)} $unit；'
      '漂移 ${_signed(measurement.slopePerSecond)} $unit/秒；'
      '${measurement.frameCount} 帧',
    );
  }

  String _signed(double value) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}';
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.flags});

  final Set<AnalysisQualityFlag> flags;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('录音质量', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...flags.map((flag) => Text('• ${_qualityLabel(flag)}')),
        ],
      ),
    ),
  );
}

class _ObservationCard extends StatelessWidget {
  const _ObservationCard({required this.observation});

  final Observation observation;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('result-observation-${observation.ruleId}'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _observationLabel(observation),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('置信度 ${(observation.confidence * 100).toStringAsFixed(0)}%'),
          Text('范围：${_scopeLabel(observation.scope)}'),
          Text('规则：${observation.ruleId} v${observation.ruleVersion}'),
          Text('依据：${_basisLabel(observation.basis)}'),
          const SizedBox(height: 8),
          ...observation.evidence.map(
            (evidence) => Text('证据：${_evidenceLabel(evidence)}'),
          ),
          if (observation.suppressedReasonKey != null) ...<Widget>[
            const SizedBox(height: 8),
            const Text('由于信号质量或有效帧不足，已抑制进一步解释。'),
          ],
        ],
      ),
    ),
  );
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation});

  final Recommendation recommendation;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_recommendationLabel(recommendation.exerciseId)),
          const SizedBox(height: 8),
          Text('练习 ID：${recommendation.exerciseId}'),
          Text('内容版本：v${recommendation.contentVersion}'),
          Text('审核状态：${_reviewStatusLabel(recommendation.reviewStatus)}'),
          Text('证据等级：${_evidenceGradeLabel(recommendation.evidenceGrade)}'),
          Text(
            '建议置信度：${(recommendation.confidence * 100).toStringAsFixed(0)}%',
          ),
          Text('适用范围：${_scopeLabel(recommendation.scope)}'),
          Text('建议依据：${recommendation.reasonKey}'),
          Text('来源：${recommendation.sourceIds.join(', ')}'),
          if (recommendation.limitations.isNotEmpty)
            Text('限制：${recommendation.limitations.join(', ')}'),
          const SizedBox(height: 8),
          ..._recommendationSteps(
            recommendation.exerciseId,
          ).map((step) => Text('• $step')),
          if (recommendation.reviewStatus !=
              ContentReviewStatus.approved) ...<Widget>[
            const SizedBox(height: 8),
            const Text('此内容尚未标记为专家审核通过。'),
          ],
        ],
      ),
    ),
  );
}

String _observationLabel(Observation observation) =>
    switch (observation.labelKey) {
      'recording_quality_limited' => '本次录音质量不足，仅提供录音改善建议。',
      'target_alignment_consistent' => '有效帧大多落在目标音容差内。',
      'target_alignment_practice_needed' => '有效帧落在目标音容差内的比例有限，可重复目标音练习。',
      'target_pitch_consistently_high' => '有效帧的音高中位数高于目标容差。',
      'target_pitch_consistently_low' => '有效帧的音高中位数低于目标容差。',
      'pitch_variation_observed' => '稳态片段测得的音高波动较大。',
      'pitch_drift_upward' => '稳态片段测得音高随时间上升。',
      'pitch_drift_downward' => '稳态片段测得音高随时间下降。',
      'level_variation_observed' => '稳态片段测得的音量波动较大。',
      'level_drift_upward' => '稳态片段测得音量随时间上升。',
      'level_drift_downward' => '稳态片段测得音量随时间下降。',
      'stable_pitch_onset_delayed' => '从达到输入能量到形成稳定音高的时间较长。',
      _ => '本次练习的描述性观察已生成。',
    };

String _recommendationLabel(String exerciseId) => switch (exerciseId) {
  'REC-QUALITY-01' => '先改善录音条件，再重新测量。',
  'PITCH-MATCH-01' => '舒适音区单音模唱与隐藏反馈复测。',
  _ => '请根据本次练习结果调整下一次练习。',
};

List<String> _recommendationSteps(String exerciseId) => switch (exerciseId) {
  'REC-QUALITY-01' => const <String>[
    '保持固定麦距并避开伴奏外放。',
    '输入过低时靠近麦克风；削波时降低音量或稍微远离。',
    '重录后只在质量门槛通过时查看技巧观察。',
  ],
  'PITCH-MATCH-01' => const <String>[
    '选择舒适音区，以舒适音量模唱一个目标音。',
    '先看轨迹完成短组练习，每轮只关注音高偏差。',
    '组末隐藏轨迹再唱一次，用于检查是否能独立复现。',
    '出现疼痛、明显不适或呼吸困难时立即停止。',
  ],
  _ => const <String>[],
};

String _reviewStatusLabel(ContentReviewStatus status) => switch (status) {
  ContentReviewStatus.draft => '草案 / 未审核',
  ContentReviewStatus.reviewed => '已复核',
  ContentReviewStatus.approved => '已批准',
};

String _evidenceGradeLabel(RecommendationEvidenceGrade grade) =>
    switch (grade) {
      RecommendationEvidenceGrade.guideline => 'G（指南/测量协议）',
      RecommendationEvidenceGrade.systematicReview => 'SR（系统/范围综述）',
      RecommendationEvidenceGrade.controlledTrial => 'CT（随机/对照研究）',
      RecommendationEvidenceGrade.measurementStudy => 'P（测量研究）',
      RecommendationEvidenceGrade.pedagogyConsensus => 'PED（正规教学共识）',
      RecommendationEvidenceGrade.unvalidated => 'U（尚未验证）',
    };

String _scopeLabel(ObservationScope scope) => switch (scope) {
  ObservationScope.frame => '单帧',
  ObservationScope.segment => '片段',
  ObservationScope.session => '会话',
  ObservationScope.trend => '趋势',
};

String _basisLabel(EvidenceBasis basis) => switch (basis) {
  EvidenceBasis.absoluteThreshold => '技术阈值',
  EvidenceBasis.personalBaseline => '个人基线',
  EvidenceBasis.compatibleHistory => '同任务历史',
};

String _evidenceLabel(Evidence evidence) {
  final label = switch (evidence.metric) {
    'target_hit_rate' => '目标命中率',
    'target_tolerance_cents' => '目标容差',
    'target_deviation_median_cents' => '目标音高中位偏差',
    'pitch_mad_cents' => '音高 MAD',
    'pitch_variation_threshold_cents' => '音高波动门槛',
    'pitch_slope_cents_per_second' => '音高漂移',
    'pitch_drift_threshold_cents_per_second' => '音高漂移门槛',
    'level_mad_db' => '音量 MAD',
    'level_variation_threshold_db' => '音量波动门槛',
    'level_slope_db_per_second' => '音量漂移',
    'level_drift_threshold_db_per_second' => '音量漂移门槛',
    'onset_delay_samples' => '稳定音高形成时间',
    'onset_delay_threshold_samples' => '起音时间门槛',
    'valid_frame_count' => '有效帧数',
    'valid_frame_ratio' => '有效帧比例',
    _ => evidence.metric,
  };
  final isRatio =
      evidence.metric.contains('rate') || evidence.metric.contains('ratio');
  final value = isRatio
      ? '${(evidence.value * 100).toStringAsFixed(0)}%'
      : evidence.value.toStringAsFixed(1);
  return '$label $value${_evidenceUnit(evidence.metric)}（${_basisLabel(evidence.basis)}）';
}

String _evidenceUnit(String metric) {
  if (metric.contains('cents_per_second')) return ' cents/秒';
  if (metric.contains('cents')) return ' cents';
  if (metric.contains('db_per_second')) return ' dB/秒';
  if (metric.contains('_db')) return ' dB';
  if (metric.contains('samples')) return ' samples';
  return '';
}

String _signedValue(double value, int fractionDigits) =>
    '${value >= 0 ? '+' : ''}${value.toStringAsFixed(fractionDigits)}';

String _qualityLabel(AnalysisQualityFlag flag) => switch (flag) {
  AnalysisQualityFlag.clipping => '检测到削波：请降低输入音量或远离麦克风。',
  AnalysisQualityFlag.inputTooLow => '输入偏低：请靠近麦克风并保持环境安静。',
  AnalysisQualityFlag.discontinuity => '采集有间断：稳定度不作解释。',
  AnalysisQualityFlag.droppedSamples => '部分音频未及时分析：稳定度不作解释。',
  AnalysisQualityFlag.processingAdjusted => '采集格式已调整。',
  AnalysisQualityFlag.insufficientValidFrames => '有效信号不足：请保持稳定发声。',
};
