# 歌曲人声分离质量评估协议（SRD-03）

状态：R&D evidence only；不被 Flutter、FRB 或 production Rust 调用。

## 1. 评估对象与权利门禁

每个 case 必须提供 44.1 kHz、stereo、PCM16、等长的 mixture、reference vocals、estimated vocals 和 estimated accompaniment。音频与输出留在 Git 外；仓库只提交 schema、工具、获取说明与可复核的 hash/摘要。

`quality_manifest.schema.json` 固定 v1 清单。运行时还会拒绝：

- 未确认 `--acknowledge-rights`；
- 空的许可/来源/核对人/日期；
- 绝对路径或 `..` 越界；
- SHA-256 不符、未知字段、重复 case ID；
- 非 44.1 kHz stereo PCM16 或任意长度不一致。

推荐的外部基线是通过官方流程获得的 MUSDB18-HQ；它含 150 首、44.1 kHz stereo mixture/stems。它不是统一的宽松许可数据集：官方说明包含 DSD100、CC BY-NC-SA、Native Instruments 与比赛来源，访问限学术用途，并提供逐曲许可表。因此每个 case 必须按曲核对，不能只写“来自 MUSDB”就假定可商用或可再分发：<https://sigsep.github.io/datasets/musdb.html>。

官方 7 秒 MUSDB18 sample 可以做工具 smoke，但它是 AAC stems、带宽约 16 kHz，且 mixture 独立编码后不严格等于 reference sources 之和；它不能替代 MUSDB18-HQ 的最终听感/全带宽 gate。

## 2. 指标含义

### 波形证据

- vocals SI-SDR：reference vocals 与 estimated vocals 的整段 scale-invariant SDR；实现固定为 `srd03-quality-v1`。这是轻量 regression 指标，不是 BSS Eval v4/museval，不能把数值与论文表格直接横比。
- mixture baseline SI-SDR 与 SI-SDR improvement：证明模型是否比直接拿 mixture 当 vocals 更有用。
- residual error dBFS：`mixture - estimated vocals - estimated accompaniment`；高于 -45 dBFS 标记 `residual_mismatch`。
- reference/estimate RMS 与 clipping fraction：reference 低于 -45 dBFS、estimate 低于 -55 dBFS、clipping 超过 0.1% 时标记质量问题。

### reference F0 / DTW 证据

F0 只对清单中经核对为 `monophonic_lead` 的 reference 启用。和声、叠唱、多人声或未完成听觉核对的 case 必须写 `not_eligible`，并输出 `reference_pitch_not_eligible` 与 pitch suppression，不能把单音 estimator 的选峰当成歌手主旋律。

开发算法把 stereo 合为 mono，经 3 点均值抗混叠降到 14.7 kHz，在 1024-sample window、147-sample hop 内做 60–1000 Hz normalized autocorrelation；之后在 20%/至少 10 帧的 Sakoe-Chiba 窗内做 bounded DTW。输出 median/p90 absolute cents、50 cents 命中比例与平均 DTW cost。它只用于分离 artifact/reference 可用性 gate，不进入用户声区、唱法或生理判断。

### confidence 与 suppression

`waveform_confidence` 取 reference level、clipping 与 residual consistency 的保守最小值；`pitch_confidence` 只在 `monophonic_lead` 时存在，并取 reference/estimate voiced coverage 的较小值。`confidence` 再取可用证据的保守最小值。

低 confidence 不删除原始测量，但必须置 `interpretation_suppressed=true`。`not_eligible` 只置 `pitch_interpretation_suppressed=true`，不会抹掉仍然有效的 waveform 分离证据。

这些门槛是研发筛查值，不代表听感优秀、教学可用，更不是医疗或声带状态判断。

## 3. 命令

```powershell
cargo run --release --manifest-path tool/song_separation/Cargo.toml --bin song_separation_rd -- `
  evaluate `
  --acknowledge-rights `
  --manifest <git-outside>/quality-manifest.json `
  --dataset-dir <git-outside>/quality-audio `
  --cancel-file <optional-cancel-sentinel>
```

stdout 每行一个 JSON progress/report。报告包含 case ID、许可证据、合同、指标、confidence 和 quality flags，不包含文件路径、曲名、PCM 或音频字节。取消在 hash、每个 pitch frame 与每行 DTW 处协作检查，不返回 completed report。

## 4. SRD-03 Windows smoke（2026-08-27）

使用官方 MUSDB18 7 秒 sample 中一个 DSD restricted case，仅作本地研究 smoke；音频、manifest、模型与输出均在 `%TEMP%`，未进入 Git。未做人工听觉核对，因此 `pitch_reference_scope=not_eligible`。

- mixture：300,032 frames；SHA-256 `247a97eb75a5be90d621a3b11bcfcd26f5fb3785fa77c79f25a2d5add322851b`
- reference vocals：SHA-256 `e854bb2c388c8bfc4e9c164c0fd6dca29965a329808e030146cb077d3151a0ff`
- UMX-HQ oracle vocals：SHA-256 `272a76e259cec66831d5f12b672757b08b34a8b8dfaf49c131113df578f913b1`
- residual accompaniment：SHA-256 `4af7724430d253833f0f13b840cfb30c61933cb09bc0e9c62047fc5c7b14b781`
- oracle inference：0.12564 s；peak RSS 748,175,360 bytes
- vocals SI-SDR 12.28795 dB；mixture baseline -4.92437 dB；improvement 17.21232 dB；residual error -98.62817 dBFS；reference/estimate clipping 均为 0

这是单个短、压缩、restricted research sample 的执行证据，不是产品质量结论。SRD-03 的非人工实现已经闭合；仍需仓库所有者提供/确认可用的逐曲授权集，并由人工听觉核对 `monophonic_lead` case，才能形成最终多曲质量接受报告。

## 5. SRD-04 移交边界

SRD-04 才能把分离接入产品，且必须在一张明确授权卡中同时交付：

1. 本地文件解码到 44.1 kHz stereo f32 与有界高质量重采样；不让采集/UI isolate 等待。
2. 与 UMX-HQ 一致的 centered STFT（4096/hop 1024）、model magnitude normalization/core inference、mask/Wiener 决策、mixture phase ISTFT 与长度补偿。
3. vocals + residual accompaniment 的数值和长度不变量；不可写假的成功文件。
4. 长音频 chunk/context/overlap/crossfade、边界 golden、工作内存上限、progress、取消延迟与 partial 清理。
5. production Rust adapter 到 Flutter `SongSeparator`：typed error、输出 locator/hash/format/model version；Windows/Android/Web 分平台 composition 与 unavailable/manual-stem fallback。
6. 30 秒/3 分钟/5 分钟性能；Windows、Android 真机、Web 单线程/WebGPU；SRD-03 质量集回归和人工听感 gate。

在这些条件满足前，UI 必须继续显示自动分离 unavailable，不得把当前 Python oracle 或 R&D tract harness 当 production backend。
