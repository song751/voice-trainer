# Phase 1 Closure 执行计划

更新时间：2026-08-05  
状态：**Phase 1 与 Closure C1–C4 已全部完成；下一张且唯一允许执行的卡是 P2-01。**

当前执行状态：C4 本地 gate、真实 Edge dedicated worker smoke、Android/Windows/Web 构建和
最终 hosted CI 均通过。跨平台 FRB Web 编译产物不再被错误要求 bit-exact；声明式生成物仍执行
严格 drift 检查，JS/WASM 绑定对改用结构、语法、关键导出、构建和 runtime 验证。Phase 2 已解锁，
但卡片顺序仍是硬约束，当前不得越过 P2-01。

本文件保留 Phase 1 Closure 的审计与验收记录，并定义已解锁的 Phase 2 固定顺序。后续 Agent 仍必须一次只执行一张卡；当前只执行 P2-01。

## 当前判定

| 范围 | 状态 | 审计结论 |
| --- | --- | --- |
| P1-01 Domain/state machine | 通过 | sealed state、typed failure、合法/非法迁移测试完整；domain 没有插件依赖。 |
| P1-02 Fake E2E | 通过 | start/pause/resume/stop、慢分析丢帧、失败恢复均有测试。 |
| P1-03 Capture adapter | 通过 | adapter contract、PCM ownership、奇数字节/config/暂停/设备与 stream error、生产 WAV sink 和恢复均有测试。 |
| P1-04 Worker supervisor | 通过 | `primary → restart once → fallback → terminal`、timeout/terminate、异常测试和真实 Edge/Windows 对比完整。 |
| P1-05 Persistence v1 | 通过 | Native/Web BlobStore、tombstone/recovery、事务回滚和 feature-series 无损 round-trip 完整。 |
| P1-06 Riverpod/shell | 通过 | provider 可覆盖，五个最小路由、错误/no-data/widget tests 均在 Phase 1 范围内。 |
| P1-07 CI/matrices | 通过 | 四条 workflow、生成物 gate、平台矩阵、remote 和最终 hosted CI 绿灯均可复核。 |
| P1 cross-cutting | 通过 | 结构化日志在 sink 前脱敏；全局 mapper 将外部错误映射为 typed failure，不保留原始敏感消息。 |

### 已复验的证据

- 源码范围 Dart format：111 files，0 changed。
- `flutter analyze` 通过。
- Flutter 单元/Widget tests：42 个通过。
- Windows fake integration：3 个通过。
- Rust fmt、Clippy、tests：2 个通过。
- Flutter Web release build 通过；产物包含 dedicated worker、Rust WASM、SQLite WASM 和 Drift worker。
- Edge dedicated Worker runtime smoke 通过：90 frames、sample checksum `2,050,560`，与 Windows 基线相容且未出现 DataCloneError。
- Android debug APK 构建通过。
- commit `ab66892` 的 Dart/Rust、Web、Android、Windows hosted CI 全绿。

## 审计发现与处置

1. [C1 已解决] 建立 Git 基线、remote、忽略/二进制属性和 hosted CI 证据。
2. [C1 已解决] 同步阶段文档，并统一 Phase 2 不实现 HNR、Formant、CPPS、Jitter/Shimmer。
3. [C2 已解决] Worker 使用有限恢复状态机、每请求 timeout 和直接 terminate，并完成真实 Edge 验收。
4. [C3 已解决] feature series 保留 sample timeline、RMS、Peak、Clarity 等原值及列校验和。
5. [C3 已解决] Native/Web 生产 BlobStore、删除 tombstone 和启动恢复均已实现并验证。
6. [C4 已解决] 增加 sink 前结构化日志脱敏、统一错误 mapper、全局 providers 和对应 tests。
7. [C1 已解决] format gate 只扫描源码目录，不再包含 `build/` 或第三方生成副本。
8. [C4 已解决] FRB JS/WASM 编译产物采用语义/runtime gate；声明式生成物继续严格拒绝漂移。

## 执行规则

- C1–C4 已完成。后续顺序固定为 `P2-01 → P2-02 → ... → P2-07`；当前只允许 P2-01。
- 每张卡结束时，记录实际执行命令、平台、结果、未覆盖项和证据文件位置。
- 不以 build 成功、fake 测试或模拟器代替真实麦克风/Edge Worker 验收。
- 格式检查仅扫描明确的源码目录；不要将构建目录、缓存或第三方生成副本纳入 gate。
- P2-01 完成前不得修改生产 pitch、spectrum、resampler 或 bridge DTO。

---

## C1：建立可信仓库基线与文档同步

