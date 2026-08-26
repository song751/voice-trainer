# 分离人声与练唱短句对比 MVP

状态：实现合同；2026-08-27。

## 边界

本功能只比较用户明确选择的已分离 vocals stem 和一个已保存练习会话中的明确短窗。参考人声标记为“歌曲分离估计（无人声逐句真人标签）”，不是唯一正确演唱，也不是 ground truth。

进入解释前必须同时满足：

- 用户试听并确认该窗口的分离伪影不妨碍比较；
- 用户确认窗口以单一主旋律人声为主；
- 双方 voiced coverage、周期性、采集质量和互相可比窗口达到门禁；
- 每个窗口为 1–30 秒；
- 用户会话有本地录音用于 A/B 回放，指标来自其既有 packed feature series。
- stem 实际 bytes、stem 元数据和 reference feature provenance 三者内容身份一致；练唱 WAV 实际 bytes、recording locator 和 packed feature provenance 三者内容身份一致。

内容身份由 SHA-256 与 byte length 组成，报告只显示前 12 位短 ID，不记录完整 hash、路径或音频。任一内容身份缺失、越界、文件缺失或不匹配时 fail closed：报告不计算 coverage/对齐/对比指标，也不输出 `REFERENCE-AB-01`。其他信号/人工门禁失败时，报告保留 coverage、quality flags、scope 和抑制原因。

## 版本化算法

- reference 特征：`reference-yin-14k7-v1`。44.1 kHz stereo stem 下混 mono，用 SRD-03 已记录的三点均值降到 14.7 kHz，1024 window / 147 hop，YIN 60–1000 Hz；RMS ≥ -55 dBFS 且 clarity ≥ 0.60 才算 voiced。
- 用户特征：直接读取会话已有 packed series，保留其 `algorithmVersion`，不覆盖、不静默重算。
- 对比：`reference-comparison-v1`。按双方第一个可靠 voiced onset 对齐，用 voiced span 比例报告时间伸缩；匹配窗口的原始 cents 中位差作为 key difference，并以最近整半音做轮廓移调对齐。报告同时保留原始 key difference 和实际移调参数。

独立显示：pitch contour 中位/P90 绝对差、onset delta、voiced-span/tempo scale、去中位 level envelope 差与双方 level MAD、双方周期性中位数。没有总分，也不做 head/falsetto/mix/metal 分类或闭合、喉位、病理推断。

## 播放与存储

Windows/Android 使用应用内播放器读取两个经过 managed-root、长度与 hash 验证的私有 snapshot lease，并限制到用户选择的窗口；播放器和 extractor 均不会接收数据库中的原始路径，不会启动 shell 或外部播放器。snapshot 令验证后源文件替换不会改变本次比较输入，并在 controller 销毁时清理。Web 当前没有可用的歌曲分离 runtime，因此 resolver、reference 分析和 A/B 均为 typed unavailable；OPFS locator 与 BlobStore API 不变。

Drift schema v6 为 recording 与 packed feature metadata 各增加 nullable SHA-256/byte-length provenance。新录音 finalize 后绑定两侧；旧记录保持 NULL，禁止根据当前文件回填，因此不可进入 reference comparison。歌曲 reference 当前本身仍是会话内状态，对比报告保持会话内可重算。报告显式携带 separator、reference analyzer、user analyzer 和 comparison 四个版本；未来若持久化歌曲 reference，再以独立 migration 保存报告，不把它塞入现有 session summary JSON。

`REFERENCE-AB-01` 仍按证据地图保存为 `draft/unvalidated`。仓库没有声乐教师与 SLP/嗓音医学 reviewer 签核，因此 UI 必须显示“未审核”，不得伪标 expert-approved。

## 尚未覆盖

- 没有歌词、score 或人工 phrase label；首版窗口由用户选取。
- Web OPFS 录音有内容身份但没有 native path lease；在 Web reference runtime 单独通过 worker/播放/资源 gate 前仍明确 unavailable。
- 没有 DTW 音符级配准；时间对齐是公开的 onset + voiced-span affine 参数。
- 分离伪影和单旋律适用性依赖用户听检；后续授权标注集才可验证自动 artifact/monophony gate。
- 未在 Android 真机或 Web reference runtime 验证；模拟器结果不得替代真机。

## 本卡验收证据

- Windows integration 使用测试进程生成的 3 秒、44.1 kHz stereo、220 Hz WAV，实际经过 Rust 文件解码和 `reference-yin-14k7-v1`：得到超过 250 帧、超过 240 个 voiced 帧，A3 中位误差小于 2 cents；再与构造为高 200 cents 的 packed 练唱 series 比较，公开报告 `+2` 半音移调且对齐后的 pitch contour 中位误差小于 0.1 cents。
- 同一 Windows integration 通过 production `NativeAudioPreview` 实际播放 reference 的 0.10–0.25 秒窗口并停止；测试结束删除临时 WAV。它验证本机应用内播放器链路，不是听感、扬声器或移动设备验收。
- `flutter build windows --debug`、自包含 `flutter build web --release --no-web-resources-cdn --csp`、四 ABI `flutter build apk --debug` 均完成。Web 构建通过不改变 reference runtime 的 typed unavailable；Android 结果仅为 build evidence，未连接模拟器、未验证播放或资源占用。
- 确定性测试覆盖移调/时间对齐、artifact/monophony/无声 suppression、UI 报告字段与内容审核状态、vendored Android plugin 完整性；Flutter analyze/test 与 Rust fmt/Clippy/test 全量 gate 通过。
