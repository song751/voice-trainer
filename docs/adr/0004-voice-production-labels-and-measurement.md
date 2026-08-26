# ADR 0004：发声标签与多维测量分离

- 状态：Provisional / R&D only
- 日期：2026-08-26
- 详细依据：`docs/REGISTER_AND_TIMBRE_FRAMEWORK.md`

## 背景

用户需要覆盖假声、头声、混声（强混/弱混）和金属性等发声方式。现有证据显示这些词跨教学体系含义不稳定；mix 研究对其是否是 M1/M2 内调整或独立多参数轮廓也存在任务和小样本差异。消费级麦克风只能观测 radiated acoustic output，不能直接测声带接触、肌肉活动、声门下压或声道几何。

## 决策

1. 发声建模采用 `task context + human label provenance + multidimensional measurements + confidence + limitations`，不采用闭合单轴。
2. `falsetto/head/chest/mix/strong_mix/weak_mix/metallic` 是 pedagogical/perceptual labels，不是 algorithm outputs。
3. 声学、听感、自报、EGG/HSDI、EMG 和气动数据分开记录 modality；消费麦克风证据不能构造 physiology-domain measurement。
4. 比较只在 pitch、元音、响度、风格、设备/距离、处理设置、协议和算法版本兼容时发生；默认使用个人基线，不设人群“正确唱法”阈值。
5. confidence 表示 signal/task/repeatability/label agreement 的证据质量，不表示某唱法类别的概率。
6. 当前只加入平台无关 domain 值对象和 tests；不改 DSP、Drift、Observation rules 或 UI，不训练/发布自动唱法分类器。

## 后果

- UI 必须写“你/教师标注的目标”和“测得的声学差异”，不能写“系统识别到混声/金属声”。
- future lab data 可进入同一 profile，但必须保留其独立 modality 与研究协议。
- 若未来提出 classifier，必须另立任务卡，提供授权分层数据、跨标注者定义、外部验证、设备鲁棒性、校准与 suppression/error analysis；在此前不存在 production classifier 字段。