**目标**：使当前状态可审计、可回滚、可由 CI 验证，并消除文档冲突。

### 工作范围

1. 审查 secrets、录音、构建产物和大文件，确认不应进入版本库的内容已被忽略。
2. 补充 `.gitattributes`；明确 `pubspec.lock`、FRB/Drift/Web WASM 等生成物是否应提交，并将决定写入文档。
3. 建立当前审计基线 commit（仅在完成敏感文件审查后）。
4. 同步 `AGENTS.md`、`README.md`、manifest、研究记录及任务文档：当前阶段为 Phase 1 Closure，下一张卡为 C1。
5. 以 Playbook 为准，修正 CPPS/Formant/HNR/Jitter/Shimmer 的 Phase 2 范围冲突。
6. 将格式 gate 改为只检查 `lib`、`test`、`integration_test`、`tool` 等明确源码目录；确保重复运行结果一致。
7. 配置 remote 后触发并保存第一次 hosted CI 结果。remote 的选择和授权由仓库所有者决定。

### 验收

- Git 状态、忽略规则、生成物策略和首个基线 commit 可复核。
- 文档不存在将项目当前状态误写为 Phase 0 或仅等待 CI 的过期声明。
- CPPS/Formant 的 Phase 2 范围只保留 Playbook 结论。
- 源码范围 format gate 可重复通过，不扫描 `build/`。
- remote 已配置且 hosted CI 有可链接的首次运行结果；若 remote 尚未获授权，明确记录为外部阻塞。

### 交付物

- 更新的仓库元数据、文档和 CI gate。
- `docs/RESEARCH_NOTES.md` 中的基线与 hosted CI 证据。

---

## C2：关闭 Worker gate

**目标**：使分析 worker 在异常和无响应时有可验证的降级路径，并完成真实 Edge Worker 运行时验收。

### 工作范围

1. 将 supervisor 改为明确状态机：`primary → restart once → fallback → terminal failure`。
2. 每个 worker 请求增加 timeout；崩溃后的 `dispose` 必须可以直接 terminate，不能等待死 worker 回复。
3. 新增测试：替换 worker 也崩溃、fallback 也崩溃、finish/reset 超时。
4. 新增可重复的 Edge runtime smoke 脚本，直接调用 `VoiceTrainerAnalysisWorker`。
5. 在 Windows 与 Edge 比较 frame count、sample checksum、RMS/pitch 容差，并记录 DataCloneError 是否复现。

### 验收

- 连续两次 worker 崩溃后，行为符合状态机，不会无界重试或直接绕过 fallback。
- 无响应 worker 能在 timeout 后终止和释放。
- 新增异常路径测试稳定通过。
- Edge dedicated Worker 实际运行成功，且与 Windows 结果在约定容差内；证据已记录。

### 交付物

- 状态机实现、timeout/terminate 机制、测试和 Edge smoke 脚本。
- Windows/Edge 对比结果及 DataCloneError 结论。

---

## C3：关闭 Persistence/Capture gate

**目标**：提供真实录音存储、可恢复的生命周期，以及无损 feature-series round-trip。

### 工作范围

1. Native 实现录音 sink/store：`.partial → flush → WAV header → atomic rename`。
2. Web 定义并实现存储层级：OPFS 优先、IndexedDB fallback、内存降级警告；音频保持独立于 SQLite。
3. 实现 recording tombstone、物理删除和启动恢复服务。
4. 重构 feature-series 持久化：保存明确的起始 sample index、sample-period samples 和每个特征列，不得根据数组位置重建时间轴或伪造特征值。
5. 增加真实 `DriftSessionRepository` save/find round-trip、checksum、事务回滚和文件恢复测试。
6. 补 capture tests：buffer immutability、奇数字节、config changed、暂停恢复、设备不可用和 stream error。

### 验收

- Native 录音不会以半成品作为完成文件暴露；异常中断后可恢复或清理。
- Web 明确展示所选存储实现及不可持久化降级警告。
- 删除、tombstone、启动恢复和物理文件清理均有测试。
- feature-series round-trip 保持原始 sample index、period、RMS、Peak、Clarity 和 checksum。
- 事务失败不会留下不一致的 DB/录音状态。
- 所列 capture contract tests 通过。

### 交付物

- Native/Web BlobStore 与恢复服务。
- 无损 feature-series codec/repository 测试。
- 完整 capture contract 覆盖。

---

## C4：Phase 1 最终 Gate

**目标**：将 Phase 1 从「主体已落地」提升为「可判定完成」。

