# 发声方式、声区与音色多维框架

状态：R&D contract / 未经声乐教师、嗓音科学与言语治疗联合复核，不得用于自动识别唱法。

日期：2026-08-26

## 1. 结论

“假声、头声、胸声、混声、强混、弱混、金属性”不能放在一个从“闭合少”到“闭合多”的单轴上，也不能由消费级麦克风输出一个确定类别。

产品应同时保留四层信息，且不得互相偷换：

1. **任务意图**：歌手或教师要求探索的标签，例如“弱混”“强混”“头声感”“更有金属性”。
2. **听感标注**：歌手自评、教师标注或盲听小组对音色的判断；它是感知数据，不是喉部真值。
3. **声学输出**：F0、相对电平、周期性、谐波平衡、频谱倾斜/质心、共振相关谱峰、动态和时间变化。
4. **实验室生理/气动证据**：EGG、high-speed videoendoscopy、EMG、airflow 和 subglottal pressure。只有这些对应模态才能支持接触、振动形态、肌肉活动或气动描述。

当前产品可以安全实现前 3 层的记录、比较和置信度框架；第 4 层只用于研究数据合同。任何自动“检测到头声/混声/金属声”的规则都保持禁止。

## 2. 术语为何不能直接当类别

### 2.1 喉部机制与教学名称不是一一对应

