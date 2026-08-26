# 歌唱反馈与课程证据地图

状态：R&D draft / 未经声乐教师、嗓音医学与言语治疗联合复核，不得标为 expert-approved。

日期：2026-08-26

## 1. 产品边界

本文件把当前可测物理量变成“可解释的观察”，再把观察映射到低风险练习。它不是诊断规则，也不把一个声学相关量解释为声带状态、病因或唯一正确唱法。

每条产品输出必须同时携带：

- `observation_id` 与实际数值/窗口；
- `confidence` 和形成该置信度的 signal-quality flags；
- `scope`（本次设备、曲目、音区、元音、响度与任务）；
- `exercise_content_id`、`content_version` 与 `review_status`；
- `evidence_grade`、来源 ID 与已知限制；
- 没有足够质量时只给重录建议，不给技巧解释。

证据等级不是推荐强度：

| 等级 | 含义 | 产品权限 |
|---|---|---|
| `G` | 专业协会指南/专家测量协议 | 可固定安全边界或测量合同，仍不能替代临床检查 |
| `SR` | 系统综述或范围综述 | 可支持课程方向；异质性和人群差异必须显示 |
| `CT` | 随机/对照试验 | 可支持与试验相近人群和任务的练习，不外推为治疗 |
| `P` | 单项观察、机制或测量研究 | 只生成描述性反馈或产品假设 |
| `PED` | 正规专业课程/教学共识 | 可用于内容结构，不声称疗效已验证 |
| `U` | 尚未验证的产品假设 | 只允许内部实验，不向用户推荐 |

## 2. 指标 → 观察 → 练习映射

表中的“允许输出”是文案上限，不是文案例句库。所有跨 session 趋势应优先与用户自己的同设备基线比较，而不是套用“正常人阈值”。

| 数据与最低质量条件 | 允许的 Observation | 可推荐练习 | 证据与限制 | 明确禁止 |
|---|---|---|---|---|
| clipping 比例、RMS、drop/discontinuity；格式已确认 | “本段削波/输入过低/数据不连续，无法可靠比较” | `REC-QUALITY-01`：固定麦距、避开伴奏外放、调低输入后重录 | `G/P`；测量首先受采集合同影响 | 不把低电平说成气息不足；不把削波说成用力过度 |
| 双方高置信 voiced frame；target note/转调已知；排除过渡窗 | signed cents 中位数、absolute cents P50/P95、有效帧命中率；“本段相对目标偏高/偏低” | `PITCH-MATCH-01`：舒适音区单音模唱 + 实时轨迹；`PITCH-PATTERN-02`：慢速 3–4 音级进/分解和弦，再逐步增加速度 | `CT`；成人短时随机训练支持视觉增强反馈，收益个体差异大，尤其体现在 4 音旋律；不同速度、连/断、音区会改变误差 | 不叫“音痴”；不由偏高/偏低推断喉位、张力或听觉疾病 |
| 持续音且目标标记为 straight/steady；排除 intentional vibrato、滑音和 onset/offset | detrended cents MAD、慢漂移；“稳定段波动较自己的近期基线更大” | `HOLD-STEADY-01`：舒适音高短时持续、休息、逐次复听；先减少视觉依赖再做 retention probe | `P/U`；可测但练习剂量和迁移尚未由歌唱 RCT 固定 | 不把波动称为颤音异常、疲劳、支撑差或神经问题 |
| score/reference onset 可对齐；双方 voiced confidence 足够 | onset delta、note duration ratio、phrase-level DTW offset；“进入较参考早/晚” | `RHYTHM-ENTRY-01`：先拍点/哼唱节奏，再用伴奏做短句；降低速度后逐级恢复 | `PED/U`；属于待验证产品教学假设 | 不由 onset 推断“硬起音”、声门冲击或呼吸协调障碍 |
| 同设备/增益/麦距的连续片段；无 clipping/drop | 相对 level drift、段内 dynamic contour；“后半段电平比前半段低/高” | `LEVEL-CONTOUR-01`：同一舒适短句重复并保持目标动态轮廓 | `G/P`；未校准手机/麦克风只能做相对量 | 不显示临床 SPL；不把电平变化解释成肺活量、闭合、疲劳或压迫 |
| 高置信基频与任务标签；只在可比元音/音高/响度间 | periodicity/clarity、可选 CPP 的同任务变化；低 periodicity 时直接降置信 | 无自动纠正练习；先 `REC-QUALITY-01`，必要时由已审核内容提供一般热身 | `G/SR`；CPP 是辅助量，jitter/shimmer/HNR 对任务、响度、设备敏感；手机与临床录音系统并不等价 | 不由 CPP/HNR/clarity 诊断沙哑、漏气、闭合不足、结节或病变 |
| full-band bands/centroid；同一元音、音高、设备、距离；分离 artifact 低 | 只描述“该频段相对能量/质心在本次可比片段间不同” | 暂不自动分配；留给经审核的元音/风格课程 | `P/U`；声源、声道、元音、麦克风和分离模型均可改变谱 | 不推断共鸣位置、喉位、twang、歌手共振峰、声带厚薄或声区 |
| 用户主动做舒适范围任务；每个音均高置信且无不适自报 | 本次已观察到的最低/最高可靠音、成功率；不称“最大音域” | `RANGE-GENTLE-01`：从舒适中区做小音程逐级扩展，任何不适立即停止 | `PED/U`；范围高度依赖风格、元音、当日状态和任务 | 不鼓励冲极限；不以生理性别/声部给个人硬阈值 |
| 已分离 reference vocals 与用户练唱均通过 artifact/voicing gate；已处理 key/tempo | phrase-level pitch/timing contour 差异，并提供 A/B 音频；“与这一个参考演唱不同” | `REFERENCE-AB-01`：先听 reference stem，再录短句，A/B 对比后只选一个目标重练 | `P/U`；分离模型会留残响/串音；原唱是艺术参考而非唯一正确答案 | 不给整体“唱功分”；不把音色、颤音、动态差异判为错误；不抓取流媒体 |