**状态：通过（2026-08-05）。** 本地与 hosted 证据见 `docs/RESEARCH_NOTES.md` 的 C4 执行记录；下一张允许卡为 P2-01。

### 工作范围与验收

重新执行并记录以下证据：

1. 源码范围 format gate。
2. Flutter analyze、单元测试和 widget 测试。
3. Rust format、Clippy、tests。
4. Windows fake integration 与真实录音相关测试。
5. Flutter Web release build 和实际 Edge dedicated Worker smoke。
6. Android build。
7. hosted CI 全绿。

只有所有自动化项通过、真实 Edge Worker smoke 有记录、hosted CI 全绿，才可把 Phase 1 标记为完成并解锁 P2-01。

---

## Phase 2 DSP MVP：解锁后的固定顺序

> 前置条件：C1–C4 全部通过。不得直接从 MPM/YIN 开始。

| 顺序 | 卡片 | 目标 |
| --- | --- | --- |
| P2-01 | 确定性信号与 golden harness | 生成纯音、谐波、缺失基频、固定种子噪声、滑音、静音、削波、断点；保存参数、SHA-256 和预期指标。 |
| P2-02 | Signal core | 新建 `signal/pcm.rs`、`ring_buffer.rs`、`dc_blocker.rs`、`window.rs`、`resampler.rs`；替换实时路径中的 `Vec::drain`；48→16 kHz 使用低延迟 polyphase FIR，非整数比率再评估 rubato。 |
| P2-03 | Pitch/voicing | 创建 MPM/YIN estimator trait 和两种实现，加入抛物线插值、连续性和 voiced decision；用 golden 选择默认算法。 |
| P2-04 | Full-band spectrum | 48 kHz、2048 Hann、hop 480；实现正确的 power dBFS normalization、band power、spectral centroid 和 128 个对数 UI bins。 |
| P2-05 | Aggregator/features | 实现 clipping、input-too-low、dropped/discontinuity、有效帧不足、音高/音量 robust stability、onset 和 segment aggregator。 |
| P2-06 | Bridge DTO | 扩展 Rust/FRB/Web Worker DTO 和 Dart mapper；保持 bridge batch 最多 1024 samples，不传递内部 DSP 状态或过大频谱数组。 |
| P2-07 | Bench/Gate | 新增 `rust/tests/{chunk_invariance,pitch_golden,spectrum_golden,discontinuity}.rs` 与 `rust/benches/{realtime_pipeline,bridge_payload}.rs`，在 Windows 与 Edge/WASM 验收。 |

### P2-01 当前执行边界

- 只创建确定性信号生成器、golden harness、manifest/schema 和对应 tests；生产实时 analyzer 行为保持不变。
- 信号集必须覆盖纯音、谐波、缺失基频、固定种子噪声、滑音、静音、削波和明确 sample-index 断点。
- 每个 case 固定 sample rate、sample count/duration、振幅/频率参数、随机种子、PCM 编码规则和 SHA-256；同一命令连续运行两次必须 bit-exact。
- manifest 的预期值只描述可独立计算的真值/范围和后续算法 gate，不把当前 Phase 0 FFT-autocorrelation 输出固化为正确答案。
- 优先运行时生成；只有体积小、用途和许可清楚且确需 bit-exact 回归的 golden 才可提交二进制。
- P2-01 验收至少包括生成器单元测试、manifest/哈希自校验、固定种子复现、断点语义测试，以及 Rust fmt、Clippy `-D warnings`、全量 Rust tests。
- 完成后把文件、命令、case 数、hash 证据和未覆盖项写入 `RESEARCH_NOTES.md`，明确解锁 P2-02；在此之前不得修改 pitch、spectrum、resampler 或 bridge DTO。

### Phase 2 硬性指标

- 纯音中位误差 `< 1 cent`。
- 谐波噪声：P95 `< 5 cents`、octave error `< 0.5%`。
- 滑音：P95 `< 10 cents`。
- 静音/低能量噪声：voiced false positive `< 1%`。
- 任意 chunk 切分不变量、实时路径无大分配、Web 单线程可运行。
- Phase 2 不实现 HNR、Formant、CPPS、Jitter/Shimmer。

## 每张卡的交接模板

后续执行 Agent 在卡片完成时，将以下内容追加到对应任务记录或 `RESEARCH_NOTES.md`：

```md
### <卡片编号> 执行记录（YYYY-MM-DD）

- 范围：
- 修改文件：
- 执行命令与结果：
- 平台/运行时：
- 验收结论：通过 / 未通过
- 未覆盖项或外部阻塞：
- 证据（日志、截图、CI run、校验值）：
- 下一张允许执行的卡：
```