Roubeau、Henrich 与 Castellengo 从 EGG transition 研究提出 M0–M3 laryngeal vibratory mechanisms；M1/M2 是歌唱最常讨论的两个主要机制，但机制范围有重叠，单凭音高不能确定机制。[Roubeau et al. 2009](https://doi.org/10.1016/j.jvoice.2007.10.014)；[Henrich 2006 review](https://doi.org/10.1080/14015430500432417)

`chest/head/falsetto/mix` 同时包含听感、身体意象、声源行为、声道调整、音区和风格传统。NATS 的音乐剧资源也把 registration 描述为 phonation 与 resonance 的交互，并承认 chest、middle/mixed、head、belt 等多套术语并存；它是教学资源，不是统一生理分类标准。[NATS music-theatre registration resource](https://www.nats.org/Music_Theater_-_Resources.html)

因此：

- `M0/M1/M2/M3` 只在有相应实验室证据时作为 mechanism annotation；
- “假声/头声/混声/强混/弱混”作为指定教学体系内的任务标签；
- 不把“男头声”“女头声”或某个固定音高自动映射到 M1/M2；
- 不按生理性别或声部给个人设固定 passaggio。

### 2.2 “混声”研究本身是多模型、任务相关的

现有结果不能支持一个跨歌手、跨教学体系的统一 mix classifier：

- 五名专业歌手的 `voix mixte` 研究报告，听感上的混声可在 M1 或 M2 内产生，并通过强度和频谱/共振调整让两个机制的音色接近，而不是一个单独的“中间机制”。[Castellengo, Chuberre & Henrich 2004](https://www.lam.jussieu.fr/Membres/Castellengo/publications/2004d-Voix%20mixte-ISMA.pdf)
- 七名女歌手在 `chest → chestmix → headmix → head` 的同音高任务中显示 spectral tilt、TA activity 和 vocal-process adduction 的组内梯度；样本小、仅女性、标签依赖该研究训练和判断协议。[Kochis-Jennings et al. 2012](https://doi.org/10.1016/j.jvoice.2010.11.002)
- 另一项 12 名歌手的气动研究（其中 HSDI/EGG 仅 3 名）报告 mix 在若干参数上介于 chest/falsetto 之间并有不同轮廓；这与前述 mechanism 内调整的解释不完全相同，说明任务、定义和测量方式决定结论。[Lee et al. 2023](https://doi.org/10.1016/j.jvoice.2020.12.028)
- 10 名受训歌手的探索性研究显示 M1/M2 可及音高范围比传统高低区划分更重叠；CQ 在该协议下有区分力，但仍受 pitch、sex、任务和个体影响。[Register accessibility study](https://doi.org/10.1016/j.jvoice.2025.12.001)

产品含义：`strong_mix` 与 `weak_mix` 只能表示用户/教师在一个明确协议中的目标和听感端点。它们不能被解释为固定 TA/CT 比例、固定闭合程度、固定 M1/M2 或“正确程度”。

### 2.3 “金属性”首先是听感构念

CVT 使用的 `metal` 与 `density` 是 auditory-perceptual concepts。2026 年 double-case study 在两名 CVT 歌手上观察到 metallic condition 与 SPL、subglottal pressure、glottal resistance、CQ、harmonic richness 等多项差异，但作者明确要求更大样本；结果也不能脱离该体系和任务外推。[Leppävuori et al. 2026](https://doi.org/10.1159/000550742)

谱质心可与“brightness”相关，但 timbre 是多维的；元音 formants、F0、声源倾斜、湍流噪声、麦克风和房间都能改变质心或高频能量。[Multidimensional singing timbre study](https://pmc.ncbi.nlm.nih.gov/articles/PMC7179674/)；[source/filter limitation example](https://pmc.ncbi.nlm.nih.gov/articles/PMC7592904/)

产品含义：UI 可以显示“本次输出的高低频能量平衡与同任务基线不同”，并保存人工 `metallic` 听感标注；不能显示“检测到金属腔/咽部收窄/twang/假声带动作”。

## 3. 多维指标体系

所有指标先经过既有 capture/quality gate。消费麦克风只描述 radiated acoustic output；未校准设备上的 level 只能用 dBFS 和同设备相对变化。

| 维度 | 可测量项 | 最低任务约束 | 消费麦克风允许输出 | 不允许推出 |
|---|---|---|---|---|
| Pitch / register event | F0、pitch range、glide continuity、可听 transition candidate | 同方向 glide、明确 onset/offset、voicing 高置信 | “在该滑音的此处出现 F0/音色突变候选” | M1/M2、passaggio 生理位置、机制切换原因 |
| Intensity / dynamics | RMS/peak dBFS、relative contour；实验室 calibrated SPL | 同设备、增益、距离、元音和目标响度 | 相对电平与动态轮廓 | subglottal pressure、effort、闭合、肺活量 |
| Periodicity | clarity、voiced ratio；未来 CPP/CPPS | 稳态、连续、排除伴奏/分离 artifact | 周期性较本人的同任务基线高/低 | 气声、漏气、病变、闭合不足 |
| Harmonic balance | H1–H2/H1–A3 候选、alpha ratio、spectral tilt、harmonic richness | 同 F0、元音、响度；未来 inverse-filter/oracle 验证 | radiated spectrum 的相对变化 | glottal open/contact quotient、TA/CT activity |
| Spectral distribution | centroid、roll-off、固定 bands、2–4 kHz relative energy | 同 F0/元音/设备/距离；高 F0 时标记 harmonic sparsity | 输出频谱更亮/暗或高频相对更多/更少 | twang、singer's formant、喉位、声道形状、metal 类别 |
| Resonance/filter | F1/F2 或谱峰候选、harmonic-resonance alignment | 稳态元音；高 F0 时降低 formant confidence | 可比元音中的谱峰/谐波强化差异 | 咽腔/口腔几何、共鸣位置、唯一正确元音策略 |
| Temporal modulation | onset、offset、vibrato rate/extent、transition duration | 标注 intentional vibrato/glide；足够长连续段 | 时间变化和重复性 | 生理异常、疲劳、控制能力总分 |
| Perceptual | chest-like/head-like、breathy/clear、bright/dark、metallic、strong/weak mix rating | 随机化音频、盲听、统一词表和 reference anchors | 标注者与一致度 | 生理机制或健康状态 |
| Self-report | effort、comfort、location imagery、pain/discomfort | 每 take 后即时记录，不由音频代填 | “你本次自报……” | 客观组织负荷、损伤风险 |
| Contact/kinematics | EGG CQ/OQ candidate、dEGG、HSDI glottal area/wave | 电极/成像质量和方法版本 | 仅研究 UI，标明 modality | 消费麦克风不可生成；EGG 也不等于 airflow/完整 glottal area |
| Muscle/aerodynamics | TA/CT EMG、airflow、Psub、glottal resistance | 专业实验室与伦理/同意 | 不进入消费产品 | 不由 audio/EGG 反推 |

EGG 仍不是“闭合真值”：接触商依赖算法、电极、喉位与个体，且 EGG 不提供完整 glottal area 或 airflow。[EGG variability study](https://pmc.ncbi.nlm.nih.gov/articles/PMC6966776/)；声学谐波、OQ 与听感之间的关系也会显著跨个体变化。[Mehta et al. 2012](https://pmc.ncbi.nlm.nih.gov/articles/PMC3477193/)

## 4. 任务协议

协议版本必须随结果保存。以下重复数是产品研究的初始可重复性设计，不是生理规范或通过阈值。

### `VP-CAL-01` 采集与舒适范围

1. 记录 effective format、processing flags、设备类别、麦距条件和环境噪声。
2. 只询问用户舒适中区和当次不适；不由声部/性别计算范围。
3. 用舒适元音和中等自选响度做 3 次短持续音，建立本次 noise/level/periodicity 参考。
4. 任意疼痛、明显不适或呼吸困难立即停止，不继续做 register 探索。

### `VP-REG-01` 同音高/元音发声对比

1. 在用户舒适且多个任务标签都可完成的重叠音区选 2–3 个音高。
2. 固定一个 IPA 元音、音高、时长和响度条件；每个目标标签至少 3 个有效 take，顺序随机。
3. 标签由歌手意图或教师 prompt 给出，例如 `falsetto`、`head_voice`、`strong_mix`、`weak_mix`；产品不得补写 mechanism。
4. 比较 F0、relative level、periodicity、harmonic balance、spectral distribution 和 repeatability；不同响度的 take 不直接归因于 register。
5. 研究版可同步 EGG/HSDI/EMG/airflow，但每种证据单独存 modality 和 confidence。

### `VP-GLIDE-01` 上/下行转换

1. 固定元音，在舒适范围做慢上行和慢下行 glide，各至少 3 次。
2. 标记意图为“保持同一听感”“允许切换”或“尽量平滑”，避免把所有变化都当错误。
3. 音频只产出 transition candidates：F0 jump、periodicity dip、spectral-change point 和 listener-audible event。
4. 上行/下行分开总结；不把二者的 transition pitch 合成单一 passaggio。
5. 只有同步 EGG/HSDI 等研究模态才能添加 mechanism-level annotation。

### `VP-MIX-01` 混声连续体

1. 先保存该教师/课程对“强混/弱混/chestmix/headmix”的文本定义和 audio anchors，禁止全局词义映射。
2. 在同 pitch/vowel/loudness cell 中做端点与中间目标；若响度本身是目标维度，另建 loudness cell。
3. 保存 singer intent、teacher prompt、blinded listener rating 三条独立标签流；不同意时不投票成“生理真值”。
4. UI 显示各声学维度相对变化和重复性，不显示一条从弱到强的“闭合表”。

### `VP-METAL-01` 金属性/明亮度对比

1. 词表必须绑定具体教学体系和 reference anchors；`metallic`、`bright`、`ring`、`twang` 不自动互译。
2. 同 pitch/vowel/loudness 做 nonmetallic/metallic intention 对比并随机回放给盲听标注者。
3. 输出 relative centroid、bands、alpha ratio/tilt 候选、periodicity、level 和 listener agreement。
4. 不从这些轴推断 epilaryngeal narrowing、false-fold adduction、vocal economy 或安全性。

### `VP-STYLE-01` 短句风格任务

1. 用同一短句、调性、速度和可比动态探索不同风格目标。
2. phrase-level pitch/timing/dynamic/timbre 分开显示；原唱或教师 sample 只是一个 reference。
3. 字词、元音、辅音或表现处理不同的窗口不得进入 register/timbre baseline。

## 5. 标注合同

每个 take 可以有零到多个人工标签，但每条必须保存：

- `label_key`：原词表 key，例如 `head_voice`、`falsetto`、`strong_mix`、`weak_mix`、`metallic`；
- `pedagogy_vocabulary_id/version`：该词来自哪个课程/教师体系；
- `source`：`singer_intent`、`teacher_prompt` 或 `blinded_listener_consensus`；
- `confidence/agreement`：自评把握或盲听一致度，不称 classifier probability；
- `reference_anchor_id?`：若任务使用 reference，记录哪一段合法 reference；
- `limitations`：响度未匹配、元音改变、样本不足等。

实验室的 `M0/M1/M2/M3` annotation 另建 mechanism evidence，不复用 pedagogical label 字段。它必须包含测量模态、仪器/算法版本、研究人员和不确定性。

## 6. 个体基线与可比性

### 6.1 Comparison key

只有以下字段全部兼容才直接比较：

```text
protocol version
+ task kind
+ pitch context
+ IPA vowel / phrase window
+ loudness condition
+ style context
+ capture profile（设备类别、距离、processing flags）
+ algorithm version
+ pedagogical vocabulary/target label（若比较某个标签）
```

当前 domain 的 `VoiceProductionScope.isComparableWith` 采取 exact match，宁可减少比较，也不把元音、响度或设备差异包装成唱法变化。

### 6.2 Baseline formation

- 每个 task cell 先取得至少 3 个有效 take，用 median、MAD/IQR 和 take-to-take spread 描述本次重复性。
- 延续蓝图：至少 5 次兼容、质量合格的 session 后才形成个人历史基线。
- 算法版本、设备处理、麦距、任务 prompt 或词表改变时新建 baseline generation。
- 不建立“正常混声”“正常闭合”“男性/女性 passaggio”人口硬阈值。
- 显著偏离只描述“与自己的兼容历史不同”，不自动判断退步、疲劳或损伤。

## 7. Confidence 与 suppression

`VoiceProductionConfidence` 保留四个可审计分量：

1. `signalQuality`：format、clipping、noise、drop、voicing、伴奏/分离 artifact；
2. `taskMatch`：pitch、元音、响度、phrase、style prompt 是否匹配；
3. `repeatability`：同 cell 的多 take 是否复现；
4. `labelAgreement?`：存在多位盲听标注者时的一致度。

保守分数取可用分量的最小值，只表示证据可用性，不表示“有 80% 概率是混声”。

Suppression 优先级：

1. capture/quality fail → 不做唱法或音色解释；
2. task/context mismatch → 不进入 baseline comparison；
3. take 不可重复 → 展示各 take，不汇总成标签轮廓；
4. 人工标签分歧 → 显示分歧与回放，不让算法裁决；
5. consumer-mic only → physiology fields unavailable，而不是估算填充。

## 8. UI 建议

### 8.1 任务前

- 文案写“本轮目标：你/教师标注的‘弱混’”，不写“系统将检测弱混”。
- 点开术语显示它所属的课程词表、reference anchor 和“不同体系含义可能不同”。
- 让用户选择舒适音高/元音/响度；默认不按声部或性别设 passaggio。

### 8.2 结果页

用独立行或小卡展示维度，不压成总分或雷达面积：

- pitch/transition；
- relative level/dynamics；
- periodicity/valid data；
- harmonic/spectral balance；
- perceptual labels and agreement；
- self-reported comfort/effort；
- lab-only physiology（没有仪器时显示“未测量”，不显示灰色估计值）。

每项显示 `本次 → 同任务个人基线/指定 reference`、confidence components、quality flags 和 A/B 回放。允许用户纠正自己的意图标签，但不允许把一次纠正写成模型真值。

推荐文案示例上限：

- “在相同音高、元音和响度条件下，这次你标为‘强混’的片段比‘弱混’片段有更多 2–4 kHz 相对能量；该差异也可能来自元音或麦距。”
- “三次 take 的结果差异较大，暂不形成个人轮廓。”
- “这里记录的是听感标签和声学输出；本设备没有测量声带接触或喉部动作。”

禁止：

- “闭合 72%”“TA 60% / CT 40%”；
- “已识别强混/头声/假声”；
- “金属感不足说明咽腔没收窄”；
- “你的换声点是 E4”；
- “这是更健康/正确的唱法”。

## 9. Domain schema 边界

`voice_production_profile.dart` 只提供研究/未来产品可复用的值对象：

- `PedagogicalVoiceLabel` 保存词表 ID/version、human source、可选 reference anchor 与 limitations；没有 algorithm classifier；
- `VoiceProductionMeasurement` 将 metric、domain、unit、modality、sample window 和 confidence 绑定；
- physiology domain 必须携带匹配的 EGG/HSDI/EMG/airflow/pressure modality；consumer microphone alone 会被构造器拒绝；
- `VoiceProductionScope` 固定 comparison cell；
- `VoiceProductionConfidence` 提供透明的保守证据分数；
- `VoiceProductionProfile` 将标签与测量分开保存。

本 schema 不进入 Drift，不新增 DSP 指标，不更改 Observation rules，也不解锁自动 register/style feedback。

## 10. 验证路线

1. **词表研究**：至少两种教学体系的教师分别定义/示范 labels；报告跨体系 mapping failure，而不是强制统一。
2. **标注 pilot**：合法授权样本、歌手自评 + 教师 + 盲听小组；报告 within/between-rater agreement 和 unclear rate。
3. **任务可靠性**：同日/跨日重复，按 pitch/vowel/loudness/style/device 分层；预注册 primary measurements。
4. **实验室子样本**：同步 EGG/HSDI，必要时 EMG/aerodynamics；验证哪些 acoustic profiles 在何种任务下可重复相关。
5. **设备鲁棒性**：手机/USB/房间/距离/AGC 分层；比较 false observation 与 suppression rate。
6. **只做 descriptive prototype**：在专家签核、外部验证和 error analysis 前，不训练或发布 head/mix/metal classifier。

## 11. 核心来源索引

| ID | 类型 | 支持内容 | 限制 |
|---|---|---|---|
| `ROUBEAU_2009` | Review + EGG studies | M0–M3 与机制 overlap | 不是消费 audio classifier |
| `HENRICH_2006` | Historical/scientific review | register 术语混乱与观测层次 | 不定义教学唯一词表 |
| `CASTELLENGO_2004` | Primary conference study | voix mixte 可在 M1/M2 内产生 | 5 名专业歌手、特定西方古典技术 |
| `KOCHIS_JENNINGS_2012` | Primary multimodal | chest/chestmix/headmix/head 的组内多维差异 | 7 名女性、特定 labels/tasks |
| `LEE_2023` | Primary multimodal | chest/mix/falsetto 的气动、HSDI/EGG/声学轮廓 | 子测量样本仅 3–12 人 |
| `HERBST_2017_PASSAGGIO` | Primary HSDI/EGG | passaggio 可有平滑、突变和接触丢失等多种策略 | 10 名古典女高音；[full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC5414960/) |
| `REGISTER_ACCESS_2025` | Exploratory EGG | M1/M2 音高可及范围重叠、CQ task effect | 10 名受训歌手 |
| `METAL_DENSITY_2026` | Double-case multimodal | CVT metal/density 为多参数听感构念 | 仅 2 人，不足以分类 |
| `MEHTA_2012` | Primary multimodal | harmonic/OQ/voice-quality relation 跨人变化 | sustained phonation/lab |
| `NATS_REGISTER_RESOURCE` | PED | 教学术语与 source/filter 区分 | 教学资源，不是临床/机制共识 |
| `SMARTPHONE_META_2025` | Systematic review/meta-analysis | 消费设备与临床录音不等价 | 设备/指标异质；[PubMed](https://pubmed.ncbi.nlm.nih.gov/41037430/) |
