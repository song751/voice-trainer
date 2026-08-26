import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/domain/analysis/voice_comparison.dart';
import '../../../core/domain/analysis/voice_production_profile.dart';
import '../../../core/widgets/responsive_page_body.dart';
import '../application/voice_comparison_controller.dart';
import 'voice_comparison_evidence_card.dart';

class VoiceComparisonPage extends ConsumerWidget {
  const VoiceComparisonPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(voiceComparisonControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('发声对比练习')),
      body: ResponsivePageBody(
        child: ListView(
          key: const Key('voice-comparison-scroll'),
          children: <Widget>[
            const Text('设置匹配条件后，分别录制 A/B；两侧也可以选择同一标签来观察重复样本。'),
            const SizedBox(height: 8),
            const Text('这些名称来自你或教师的词表，系统不会从录音自动判定胸声、头声、假声、混声或金属性。'),
            const SizedBox(height: 8),
            const Text(
              '研究说明：即使音高相同，相关研究仍需声学、EGG、成像和气动等多种模态；麦克风只能显示受元音、响度、设备与环境影响的声学差异。NATS、Estill、CVT 或教师词汇仅作来源记录，不自动互译，也不代表专家批准。',
              key: Key('voice-comparison-research-boundary'),
            ),
            const SizedBox(height: 16),
            plan.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text('保存的对比设置暂时无法读取。'),
              data: (value) => _ComparisonForm(
                key: ValueKey(value?.id ?? 'new-comparison'),
                initialPlan: value,
              ),
            ),
            if (plan.valueOrNull case final savedPlan?) ...<Widget>[
              const SizedBox(height: 16),
              VoiceComparisonEvidenceCard(plan: savedPlan),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComparisonForm extends ConsumerStatefulWidget {
  const _ComparisonForm({required this.initialPlan, super.key});

  final VoiceComparisonPlan? initialPlan;

  @override
  ConsumerState<_ComparisonForm> createState() => _ComparisonFormState();
}

class _ComparisonFormState extends ConsumerState<_ComparisonForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _vocabularyId;
  late final TextEditingController _vocabularyVersion;
  late VoiceIntentKey _labelA;
  late VoiceIntentKey _labelB;
  late PedagogicalLabelSource _source;
  late String _protocol;
  late String _pitch;
  late String _vowel;
  late String _loudness;
  late String _style;
  late String _capture;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.initialPlan;
    _vocabularyId = TextEditingController(
      text: plan?.labelA.vocabularyId ?? 'personal-voice-vocabulary',
    );
    _vocabularyVersion = TextEditingController(
      text: plan?.labelA.vocabularyVersion ?? '1',
    );
    _labelA = _intent(plan?.labelA.labelKey) ?? VoiceIntentKey.neutral;
    _labelB = _intent(plan?.labelB.labelKey) ?? VoiceIntentKey.headVoice;
    _source = plan?.labelA.source ?? PedagogicalLabelSource.singerIntent;
    _protocol = plan?.scope.protocolId ?? 'VP-REG-01@1';
    _pitch = plan?.scope.pitchContextKey ?? 'A3';
    _vowel = plan?.scope.vowelIpa ?? 'a';
    _loudness = plan?.scope.loudnessConditionKey ?? 'medium';
    _style = plan?.scope.styleContextKey ?? 'neutral';
    _capture = plan?.scope.captureProfileKey ?? 'same-device-15cm';
    _vocabularyId.addListener(_markDirty);
    _vocabularyVersion.addListener(_markDirty);
  }

  @override
  void dispose() {
    _vocabularyId.dispose();
    _vocabularyVersion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSavedPlan = widget.initialPlan != null;
    return Semantics(
      container: true,
      label: '发声对比练习设置',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('意图标签与来源', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _dropdown<VoiceIntentKey>(
                  key: const Key('voice-label-a'),
                  label: 'A 意图标签',
                  value: _labelA,
                  values: VoiceIntentKey.values,
                  itemLabel: (value) => voiceIntentLabel(value.name),
                  onChanged: (value) => _change(() => _labelA = value),
                ),
                const SizedBox(height: 12),
                _dropdown<VoiceIntentKey>(
                  key: const Key('voice-label-b'),
                  label: 'B 意图标签',
                  value: _labelB,
                  values: VoiceIntentKey.values,
                  itemLabel: (value) => voiceIntentLabel(value.name),
                  onChanged: (value) => _change(() => _labelB = value),
                ),
                const SizedBox(height: 12),
                _dropdown<PedagogicalLabelSource>(
                  key: const Key('voice-label-source'),
                  label: '标签来源',
                  value: _source,
                  values: const <PedagogicalLabelSource>[
                    PedagogicalLabelSource.singerIntent,
                    PedagogicalLabelSource.teacherPrompt,
                  ],
                  itemLabel: labelSourceLabel,
                  onChanged: (value) => _change(() => _source = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('voice-vocabulary-id'),
                  controller: _vocabularyId,
                  decoration: const InputDecoration(
                    labelText: '词表 ID / 教师体系',
                    helperText: '例如 personal、NATS、Estill、CVT 或教师自定义；含义不跨体系自动映射',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('voice-vocabulary-version'),
                  controller: _vocabularyVersion,
                  decoration: const InputDecoration(labelText: '词表版本'),
                  validator: _required,
                ),
                const SizedBox(height: 20),
                Text(
                  '必须匹配的练习条件',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text('改变任一条件会新建对比组；设备/麦距条件由用户保持，应用不读取硬件唯一标识。'),
                const SizedBox(height: 12),
                _stringDropdown('协议版本', _protocol, const {
                  'VP-REG-01@1': '同音高/元音发声对比',
                  'VP-MIX-01@1': '混声连续体',
                  'VP-METAL-01@1': '金属性/明亮度对比',
                }, (value) => _protocol = value),
                const SizedBox(height: 12),
                _stringDropdown('目标音高', _pitch, const {
                  'A3': 'A3',
                  'C4': 'C4',
                  'E4': 'E4',
                }, (value) => _pitch = value),
                const SizedBox(height: 12),
                _stringDropdown('IPA 元音', _vowel, const {
                  'a': '/a/',
                  'i': '/i/',
                  'u': '/u/',
                }, (value) => _vowel = value),
                const SizedBox(height: 12),
                _stringDropdown('目标响度', _loudness, const {
                  'soft': '轻',
                  'medium': '中等',
                  'strong': '较强但舒适',
                }, (value) => _loudness = value),
                const SizedBox(height: 12),
                _stringDropdown('风格上下文', _style, const {
                  'neutral': '中性练习',
                  'pop': '流行',
                  'musical-theatre': '音乐剧',
                  'classical': '古典',
                }, (value) => _style = value),
                const SizedBox(height: 12),
                _stringDropdown('采集条件', _capture, const {
                  'same-device-15cm': '同一设备 · 约 15 cm · 固定处理设置',
                  'same-device-30cm': '同一设备 · 约 30 cm · 固定处理设置',
                }, (value) => _capture = value),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('save-voice-comparison'),
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存为新的对比组'),
                ),
                if (hasSavedPlan) ...<Widget>[
                  const SizedBox(height: 12),
                  if (_dirty)
                    const Text(
                      '设置已修改；保存为新的对比组后才能继续录制。',
                      key: Key('voice-comparison-dirty'),
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      OutlinedButton.icon(
                        key: const Key('record-voice-a'),
                        onPressed: _dirty
                            ? null
                            : () => _record(VoiceComparisonSide.a),
                        icon: const Icon(Icons.mic_none),
                        label: Text('录制 A · ${voiceIntentLabel(_labelA.name)}'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('record-voice-b'),
                        onPressed: _dirty
                            ? null
                            : () => _record(VoiceComparisonSide.b),
                        icon: const Icon(Icons.mic_none),
                        label: Text('录制 B · ${voiceIntentLabel(_labelB.name)}'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  DropdownButtonFormField<T> _dropdown<T>({
    required Key key,
    required String label,
    required T value,
    required List<T> values,
    required String Function(T) itemLabel,
    required ValueChanged<T> onChanged,
  }) => DropdownButtonFormField<T>(
    key: key,
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: values
        .map(
          (item) =>
              DropdownMenuItem<T>(value: item, child: Text(itemLabel(item))),
        )
        .toList(growable: false),
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  );

  Widget _stringDropdown(
    String label,
    String value,
    Map<String, String> values,
    ValueChanged<String> onChanged,
  ) => _dropdown<String>(
    key: ValueKey('voice-condition-$label'),
    label: label,
    value: value,
    values: values.keys.toList(growable: false),
    itemLabel: (item) => values[item]!,
    onChanged: (next) => _change(() => onChanged(next)),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? '此项不能为空' : null;

  void _change(VoidCallback update) {
    setState(() {
      update();
      _dirty = true;
    });
  }

  void _markDirty() {
    if (mounted && !_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(voiceComparisonControllerProvider.notifier)
        .save(
          VoiceComparisonDraft(
            labelA: _labelA,
            labelB: _labelB,
            vocabularyId: _vocabularyId.text,
            vocabularyVersion: _vocabularyVersion.text,
            source: _source,
            protocolId: _protocol,
            pitchContextKey: _pitch,
            vowelIpa: _vowel,
            loudnessConditionKey: _loudness,
            styleContextKey: _style,
            captureProfileKey: _capture,
          ),
        );
  }

  void _record(VoiceComparisonSide side) {
    ref.read(voiceComparisonControllerProvider.notifier).prepareTake(side);
    context.go(RoutePaths.livePractice);
  }

  VoiceIntentKey? _intent(String? key) {
    if (key == null) return null;
    return VoiceIntentKey.values
        .where((value) => value.name == key)
        .firstOrNull;
  }
}
