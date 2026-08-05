# Phase 1 Closure 执行计划

更新时间：2026-08-05  
状态：**Phase 1 主体已落地，但尚未完成；C1 已完成，下一张允许执行的卡是 C2。**

当前执行状态：已建立首个本地审计基线、忽略与生成物策略并同步文档；GitHub remote 已配置、
首轮 hosted CI 已触发并记录。首轮 Web generated-file drift 已修复并重新触发。C4 才负责
汇总并判定所有 hosted CI 的最终绿灯；在此之前仍不得进入 Phase 2。

本文件将 Phase 1 审计结论转成可逐卡执行、逐卡验收的收尾计划。后续 Agent 必须一次只执行一张卡；除非卡内明确要求，不得提前开始 Phase 2 DSP。

## 当前判定

| 范围 | 状态 | 审计结论 |
| --- | --- | --- |
| P1-01 Domain/state machine | 通过 | sealed state、typed failure、合法/非法迁移测试完整；domain 没有插件依赖。 |
| P1-02 Fake E2E | 通过 | start/pause/resume/stop、慢分析丢帧、失败恢复均有测试。 |
| P1-03 Capture adapter | 部分通过 | 正式 adapter、PCM 所有权复制、512 buffer、WAV writer 已有；但 contract tests 较少，且缺提升后的 Windows/Edge smoke 记录与生产 WAV sink。 |
| P1-04 Worker supervisor | 部分通过 | 队列、拆批、重启和 fake heartbeat 测试存在；真实 Edge dedicated Worker 未验收，连续崩溃时也没有可靠切换 fallback。 |
| P1-05 Persistence v1 | 未闭合 | Native background DB、Web `WasmDatabase` 和 packed BLOB 已有；生产 BlobStore、repository round-trip、真实文件删除/恢复均缺失。 |
| P1-06 Riverpod/shell | 通过 | provider 可覆盖，五个最小路由、错误/no-data/widget tests 均在 Phase 1 范围内。 |
| P1-07 CI/matrices | 仅配置 | workflow 内容基本正确，但仓库没有 commit、没有 remote；hosted CI 尚不可能有运行记录。 |

### 已复验的证据

- 源码范围 Dart format：98 files，0 changed。
- `flutter analyze` 通过。
- Flutter 单元/Widget tests：25 个通过。
- Windows fake integration：3 个通过。
- Rust fmt、Clippy、tests：2 个通过。
- Flutter Web release build 通过；产物包含 dedicated worker、Rust WASM、SQLite WASM 和 Drift worker。
- Edge dedicated Worker runtime smoke **未执行**：当前浏览器控制接口不可用。因此仅确认构建产物，不能把 runtime 标记为通过。

## 必须优先处理的事实

1. `master` 是零提交，约 299 个项目文件全部未跟踪，且没有 remote。因此没有可信基线、历史回滚或 hosted CI 证据。
2. [C1 本地范围已解决] 审计时 `AGENTS.md` 仍称项目处于 Phase 0 前、`README.md` 把 Phase 1 简化为只等待 CI；两份文档现已同步为 Phase 1 Closure / C1 外部阻塞状态。
3. `AnalysisWorkerSupervisor` 当前只兜底第一次调用：替换 worker 再崩溃会直接抛错，且 Web 请求缺少 timeout/终止保护。
4. `DriftSessionRepository` 读取 feature series 时会将 sample index 重建为 `0, 1, 2...`，并将 RMS、Peak、Clarity 重建为零，破坏「sample index 是唯一时间轴」约束。
5. 目前只有 `InMemoryRecordingStore` 和 `WavStreamWriter`，没有 Native/Web 生产 BlobStore。
6. Playbook 要求的日志脱敏和全局错误映射尚未创建。
7. `dart format ... .` 会扫描 `build/` 中的 Cargokit 生成副本而失败；格式 gate 应只检查源码目录并保持幂等。
8. `PROJECT_BLUEPRINT.md` 与 `IMPLEMENTATION_PLAYBOOK.md` 对 CPPS/Formant 阶段描述冲突。以 Playbook 为准：Phase 2 不实现 HNR、Formant、CPPS、Jitter/Shimmer。

## 执行规则

- 卡片顺序固定为 `C1 → C2 → C3 → C4 → P2-01`。一张卡未通过不得开始下一张。
- 每张卡结束时，记录实际执行命令、平台、结果、未覆盖项和证据文件位置。
- 不以 build 成功、fake 测试或模拟器代替真实麦克风/Edge Worker 验收。
- 格式检查仅扫描明确的源码目录；不要将构建目录、缓存或第三方生成副本纳入 gate。
- Phase 2 开始前，所有 Phase 1 Closure 的验收项和 hosted CI 必须为通过状态。

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
