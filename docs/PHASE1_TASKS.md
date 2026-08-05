# Phase 1 Task Cards

前置条件：Phase 0 Gate 0A–0E 已通过。每张卡单独执行、单独验收；不要把这些卡合并成一次“生成整个应用”。

## P1-01 Domain contracts and session state machine

创建 manifest 中的 `core/domain` contracts、value objects 与 `PracticeSessionState`：idle → requestingPermission → ready → running/paused → finalizing → completed/failed。不得导入 Flutter plugin、Drift 或 FRB。用纯 Dart tests 覆盖合法/非法转移、permission denied、capture failure、finalize recovery。

验收：domain tests 不初始化 Flutter binding；状态和错误是 sealed/typed，不用 UI string 表示。

## P1-02 Fake end-to-end session

实现 `FakeAudioCapture`、`FakeAnalysisEngine`、in-memory repositories 和 application coordinator。输入确定 PCM chunks，完成一次 start/pause/resume/stop，并验证 sample index、bounded queue 和 dropped/discontinuity accounting。

验收：fake integration test 完整闭环；慢 analysis、queue overflow、stop during failure 均可恢复；没有正式页面。

## P1-03 Capture adapter promotion

把 Phase 0 CaptureInspector 的已验证逻辑拆到 `AudioCapture` adapter、metrics collector 和 streaming WAV sink。遵守 `docs/specs/AUDIO_CONTRACT.md`，Web 512/1024 fallback；Phase 0 inspector 保留为手动诊断工具。

验收：adapter contract tests + Windows/Edge 手动 smoke；callback 不直接调用 UI/DB/DSP。

## P1-04 Analysis worker supervisor

把 Rust `RealtimeAnalyzer` 放入正式 `AnalysisEngine` adapter。Native 保留 FRB worker pool；Web 建 dedicated worker，消息只传 1024-sample typed batches 和精简 DTO，并保留 Gate 0D 单线程 fallback。不要恢复 FRB 2.12 默认 WASM WorkerPool。

验收：主线程 heartbeat 在 10 分钟模拟流中不中断；worker crash/restart、fallback、queue overflow 有 tests；Windows/Edge checksum 与 Gate 0D baseline 相容。

## P1-05 Persistence v1 promotion

把 Phase 0 schema/codec 移到 manifest 的 infrastructure 路径：Native file DB 使用 Drift background isolate；Web 使用 `WasmDatabase.open` 并暴露 chosen implementation/missing features。`unsafeIndexedDb`/`inMemory` 必须产生用户可理解的持久性警告。录音使用独立 BlobStore。

验收：fresh schema、migration v1、packed BLOB、repository transaction、delete/recovery tests；数据库中无 per-frame table 和 audio BLOB。

## P1-06 Riverpod composition and minimal navigation shell

只做依赖注入、router 和可导航的最小占位内容，把 fake session 接入；不制作完整设计、不批量生成训练/历史/分析页面。

验收：provider override 可替换全部外部 adapter；widget tests 覆盖 permission/error/no-data；页面不直接 import record/Drift/FRB。

## P1-07 CI and platform matrices

增加 Dart/Rust checks、Windows/Web/Android build workflow，并创建 test matrices。真实麦克风列为 manual，不能用 fake/emulator 冒充；Apple/Linux 未在当前机器实测时明确标记 pending。

验收：CI 命令与 `AGENTS.md` 一致，生成文件漂移检查、FRB Web build 和 Android compatibility patch audit 均有步骤。

## 模型与执行建议（2026-08-03）

- 默认：`gpt-5.6-terra` + Medium，一次只做一张卡。适合 P1-01/02/03/05/06/07。
- `gpt-5.6-terra` + High：P1-04 Web worker、复杂 Drift migration 或稳定复现失败时使用；不要用 High 承担整个 Phase。
- `gpt-5.6-luna` + Medium：已有明确接口/文件/测试的机械实现、补测试、CI YAML、文档同步；每轮必须给窄文件范围和验收命令。
- `gpt-5.6-sol` + High：只用于架构复核、跨平台 worker/FFI 难题、数据一致性或难解回归。`xhigh/max` 只在同一 blocker 已有最小复现且 High 两轮无法解决时短时使用。
- 不建议为了省钱退回 GPT-5.5/5.4：官方当前把 Terra 定位为质量/成本平衡、Luna 定位为高吞吐；迁移建议是先保持 reasoning effort，再对代表任务比较降低一级，而不是先退模型代际。
