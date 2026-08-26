# ADR 0003：歌唱反馈的证据与安全边界

- 状态：Provisional / R&D only
- 日期：2026-08-26
- 详细依据：`docs/SINGING_PEDAGOGY_EVIDENCE_MAP.md`

## 背景

当前产品已有 pitch、level、periodicity、quality flags、onset 与 spectrum 等描述性测量。歌曲分离又会产生一个可对比的原唱 reference。若把这些数值直接翻译成“挤压、漏气、闭合、喉位、疲劳”等机制或健康判断，会越过消费麦克风和现有证据的能力边界。

## 决策

1. 输出模型固定为 `measurement evidence → Observation → reviewed exercise`，不允许 `metric → Diagnosis`。
2. 每条推荐必须有 confidence、quality flags、scope、content ID/version/review status、evidence grade/source 和 limitations。
3. pitch visual feedback 可作为第一个受控教学模块；SOVT 只作为经人工复核的一般候选，不由声学阈值自动触发为治疗。
4. timing、level、range、spectrum 和 reference A/B 的练习在产品验证前标为 `U/PED`；不宣传科学疗效。
5. 分离后的歌手 stem 是一个艺术参考，不是唯一正确答案；仅比较双方都高置信且 key/tempo 已对齐的窗口。
6. 疼痛或严重警示症状提示停止并联系合格专业人员；持续 dysphonia/hoarseness 未在 4 周改善时提示喉科/耳鼻喉评估。应用不从音频判断这些症状。
7. 所有新内容默认 `unreviewed`，不能标为 expert-approved；临床 voice therapy 不得由本产品自行处方。

## 后果

- 建议系统需要可审计 content catalog 和 suppression-first rule engine，而不是更多固定阈值。
- 首批课程应先验证音高视觉反馈和 retention，再逐项验证其他练习。
- 任何“唱功总分”、生理机制标签、病理筛查或嗓音治疗功能都需要新的明确授权、临床合作与独立验证。
- 本 ADR 不修改当前 UI、DSP、数据库或 P4 composition，也不解锁新的 Phase 卡。