## 3. 练习合同

### `PITCH-MATCH-01` / `PITCH-PATTERN-02`

1. 先用用户自报舒适区选目标，不从声部标签推断范围。
2. 播放 vocal 或柔和合成参考；显示 target 与高置信 F0，不显示低置信假轨迹。
3. 一轮只反馈 signed bias、absolute error 和有效帧比例；先单音，再 3–4 音相对音程。
4. 视觉反馈用于 acquisition；每组末尾隐藏轨迹做一次 retention probe，避免只学会追线。
5. 不使用羞辱性标签，不把短时误差解释为先天能力。

依据：Berglin 等对 75 名成人的随机训练显示，20 分钟 pitch-matching 中视觉增强组的改善最可靠，优势主要出现在 4 音旋律而非所有单音任务；作者也明确报告个体差异和训练控制限制。[原始研究](https://doi.org/10.1177/03057356211026730)

### `SOVT-GENERAL-01`

可作为“经人工审核的一般热身/发声探索”候选，不应由某个声学指标自动开药式触发：

- 初始内容只允许 humming 或合适阻力的 flow-resistant tube；保持舒适音高/响度、短时、无痛。
- 用户出现疼痛、明显不适、呼吸或吞咽困难、突然显著改变时停止；不通过应用继续尝试纠正。
- 产品不得称其会治疗病变，也不得把某一次声学改善当成长期健康收益。

证据：2024 随机临床试验中 FRT 与 LMRVT 对 voice-disorder 人群的 VHI 相对对照改善，但该人群与健康自学歌手不同，[原始 RCT](https://doi.org/10.1044/2024_JSLHR-22-00456)；2026 年 45 名业余合唱歌手的四周试验报告 water-resistance tube 的部分声学、听感与自评改善，[歌手 RCT](https://doi.org/10.1016/j.jvoice.2026.01.051)。2026 歌手 conditioning 范围综述仅纳入 8 项研究，干预差异很大且多依赖自评，因此只给中低置信度的课程方向，[范围综述](https://pubmed.ncbi.nlm.nih.gov/42454833/)。

### 低证据练习

`HOLD-STEADY-01`、`RHYTHM-ENTRY-01`、`LEVEL-CONTOUR-01`、`RANGE-GENTLE-01` 与 `REFERENCE-AB-01` 目前是合理但未被本产品人群验证的教学假设。它们在内容系统中必须为 `review_status=unreviewed`、`evidence_grade=U/PED`，在完成人工复核和产品实验前不能写成“科学证实有效”。

## 4. 歌曲 reference 对比合同

```text
authorized local song
  -> offline separator (vocals + residual)
  -> artifact / voicing gate
  -> reference F0 + onset + phrase boundaries
  -> key/tempo-aware alignment
user practice recording
  -> capture quality gate
  -> user F0 + onset + phrase boundaries
  -> only mutually valid windows
  -> observations + A/B evidence + one reviewed exercise
```

- reference 先按 phrase 对齐，不把原唱和用户 waveform 逐 sample 相减。
- 允许用户选择转调；比较 target contour 时保存 transposition，避免把全曲合法转调报成持续跑调。
- 伴奏 bleed、和声、混响和重叠人声会破坏 reference F0；此时必须降置信或拒绝评分。
- 歌手 stem 只作为“这一版演唱”的 reference。音色、发音、风格、颤音与动态允许多解。
- 对比报告至少回放 reference/user 对应短窗，使用户能核对算法观察。

## 5. 初版课程骨架

| 模块 | 学习目标 | 测量/反馈 | 解锁条件 |
|---|---|---|---|
| `M0` 安全与基线 | 理解 Observation、录音质量和停止条件 | quality flags、自报舒适区/不适 | 完成权利与安全确认 |
| `M1` 听与模唱 | 区分目标、自己与 visual trace | 单音 signed/absolute cents | 不是统一 cents 硬阈值；用个人稳定趋势和有效数据率 |
| `M2` 相对音程 | 复制 3–4 音轮廓 | interval error、方向 bias | 两次有/无视觉反馈的 retention 对比 |
| `M3` 持续与复现 | 在舒适音高复现稳定段 | detrended MAD、慢漂移 | 明确排除 vibrato/滑音任务 |
| `M4` 节奏与句首 | 跟随短句 onset/时值 | onset delta、duration ratio | score/reference 对齐置信足够 |
| `M5` 歌曲短句 A/B | 对比授权原唱 stem 与自己 | phrase pitch/timing + 回放 | separation artifact gate 通过 |
| `M6` 动态与表达 | 在准确基础上探索多种表达 | 相对 contour，不给审美总分 | 课程内容已按目标风格人工审核 |

产品学习循环采用：baseline → 单一目标短练 → 即时 knowledge-of-results → 隐藏反馈复测 → 隔日 retention。有关把运动学习原则用于 voice therapy 的证据仍处早期、样本小，不能把这个循环宣传成临床最优剂量，[2026 review](https://pubmed.ncbi.nlm.nih.gov/41941658/)。

## 6. 安全语言与转介

应用只能询问症状，不能从麦克风诊断症状：

- 疼痛、呼吸困难、吞咽困难、咳血、颈部肿块、近期头颈/胸部手术后声音改变、突然或进行性显著变化：停止训练并提示尽快联系合格医疗专业人员；紧急呼吸问题应使用当地急救服务。
- 持续的 dysphonia/hoarseness 在 4 周内未改善，应提示耳鼻喉/喉科评估。专业嗓音使用者属于需要更早考虑升级评估的因素。
- 在把临床 voice therapy 当作治疗建议前需要喉镜检查；应用中的一般练习不得冒充 voice therapy。

上述边界来自 AAO-HNSF 多学科临床指南；它建议未在 4 周内改善或怀疑严重原因时进行/转介喉镜检查，并建议 voice therapy 前先行诊断性喉镜检查。[指南原文](https://doi.org/10.1177/0194599817751030) [官方入口](https://www.entnet.org/quality-practice/quality-products/clinical-practice-guidelines/hoarseness-dysphonia/)

## 7. 不可推断事项

以下输出即使“看起来合理”也不得从当前消费级麦克风自动产生：

- “提喉、压喉、挤压、漏气、闭合不足、声带疲劳/损伤风险”；
- 结节、息肉、炎症、反流、声带麻痹、神经或听觉疾病；
- 呼吸支持、肺活量、声门下压、喉部肌张力；
- 胸声/头声/混声、声区转换位置、声带厚薄或振动模式；
- 共鸣位置、喉位、咽腔形状、twang 或 singer's formant；
- 由音高/响度/谱一个指标得出的“唱法正确”“嗓音健康”或综合唱功分。

原因不是缺一个更聪明阈值：jitter/shimmer 等并非独立病理指标，且明显受系统、性别、元音和响度混杂，[临床综述](https://pubmed.ncbi.nlm.nih.gov/21483265/)；ASHA 专家协议推荐的 CPP 也是声学辅助量而非声带成像，[测量协议](https://doi.org/10.1044/2018_AJSLP-17-0009)；手机与临床录音系统在 HNR、AVQI、jitter、CPPS 等指标上存在显著不一致，[系统综述与 meta-analysis](https://pubmed.ncbi.nlm.nih.gov/41037430/)。

## 8. 内容与建议数据合同

```json
{
  "observationId": "pitch.signed_bias.v1",
  "evidence": {
    "metric": "median_signed_cents",
    "value": 23.4,
    "validFrames": 146,
    "windowStartSample": 288000,
    "windowEndSample": 360000
  },
  "confidence": "moderate",
  "qualityFlags": ["reference_separation_artifact_possible"],
  "scope": {
    "task": "phrase_reference_comparison",
    "deviceSessionOnly": true,
    "transpositionSemitones": -2
  },
  "exerciseContentId": "PITCH-PATTERN-02",
  "contentVersion": 1,
  "reviewStatus": "unreviewed",
  "evidenceGrade": "CT",
  "sourceIds": ["BERGLIN_2022"],
  "limitations": ["short_training_trial", "individual_response_varies"]
}
```

硬规则：`quality gate fail => observation suppressed`；`review_status != reviewed => 不可显示 expert-approved`；缺 `sourceIds/limitations/scope` 的推荐不得进入 production content catalog。

## 9. 正规课程与核心来源

NATS 的 Science-Informed Voice Pedagogy 资源提供一/两学期 syllabus、实验、lesson observation、vibrato/voice-range-profile 等材料，可作为课程设计与人工 reviewer 培训的正规入口；NATS 自己也把它称为持续演化的 living documents，因此其角色是 `PED` 而不是疗效证据。[NATS 官方资源](https://www.nats.org/cgi/page.cgi/Science-Informed_Voice_Pedagogy_Resources.html)

核心证据索引：

| ID | 类型 | 用途 | 关键限制 |
|---|---|---|---|
| `ASHA_MEASURE_2018` | `G` 专家协议 | F0/SPL/CPP 测量选择与采集注意 | 临床协议不等于消费设备诊断 |
| `AAOHNS_DYSPHONIA_2018` | `G` 临床指南 | 停止、转介和 voice-therapy 边界 | 面向 dysphonia 管理，不是歌唱课程 |
| `BERGLIN_2022` | `CT` 成人随机训练 | pitch visual feedback 与 4 音模式 | 20 分钟、低准确度成人、个体差异大 |
| `LARROUY_2017` | `P` 比较研究 | tempo/articulation/tessitura 会改变 pitch error | 20 名歌手，不能导出统一阈值；[PubMed](https://pubmed.ncbi.nlm.nih.gov/26948385/) |
| `HELLER_STARK_2024` | `CT` 随机临床试验 | FRT/LMRVT 候选 | voice-disorder 人群，不可直接外推健康歌手 |
| `MEERSCHMAN_2026` | `CT` 歌手随机试验 | 水阻管候选 | 45 名业余合唱歌手、四周、部分指标 |
| `CARVALHO_2026` | `SR` 范围综述 | 歌手 conditioning 课程方向 | 仅 8 项，方案异质、多自评 |
| `SAEEDI_2023` | `SR` 系统综述 | vocal-health education 候选 | 仅 4 项且多为小样本；[PubMed](https://pubmed.ncbi.nlm.nih.gov/38052688/) |
| `SMARTPHONE_META_2025` | `SR` meta-analysis | 手机声学指标的设备限制 | 10 项/379 人，设备和指标异质 |
| `NATS_CURRICULUM` | `PED` 正规专业课程 | reviewer 培训、内容结构 | living documents，不是干预效果试验 |

## 10. 下一 gate

1. 声乐教师 + SLP/嗓音医学 reviewer 对所有中文文案、练习演示、剂量和停止条件签核。
2. 用授权健康成人做 usability/measurement study；预注册主要终点，分别报告 retention 与即时表现。
3. 对每个设备/麦距/伴奏泄漏/分离 artifact 分层，验证 false observation 和 suppression rate。
4. 先验证 `PITCH-MATCH-01/02`，再逐个解锁低证据练习；不同时推出整套课程后只看满意度。
5. 在未完成这些 gate 前，本文件只能指导 schema、原型与内容评审，不能让产品声称“专业声乐老师”“治疗”或“医学级”。
