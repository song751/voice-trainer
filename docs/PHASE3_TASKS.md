# Phase 3 固定任务卡

更新时间：2026-08-07  
状态：**P3-00 至 P3-06 已接受但尚未形成独立可追溯工作树基线；P3-07 部分完成。当前只允许执行 P3-07P 核验/封存卡，之后才执行 P3-07A。P3-07D 需要仓库所有者在 Windows 电脑旁协助，现为阻塞。**

## 1. 目的与执行规则

Phase 3 将已验收的 P2 DSP 组件接入真实 Windows 采集、实时 UI、持久化、结果与历史闭环。它不重开 P2 算法决策，也不解锁 Android/Web 产品工作。所有卡必须按编号顺序单独实施、测试、记录；后续卡不得与当前卡混在同一提交中。

- 每张卡完成后，记录实际命令、平台、结果、未覆盖项及证据链接。
- 生产入口必须使用真实 sample-index timeline；wall-clock 只能作诊断元数据。
- 不得让 100 Hz 原始帧、PCM、数据库或写盘操作阻塞采集回调或直接重建 Flutter 页面。
- 不得将声学特征写成医疗结论；质量不足时应抑制解释并说明改善录音的方法。
- 除 P3-00 外，每张卡通过本地适用 gate、审查并记录后，才解锁下一张卡。P3-07 的真实设备/人工证据不能由 fake capture、模拟器或编译成功替代。

## 2. 固定顺序

| 顺序 | 任务卡 | 核心交付与验收 |
|---|---|---|
| P3-00 | P2 基线封存与 Phase 3 立项 | 独立提交所有 P2 收尾文件、通过 hosted CI、接受本文件，防止 P2/P3 混合。 |
| P3-01 | 生产 DSP 管线合成 | 生产 analyzer 组合 YIN、48→16 kHz pitch branch、2048/480 full-band spectrum、quality 与 SegmentAggregator；使用真实 100 Hz sample timeline，生产入口通过全部 golden/chunk-invariance。 |
| P3-02 | 有效采集格式与背压合同 | 按 `CaptureSession.effectiveFormat` 初始化 DSP；格式变化、奇数字节、丢样、断点、暂停恢复均显式传播；44.1 kHz 等暂不支持格式明确失败，绝不按 48 kHz 静默分析。 |
| P3-03 | 真实 Coordinator 闭环 | Windows 默认接入 `RecordAudioCapture` 与 `RustAnalysisEngine`；Coordinator 暴露实时帧、采集健康与 worker 指标；保留 fake provider 的测试覆盖。 |
| P3-04 | UI decimator 与 Live UI | 增加 20–30 Hz `UiAnalysisFrame` 与定长 pitch ring；实现目标音、note/cents、RMS、quality chip、暂停/结束；100 Hz 原始帧不得驱动 Riverpod 页面重建。 |
| P3-05 | Windows 录音与持久化升级 | 接入 Native WAV sink、`AppDatabase`、启动恢复；升级 feature BLOB/schema 支持 P2 字段和摘要，提供历史查询、会话/录音删除；失败时保持数据库与录音一致。 |
| P3-06 | 摘要、规则、结果与历史 | Rust segment summary 到 Dart；计算目标命中率，加入质量 gate 与确定性 `ObservationEngine`；完成结果页和最小历史列表。低质量输入仅展示改善录音的方法，不产生强结论。 |
| P3-07 | Windows 故障与性能 Gate | 先以 P3-07P 封存工作树，再按 P3-07A→C 完成远程验收准备；仓库所有者配合执行 P3-07D 实机矩阵后，以 P3-07E 汇总证据。任一子卡未完成都不得通过本卡。 |
| P3-08 | Phase 3 Closure | 全量静态检查、测试、Windows release build、手动矩阵证据及只读架构/隐私审计通过后，才解锁 Android/Web。 |

## 3. 逐卡定义

### P3-00 — P2 基线封存与 Phase 3 立项

**状态：通过（2026-08-06）。**

**范围：** 将 P2-01 至 P2-07 的源码、测试、FRB/Web 生成物、工具与文档作为单一独立提交封存；创建并接受本任务卡文档。没有 Phase 3 产品实现。

**验收：**

- P2 基线提交为 `4832134`（`feat: close Phase 2 DSP MVP`），其工作树与之后的 P3 文档提交分离。
- 本地通过 `dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool`、`flutter analyze`、`flutter test`（45）、`cargo fmt --check --manifest-path rust/Cargo.toml`、`cargo clippy --manifest-path rust/Cargo.toml --all-targets -- -D warnings` 与 `cargo test --manifest-path rust/Cargo.toml`（47）。
- Hosted CI 对 commit `4832134` 全部成功：[Dart and Rust checks](https://github.com/song751/voice-trainer/actions/runs/31072685164)、[Web build](https://github.com/song751/voice-trainer/actions/runs/31072685197)、[Android build](https://github.com/song751/voice-trainer/actions/runs/31072685159)、[Windows build](https://github.com/song751/voice-trainer/actions/runs/31072685171)。
- 本文件经仓库所有者提供的固定卡接受；`AGENTS.md` 明确只允许进入 P3-01。

**未覆盖：** 本卡不重新执行 Windows/Edge 的人工 P2 runtime gate，也不实现任何 P3 功能。

### P3-01 — 生产 DSP 管线合成

**前置：** P3-00 完成。  
**范围：** 仅在 Rust 生产 `RealtimeAnalyzer`/稳定 bridge entry 中组合已验收的 P2 component；不改变 P2 算法阈值和 golden 真值。

**必须交付：**

- 单一生产路径组合 P2 YIN tracker、48→16 kHz pitch branch、48 kHz 2048 Hann/480-hop spectrum、quality 和 `SegmentAggregator`。
- 从单调 `startSample`/sample index 推导真实 100 Hz timeline；禁止合成/重置每批的局部时间轴。
- 把 production output 接到受限 DTO；若本卡需要补充 summary wire contract，保持批量、版本化且不暴露内部 DSP state。
- 新增 production-entry golden 与任意 chunk-split invariance 测试，覆盖 P2-01 全部输入、timeline 与 quality/segment 输出。

**验收：** `cargo test` 中独立 production-entry gate 通过；现有 P2 golden/invariance 全绿；`cargo fmt`、Clippy `-D warnings` 与适用 Flutter mapper 测试通过。记录 production frame sample index、pitch、spectrum、quality/summary 的可比较断言。

**禁止：** 不开始 effective-format 合同、真实采集接线、UI、持久化或规则页工作。

#### P3-01 执行记录（2026-08-06，已接受）

- 范围：将旧 Phase 0 `RealtimeAnalyzerCore` 骨架替换为单一生产组合路径；没有修改采集格式/背压、Coordinator、UI、持久化或规则实现。
- 生产路径：固定 48 kHz，使用 P2 默认 YIN `PitchTracker`（含经验证的 48→16 kHz FIR 分支）、48 kHz 的 2048-sample periodic-Hann / 480-sample-hop full-band `SpectrumAnalyzer`，并以同一 480-sample timeline 合成质量帧与 `SegmentAggregator`。不完整的尾窗不会被填零伪造为分析帧。
- 时间线：桥接稳定入口新增 `push_pcm16_at(startSample, pcm)` / Web Worker `pushPcm16At`。连续批次由显式单调 sample index 校验；输出 frame start、segment start/end 都从该 index 推导，任何批内局部 clock 都不参与。有效格式、typed gap/error 传播仍属于 P3-02，故当前连续性失配会明确拒绝而非静默重置。
- DTO：每帧仍只公开现有的 start sample、level、optional F0/voiced/clarity、固定 8 个频带功率与 quality bitset；没有暴露 FFT、128-bin spectrum、ring buffer 或 pitch tracker state。FRB Dart/Rust 生成物与 Web WASM package 已重新生成。
- 验收测试：新增 `rust/tests/p3_01_production_pipeline.rs`。它对 P2-01 的全部 8 类确定性输入验证 production entry 的整块/任意 chunk split 完全相同、真实 100 Hz（480 sample）时间线、quality/segment summary，以及桥 DTO 与内部 production frame 的可比较字段。另复验稳态/谐波/缺失基频的 YIN 精度、滑音 P95、silence/noise unvoiced、silence/insufficient 与 clipping 质量 gate。
- 实际命令及结果：`cargo fmt --check --manifest-path rust\\Cargo.toml`、`cargo clippy --manifest-path rust\\Cargo.toml --all-targets -- -D warnings`、`cargo test --manifest-path rust\\Cargo.toml`（49 项）均通过；`dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool`（113 files / 0 changed）、`flutter analyze`、`flutter test`（45 项）通过；`flutter_rust_bridge_codegen generate --stop-on-error`、`flutter_rust_bridge_codegen build-web --release`、`node --check web\\analysis_worker.js` 与 `flutter build web --release` 均通过。
- 未覆盖项：本卡没有把 capture 的 `effectiveFormat`、序号缺口、奇数字节、暂停/恢复或 dropped samples 接入生产入口；这些必须由 P3-02 以 typed contract 和额外测试实现，不能将本卡的连续输入断言视为已覆盖。尚未运行真实麦克风或 UI/存储流程。
- 验收状态：仓库所有者已独立接受；P3-02 已解锁。

### P3-02 — 有效采集格式与背压合同

**前置：** P3-01 完成。  
**范围与验收：** 用 `CaptureSession.effectiveFormat` 初始化/验证 DSP，显式处理格式变化、奇数字节、sequence/sample-index 缺口、丢样和暂停恢复。48 kHz/mono/PCM16 以外的当前不支持格式（包括 44.1 kHz）必须返回可映射的 typed failure，不得回退为 48 kHz。测试须验证背压丢弃计数进入 quality/timeline、断点使跨缺口统计失效、恢复后 timeline 不倒退。

#### P3-02 执行记录（2026-08-06，已接受）

- 范围：以 `CaptureSession.effectiveFormat` 创建 `AnalysisConfig`，并将生产 DSP 的 batch 合同扩展为格式、字节对齐、绝对 sample index、丢样和断点的显式事实；未接入默认真实 provider、实时 UI、录音或数据库。
- 有效格式：`AnalysisConfig` 现在保存完整 `CaptureFormat`。`RustAnalysisEngine` 只接受 48 kHz / mono / signed PCM16 LE；44.1 kHz、非单声道或其他编码在初始化前返回 `AnalysisFailureReason.unsupportedFormat`。后续 batch 的格式改变、奇数字节/非完整 frame、回退 sample index 分别返回 `formatChanged`、`invalidPcm`、`nonMonotonicSampleIndex`，没有 48 kHz 静默回退。
- timeline/backpressure：FRB 与 Web Worker 都向 Rust 传递绝对 `startSample` 及断点元数据，不再在 Dart 侧 reset/rebase origin。前进缺口或显式暂停恢复会重启 streaming window、保持 absolute timeline，并把 `discontinuity`、`droppedSamples` 置入首个恢复 frame 和 segment summary；跨断点帧不会进入稳定度统计。Segment 对同一缺口的 index 与显式 drop 事实只计一次。
- Capture application：Coordinator 先获取 `CaptureSession.effectiveFormat` 再初始化 analyzer；恢复后的首个 chunk 标记断点。chunk format 与初始化格式不一致或 health 报告格式变化时，使用 typed `AnalysisFailure(formatChanged)` 终止分析，绝不重解释 PCM。
- 验收测试：新增 Rust `p3_02_capture_contract`，验证 forward gap 的单调恢复、quality mask、准确 dropped count 与 pause/resume 统计失效；Dart 窄测试覆盖不支持格式、奇数字节、格式变化、回退 timeline 与 batch metadata；Windows fake-capture integration 覆盖 effective format、暂停恢复、队列丢弃和格式变化失败。
- 实际命令及结果：`cargo fmt --check --manifest-path rust\\Cargo.toml`、`cargo clippy --manifest-path rust\\Cargo.toml --all-targets -- -D warnings`、`cargo test --manifest-path rust\\Cargo.toml`（51 项）通过；`dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool`（113 files / 0 changed）、`flutter analyze`、`flutter test`（47 项）通过；`flutter test integration_test\\fake_capture_session_flow_test.dart -d windows`（4 项）、FRB generate/build-web、两条 Web worker JS syntax check 与 Flutter Web release build 均通过。Windows native bridge smoke：48,000 samples / 1,024 batch、94 frames、start checksum `2,098,080`、maxBandPowers `8`。
- 未覆盖项：本卡的 fake-capture integration 和 native bridge smoke 不替代 P3-03 的默认 `RecordAudioCapture` 装配，也不替代 P3-07 的真实内置/USB 设备、格式切换、长时间 soak 和故障矩阵。仓库所有者已独立接受，P3-03 已解锁。

### P3-03 — 真实 Coordinator 闭环

**前置：** P3-02 完成。  
**范围与验收：** Windows 默认 provider 使用 `RecordAudioCapture` + `RustAnalysisEngine`；Coordinator 公开 decimated-ready 实时输入、`CaptureHealth` 和 analysis-worker metrics。fake provider 继续作为可替换测试双。集成测试验证默认依赖装配、permission/capture/worker typed failure 路径与 fake flow，且采集不等待 worker、UI、DB 或磁盘。

#### P3-03 执行记录（2026-08-06，已接受）

- 范围：Windows composition root 现在默认选择 `RecordAudioCapture` 和 `RustAnalysisEngine`；其他 native 平台及 Web 仍为明确的 fake fallback，等待各自的设备 gate。录音 sink/repository 仍保持现有 in-memory 实现，未提前开始 P3-05。
- Coordinator：公开 raw realtime `AnalysisFrame` stream、`CaptureHealth` stream 和 domain-level `AnalysisWorkerMetrics` stream。100 Hz frame 只作为下一卡 decimator 的输入，页面尚未监听它。worker supervisor 在初始化、drop、restart/fallback/reset/terminal state 变更时发布 metrics；capture callback 仍只入队，不等待分析、UI、数据库或写盘。
- 失败与测试双：保留所有 provider override/fake 实现；fake integration 覆盖 permission/capture 既有路径、typed analyzer initialization failure、格式变化、暂停恢复、queue drop 和三类 Coordinator stream。新增 Windows integration 在真实插件 runner 中验证默认 provider 类型，避免 Flutter unit runner 缺少 record platform channel 时误报。
- 实际命令及结果：`cargo fmt --check --manifest-path rust\\Cargo.toml`、`cargo clippy --manifest-path rust\\Cargo.toml --all-targets -- -D warnings`、`cargo test --manifest-path rust\\Cargo.toml`（51 项）通过；`dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool`（117 files / 0 changed）、`flutter analyze`、`flutter test`（47 项）通过；`flutter test integration_test\\fake_capture_session_flow_test.dart -d windows`（6 项）、`flutter test integration_test\\p3_03_default_composition_test.dart -d windows`（1 项）和 `flutter build web --release` 均通过。
- 未覆盖项：默认 provider 类型/flow 测试没有开始实际麦克风录制，不能代替 P3-07 的权限、内置/USB、拔插、格式变化和 soak 证据；UI decimation/展示、WAV 持久化与结果规则均仍锁定给后续卡。仓库所有者已独立接受，P3-04 已解锁。

### P3-04 — UI decimator 与 Live UI

**前置：** P3-03 完成。  
**范围与验收：** 定义 20–30 Hz `UiAnalysisFrame` 和固定长度 pitch ring，Live 页面显示目标音、音名/cents、RMS、quality chip、暂停和结束。测试/metrics 证明 100 Hz raw frame 不被 Riverpod 页面监听；UI 仅随 decimated frame 重建。质量 flag 要可见但不作疾病或发声机理推断。

#### P3-04 执行记录（2026-08-06，已接受）

- 范围：新增平台无关的 `UiAnalysisFrame` / `UiPitchPoint`，以及仅按 `sampleIndex` 节流的 `UiFrameDecimator`。它以 48 kHz timeline 的 1,920 samples 间隔发出 25 Hz 快照，原始 pitch 只保留在固定 600-point ring 中；没有修改 capture、DSP、录音、数据库、摘要或规则。
- Riverpod/UI：`liveUiAnalysisFrameProvider` 是唯一供 Live 页面观察的分析 stream，直接消费 decimator 输出；Coordinator 的 100 Hz `realtimeFrames` 只被该 transformer 读取，页面不 watch raw frame 或 PCM。页面显示目标音、当前 note/cents、RMS、描述性质量 chip、固定 ring 的 `CustomPainter`，并保留暂停与结束控制。quality 文案仅解释削波、输入低、缺帧/断点或有效帧不足及改善录音方法，不输出疾病或发声机理结论。
- 验收测试：`ui_frame_decimator_test` 对一秒 100 个 10 ms raw frames 断言仅输出 25 个 UI frames（0…46,080 sample），并验证 ring 固定长度和断点证据；widget test 由 fake capture 驱动 decimated output，断言目标音、A3/+0 cents、RMS、quality、ring 和暂停/结束控件。
- 实际命令及结果：窄测试 `flutter test test\\features\\live_practice\\application\\ui_frame_decimator_test.dart test\\widgets\\app_shell_test.dart`（8 项）通过。全量 `dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool`、`flutter analyze`、`flutter test`（50 项）、`cargo fmt --check --manifest-path rust\\Cargo.toml`、`cargo clippy --manifest-path rust\\Cargo.toml --all-targets -- -D warnings`、`cargo test --manifest-path rust\\Cargo.toml`（51 项）和 `flutter build web --release` 均通过。
- 未覆盖项：本卡未采集真实麦克风、未量测 Windows UI frame time 或端到端延迟；这些仍是 P3-07 的设备/性能证据。Native WAV、数据库/feature BLOB、恢复、删除、结果页、历史及 Observation rules 都仍锁定给 P3-05/P3-06。仓库所有者已独立接受，P3-05 已解锁。

### P3-05 — Windows 录音与持久化升级

**前置：** P3-04 完成。  
**范围与验收：** 接入 Native WAV sink、`AppDatabase` 和启动恢复；feature BLOB/schema 升级为可保存 P2 字段、100 Hz/持久化降采样契约与 summary。实现最小历史查询、会话删除和录音删除。针对 append/finalize/DB transaction/删除的失败注入测试必须证明不会留下错误引用或不可恢复的不一致状态。

#### P3-05 执行记录（2026-08-06，已接受）

- Windows 默认 persistence composition 现在使用懒打开的 native application-support `voice_trainer.sqlite`、`NativeRecordingSink` 和 `NativeRecordingStore`；首次 `RecordingSink.open` 会先运行 incomplete `.partial` 清理与 recording tombstone recovery，采集开始前不接受 PCM。非 Windows/Web 和 provider override 继续使用明确的 in-memory 双。
- 持久化：`FeatureSeriesMetadata` schema 升为 v3，记录 `featureSchemaVersion`。v2 feature series 以 100 Hz shared sample timeline 保存既有 F0/RMS/peak/clarity/voiced/cents/quality 列及 8 个 P2 `band_{0..7}_db` packed BLOB；旧的无频带 v1 series 保持可读。`DriftSessionRepository` 增加最近会话查询、仅删录音与删会话，录音删除先写 tombstone、成功删除 blob 后才删 locator。
- 一致性：录音 append 失败会停止 capture 并 abort partial；finalize 或 DB save 失败会删除/abort 已完成 recording；DB transaction 失败不会留下 session/run/features；blob 删除失败保留 durable tombstone，由下次 recovery 重试。native sink 在 final WAV 已提升后仍可 abort 删除该文件，防止 save 失败留下孤儿。
- 验收测试：新增 P2 8-band round-trip、历史查询、录音删除与会话删除；新增 append/finalize/DB-save 失败注入。既有 native sink/recovery 与 DB foreign-key rollback/tombstone 测试继续覆盖 finalize、DB transaction 与 delete recovery。Windows integration 同时确认默认 capture、DSP 与 native persistence composition。
- 实际命令及结果：`dart run build_runner build --delete-conflicting-outputs`（Drift generated outputs）完成；窄测试 `flutter test test\\infrastructure\\drift_session_repository_test.dart test\\features\\live_practice\\application\\persistence_cleanup_test.dart`（7 项）与 `flutter test integration_test\\p3_03_default_composition_test.dart -d windows`（1 项）通过。全量 `dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool`（124 files / 0 changed）、`flutter analyze`、`flutter test`（55 项）、`cargo fmt --check --manifest-path rust\\Cargo.toml`、`cargo clippy --manifest-path rust\\Cargo.toml --all-targets -- -D warnings`、`cargo test --manifest-path rust\\Cargo.toml`（51 项）和 `flutter build web --release` 均通过。
- 未覆盖项：没有用真实麦克风写入真实会话，亦未验证升级前真实磁盘数据库的 migration fixture；P3-07 的磁盘失败、崩溃恢复及 30 分钟设备 soak 仍不可由 fake、Windows runner 或构建替代。结果页、命中率和 Observation rules 已由 P3-06 承接。仓库所有者已接受，P3-06 已解锁。

### P3-06 — 摘要、规则、结果与历史

**前置：** P3-05 完成。  
**范围与验收：** 将 Rust segment/session summary 映射到 Dart，按目标练习计算命中率，实施 quality gate 和确定性 `ObservationEngine`，完成结果页及最小历史列表。所有 Observation 必含证据、质量 flags、范围和置信度；低质量或有效帧不足时只给改善录音的建议，不输出强结论或医疗/生理断言。为 hit rate、quality suppression、规则确定性和历史读取添加测试。

#### P3-06 执行记录（2026-08-06，已接受）

- Rust finalization bridge 现在返回受限 `SegmentSummaryDto`：frame/valid-frame count、dropped samples、quality flags、pitch/level robust stability 与 onset delay；每帧桥 DTO 仍只包含既有 8 个频带和标量，不泄露 DSP state。FRB 与 dedicated Web Worker 都在 `finish` 时映射该摘要到 Dart。
- Dart 按练习目标的 MIDI cents/tolerance 从有效、连续的 voiced frames 计算 hit rate；频率到 cents 使用 A4=440 Hz 的 MIDI 基准，避免直接把 Hz 对数同 MIDI cents 混用。summary 和统计值以兼容的 JSON 字段随 session 保存；Drift schema 升为 v4，旧记录安全回退到空的扩展摘要。
- `DeterministicObservationEngine` 的 quality gate 先于任务规则运行。只要有效帧不足、quality flags 非空或无可计算命中率，就只输出“录音质量受限”这一受抑制观察和改善录音建议；不会输出发声机理、医疗或强结论。合格输入仅给出描述性的目标对齐观察及可重复目标音练习建议。
- 结果页展示有效帧、目标命中率、质量说明、观察和下一步；历史页从 repository 的最近会话查询读取最小列表与命中率。未将 100 Hz 帧、PCM 或逐帧 SQL 接入页面。
- 实际命令及结果：`dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool`、`flutter analyze`、`flutter test`（58 项）、`cargo fmt --check --manifest-path rust\\Cargo.toml`、`cargo clippy --manifest-path rust\\Cargo.toml --all-targets -- -D warnings`、`cargo test --manifest-path rust\\Cargo.toml`（52 项）、FRB generate/build-web、两条 Web worker JS syntax check 与 `flutter build web --release` 均通过。
- 未覆盖项：没有把 fake/构建结果当作真实 Windows microphone、设备故障、磁盘失败、crash recovery、soak 或性能证据。结果/历史也尚未实现个人基线或同任务趋势。仓库所有者已接受，P3-07 已解锁。

### P3-07 — Windows 故障与性能 Gate

**前置：** P3-06 完成。  
**范围与验收：** 在 Windows 内置麦克风与 USB 麦克风各记录一份可复核矩阵，覆盖权限拒绝、无设备、拔插、格式变化、暂停恢复、磁盘失败和崩溃恢复。完成至少 30 分钟连续采集 soak，记录 P50/P95 端到端延迟、丢样率、UI frame time、内存趋势和设备/驱动/有效格式（脱敏）。任何未通过或未测项必须明确列出，不能用 fake capture、模拟器或构建成功替代。

#### P3-07 执行记录（2026-08-06，进行中）

- 实机发现并明确选择 Realtek 内置麦克风阵列和 USB Audio 麦克风；两者请求/有效格式均为 mono PCM16 / 48 kHz，处理开关均为 AGC/echo/noise suppression off。设备唯一 ID、PCM 与录音内容不写入仓库。
- Realtek 短采集（10 秒）：样本误差 0%、chunk interval P95 47.437 ms、callback work P95 43 µs，但发现一次 169.969 ms 的间隔代理断点；该次结果不能作为连续稳定度或无断点通过证据。
- USB 采集（60 秒活动 + 5 秒暂停）：样本误差 0.2167%、interval P95 47.587 ms、callback work P95 35 µs、0 odd bytes、0 discontinuity proxy；pause/resume 调用 0.629/0.723 ms。短采集确认 USB first-chunk latency 295.726 ms；不把 capture first-chunk latency 误称为端到端 DSP/UI latency。
- 物理拔下 USB 后，Windows endpoint 枚举不再包含 USB Audio；以先前保存的选择启动真实 capture inspector 返回明确的 “Requested input device was not found”，确认设备消失不会被静默回退至默认输入。该检查器的 auto-exit error path 已修复，便于可重复收集失败证据。
- USB 回插并由 Windows 重新枚举为正常 endpoint 后，以同一显式设备选择完成 10 秒恢复采集：48 kHz/mono/PCM16、样本误差 0.2%、interval P95 47.276 ms、callback work P95 46 µs、0 discontinuity proxy。该记录确认拔插后的恢复路径；不把它扩大为磁盘、崩溃或端到端 UI/DSP 的恢复证据。
- USB 30 分钟连续采集：显式 USB 设备、48 kHz/mono/PCM16、处理开关关闭，capture inspector 正常结束并写出 WAV；其 data chunk 为 172,800,000 bytes，按 48,000 × 1 × 2 bytes/s 独立复核为恰好 1,800 秒。该检查器在结束时拼接并写 WAV，故它自己的末段 working set（第 26 至 30 分钟）从约 418 MiB 到 435 MiB、private memory 从约 397 MiB 到 412 MiB；这是 inspector 暂存原始 PCM 的预期趋势，不作为正式 streaming recorder 的内存通过结论。临时录音不纳入仓库。
- 枚举为 44.1 kHz 的另一真实输入在请求 48 kHz 后仍交付 48 kHz/mono/PCM16 输出（10 秒样本误差 0.0071%、0 discontinuity proxy）。这暴露出驱动/插件可能重采样；不能证明 production `effectiveFormat` 的格式变化通知，也不能把它记为不支持格式的拒绝通过。
- 未完成：权限拒绝/撤回、无设备、格式变化、真实磁盘失败、crash/restart、端到端 P50/P95、正式 Live UI frame time、正式录音链路内存趋势。以上必须通过真实设备/人工操作补齐，当前不解锁 P3-08。

#### P3-07 剩余子卡与执行规则

现有实机结果保持有效，不要求重做已经可复核的 USB 拔插、回插恢复和 30 分钟 capture-only 采集。剩余工作按下列顺序执行。`P3-07A` 至 `P3-07C` 只为实机验收提供可复核工具，不能把自动化结果写成设备通过；`P3-07D` 是唯一需要仓库所有者在电脑旁操作的子卡。

| 顺序 | 子卡 | 执行条件 | 状态 |
|---|---|---|---|
| P3-07P | 已接受 P3 工作树核验与封存 | 远程可执行，不新增功能 | 已接受 |
| P3-07A | 证据合同与 Windows gate runner | P3-07P 接受后，远程可执行 | 已接受 |
| P3-07B | 正式产品链路性能观测 | P3-07A 接受后，远程可执行 | **当前解锁** |
| P3-07C | 真实故障 runbook 与安全 gate hook | P3-07B 接受后，远程可执行 | 锁定 |
| P3-07D | Windows 实机剩余矩阵 | P3-07C 接受且仓库所有者在电脑旁 | **外部条件阻塞** |
| P3-07E | 证据校验与 P3-07 结论 | P3-07D 产生完整原始报告后，远程可执行 | 锁定 |

### P3-07P — 已接受 P3 工作树核验与封存

**目标结果：** 在开始任何新实现前，核对当前大量未提交文件确实属于已接受的 P3-01→P3-06、P3-07 已记录的部分实机/inspector 工作和本轮任务规划；运行完整回归并形成可追溯 checkpoint，避免后续 Android/UI/Web 改动与整段 P3 混在一起。

#### P3-07P 执行记录（2026-08-07，已接受）

- 核对基线 `11265a3` 的 65 项未提交改动：62 项 P3-01→P3-06 production/test/generated 文件已作为 `1133e5e`（`feat: checkpoint accepted Phase 3 implementation`）封存；其余为 P3-07 capture-inspector error auto-exit、已取得的脱敏 Windows 部分证据、P3-07 子卡/Phase 4 规划和状态文档。本次未发现将录音、数据库、绝对用户路径、设备唯一 ID、缓存或 build output 加入 Git 的候选文件；`build/`、`logs/`、`.dart_tool/` 和 IDE/Android runtime 输出保持忽略。
- 实际回归均针对封存候选运行并通过：Dart format（129 files / 0 changed）、`flutter analyze`、`flutter test`（58 项）；Rust fmt、clippy `-D warnings`、`cargo test`（52 项）；Windows fake capture integration（6 项）与默认 production composition integration（1 项）；FRB generate/build-web、Web artifact validator、两条 Web worker JavaScript syntax check、Flutter Web release 与 Windows release。
- FRB generated Dart/Rust/Web JS/WASM 文件以 SHA-256 在连续一次 generate + build-web 后保持一致；Web validator 确认 WorkerRealtimeAnalyzer binding 与 338,790-byte WASM payload。FRB/Web 构建中的 nightly atomics warning 和 Cargo optional package-metadata warning 未影响退出状态，保留为既有工具链提示，未扩大解释为设备证据。
- 本条记录及剩余 P3-07 partial evidence/planning 已在独立 documentation checkpoint 封存。P3-07A 现为当前唯一允许执行的子卡；P3-07D/P3-08 与所有真实设备 Gate 仍 Pending。

**允许修改：** 仅修复格式/生成物漂移或回归 gate 暴露的、阻止既有 P3 行为通过的问题；状态/执行记录可按实际结果更正。允许按逻辑范围暂存并创建清晰 commit。

**禁止修改：** 新功能、算法/阈值、schema 扩张、Android/Web production promotion、UI 扩张；不得丢弃、覆盖或 reset 任何用户改动，不得把 P3-07 未完成项写成通过。

**必须完成：**

- 逐项分类 `git status`/diff：P3-01→06 production、generated files、P3-07 partial evidence、规划文档、意外 build/runtime artifact。
- 运行 AGENTS 标准 Dart/Rust gate、适用 Windows integrations、FRB generate/build-web、Web artifact checks和Windows release build；记录实际数量/结果。
- 确认生成文件来自同一次锁定工具链生成且二次生成无意外漂移；确认没有录音、数据库、绝对用户路径、设备 ID、缓存或 build output 被纳入。
- 形成至少一个名称不宣称 P3-07/Phase3 closure 的 checkpoint commit；若需要多个 commit，按“P3-01→06实现/生成物”“P3-07 partial证据与规划”分离。提交前后记录 commit和剩余工作树状态。

**失败处理：** gate失败时只做最小修复并重跑受影响/全量gate；若改动归属无法确认，停止并报告，不猜测删除。P3-07P未接受前不开始P3-07A。

### P3-07A — 证据合同与 Windows gate runner

**目标结果：** 建立一个版本化、机器可读且不含隐私数据的 P3-07 报告合同与校验 runner，使后续每次实机操作都能产生相同字段和明确的 pass/fail/pending，而不是靠聊天记录验收。

#### P3-07A 执行记录（2026-08-07，已接受）

- 新增 `docs/specs/P3_07_EVIDENCE_V1.md`、`tool/p3_07_evidence.dart` 与 `tool/p3_07_evidence_runner.dart`。合同固定 commit、日期、build mode、已知场景、脱敏设备类别、请求/有效 PCM16LE 格式、处理开关、时长/样本/丢样/断点、pipeline/UI P50/P95、内存样本、结果和未覆盖原因；禁止 PCM、设备 ID、用户备注和绝对路径。
- runner 提供 `create`、`merge`、`validate`；其 `tool/p3_07_fixtures/partial_capture.json` 只迁入可证明的 USB capture-only 与拔插恢复字段，所有 product-pipeline 结果保持 `pending`。`invalid_privacy.json` 是故意损坏 fixture，包含禁止字段，必须非零退出。
- 实际命令：`dart format --output=none --set-exit-if-changed tool test`（22 files / 0 changed）、`flutter analyze`、`flutter test`（62 项）和 `dart run tool/p3_07_evidence_runner.dart validate tool/p3_07_fixtures/partial_capture.json` 均通过；对 `invalid_privacy.json` 的 validate 非零退出。未将 synthetic/capture-only 解释为 real-device pass。

**允许修改：** `tool/` 下新建的 P3-07 runner/validator、对应 `test/`、`docs/specs/`、`docs/test-matrices/windows.md` 与本文件。

**禁止修改：** 生产 capture/DSP/数据库/UI 行为、算法阈值、Drift schema、FRB DTO、平台默认 provider；不得采集或提交 PCM、设备唯一 ID、完整录音路径和用户名。

**必须交付：**

- `P3_07_EVIDENCE_V1` 合同，至少包含 commit、日期、release/debug、场景 ID、脱敏设备类别、请求/有效格式、处理开关、持续时间、样本/丢弃/断点、延迟 P50/P95、UI build/raster P95、内存采样、结果与未覆盖原因。
- runner 能创建空白场景清单、合并单场景 JSON、验证必填字段/单位/分位数/隐私禁项，并在缺项或阈值失败时返回非零退出码。
- 已有 P3-07 结果只迁移能被当前记录证明的字段；其余保持 `pending`，不得补猜数据。
- 单元测试覆盖 schema version、未知场景、缺字段、非法分位数、设备 ID/绝对路径泄漏和 pending 不得计为 pass。

**验收：** `dart format --output=none --set-exit-if-changed tool test`、相关 `flutter test`、`dart run tool/<runner> validate <fixture>` 通过；损坏 fixture 必须失败。执行记录写明实际文件名和命令后才解锁 P3-07B。

### P3-07B — 正式产品链路性能观测

**目标结果：** 在显式 gate 模式下，从 production `RecordAudioCapture` → bounded queues → Rust DSP → 25 Hz UI → streaming WAV/Drift 路径收集可关联的性能数据；默认产品运行不增加敏感日志或无限缓存。

**允许修改：** `lib/infrastructure/audio/`、`lib/features/live_practice/` 中独立的 metrics adapter、`lib/core/` 中不含插件依赖的 metrics value object、`tool/`、`integration_test/` 和测试。若必须改既有 DTO，只能增加 gate-local 映射，不扩大 FRB 实时 payload。

**禁止修改：** DSP 算法、Observation 规则、持久化 schema、产品页面功能、默认 25 Hz/600-point ring、有界队列策略；不得以 wall clock 代替 sample-index 分析时间线。

**必须交付：**

- 用 sample index 关联 capture monotonic time、analysis publish、decimated UI delivery 和已绘制 frame；明确区分“软件管线延迟”与无法仅靠应用测出的声学/显示外部延迟。
- 使用 Flutter frame timings 记录 build/raster P50/P95；记录 analysis/recording queue drop、worker 状态和正式 streaming recorder 的定期 working-set/private-memory 样本。
- gate 模式输出 P3-07A 合同；内存只保留固定窗口/在线分位统计，30 分钟运行本身不得形成无限列表。
- fake-clock/integration 测试证明关联、分位数、断点、缺帧与报告单位正确；关闭 gate 时无报告文件和额外逐帧日志。

**硬门槛：** 原生稳定音到有效 UI F0 的最终实机 Gate 为 P50 ≤120 ms、P95 ≤180 ms；10 分钟 dropped samples <0.1%；UI build+raster P95 <16 ms；30 分钟无增长性内存泄漏。P3-07B 只验证测量可信，不冒充这些实机门槛已通过。

**验收：** 相关窄测试、`flutter analyze`、`flutter test` 和 Windows release build 通过；生成的 synthetic 报告能被 P3-07A validator 接受后才解锁 P3-07C。

### P3-07C — 真实故障 runbook 与安全 gate hook

**目标结果：** 把剩余人工场景写成一次可完成、可恢复的操作手册，并只在确有必要时增加显式 gate-only 注入点/录音根目录 override；真实故障仍由 P3-07D 产生，fake/注入仅验证应用预期状态。

**允许修改：** `tool/` 下 P3-07 启动/收集脚本、`integration_test/`、`test/`、明确隔离的 gate configuration、`docs/test-matrices/windows.md` 和本文件。

**禁止修改：** 默认存储位置、用户真实文件、系统权限/设备设置的自动修改、静默删除、生产安全文案和失败语义。脚本不得自动禁用设备、切换全局权限或删除宽泛目录。

**必须交付：**

- 对权限初始拒绝、运行中撤回、全部输入端点不可用、活动 USB 拔出/回插、可观察的有效格式变化、真实写盘中断、进程强制结束/重启恢复逐项给出前置、人工动作、期望 typed 状态、证据文件、清理步骤和停止条件。
- 磁盘场景只能使用用户明确指定的可丢弃目录/可移除介质；runner 在开始前打印并确认解析后的绝对目标，拒绝 workspace 根、用户主目录、盘符根和未解析变量。
- crash 场景只终止本应用测试进程；重启后验证 `.partial` 清理、tombstone/DB 引用一致性和既有历史不丢失。
- 自动化复验 permission/capture/format/recording/recovery 的 typed 映射，但报告固定标为 `synthetic`，validator 禁止其满足 `real_device_required` 场景。

**验收：** 所有脚本支持 dry-run，危险目标被拒绝；相关测试、`flutter analyze`、`flutter test` 通过。仓库所有者确认操作手册可执行后，P3-07D 进入“等待现场”状态。若仓库所有者仍不在电脑旁，可从 `docs/PHASE4_TASKS.md` 的 P4-00 开始远程实现路径；这不解锁 P3-07E/P3-08，也不把 P3-07D 记为通过。

### P3-07D — Windows 实机剩余矩阵（需仓库所有者在电脑旁）

**目标结果：** 使用 P3-07A→C 产物补齐剩余真实设备/真实故障/正式产品链路证据。Terra 负责逐步提示、启动命令、读取报告和即时判定；仓库所有者只执行物理拔插、Windows 设置、发声/播放测试音及故障介质操作。

**必须完成：**

- 权限初始拒绝与运行中撤回；所有输入端点不可用；活动 USB 拔出后的错误与回插恢复。
- 尝试造成并观察有效格式变化；若 Windows/驱动始终重采样为 48 kHz，必须记录“平台不可观察”证据与插件限制，不能写成 format-change pass，并在 P3-07E 决定是否需要 ADR。
- 对明确的可丢弃记录目标制造真实写入失败；验证采集停止/错误可见、无坏 locator、临时文件可恢复或可清理。
- 正式应用录音中强制结束进程并重启；验证旧会话、partial、tombstone 与数据库一致性。
- 正式 production 链路完成内置和 USB 的短矩阵，以及至少一次 30 分钟 soak；输出软件管线 P50/P95、丢样率、UI build/raster P95 和流式录音内存趋势。已有 capture-only 30 分钟记录保留为辅助证据，但不替代此项。

**现场通过门槛：** 使用蓝图第 12 节原生指标；任何 `pending`、synthetic、debug-only 或 capture-only 报告都不能满足对应项。不得提交录音内容；只提交 validator 通过的脱敏 JSON/Markdown 摘要。

### P3-07E — 证据校验与 P3-07 结论

**目标结果：** 在不再操作设备的情况下校验 P3-07D 原始报告、更新 Windows 矩阵/研究记录，并给出通过、失败或需要 ADR 的逐项结论。

**允许修改：** P3-07 报告 validator、报告摘要、`docs/RESEARCH_NOTES.md`、`docs/test-matrices/windows.md`、本文件、`README.md` 和 `AGENTS.md`。

**禁止修改：** 为了让指标变绿而改生产实现、测试阈值或原始证据；失败项必须留在 P3-07 或另立修复卡后重跑，不得直接解锁 P3-08。

**验收：** validator 对完整 evidence bundle 退出 0；矩阵每个必需场景只有 pass/fail，无 pending；所有门槛和未覆盖项可追溯。仓库所有者独立接受后才将 P3-07 标为完成并解锁 P3-08。

### P3-08 — Phase 3 Closure

**前置：** P3-07 完成。  

**目标结果：** 在不增加产品功能的前提下正式关闭可复现的 Windows Phase 3 基线，完成全量构建/测试、证据索引和只读架构/隐私审计。P4-00→P4-13 若已按远程例外执行，不需要回退；P3-08 接受后移除其“provisional”状态，并成为 P4-16 Closure 的硬前置。

**允许修改：** closure/CI 问题所需的独立修复卡文档、`AGENTS.md`、`README.md`、`RESEARCH_NOTES.md`、本文件、Windows 矩阵和证据索引。若审计发现源码问题，本卡只记录并另立小卡，不在 closure 审计中顺手修复。

**禁止修改：** DSP 阈值、产品功能、数据库 schema、平台 composition 和 Phase 4 代码；不得删除失败证据、降低门槛或用旧构建替代当前 commit。

**必须运行：**

- `dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool`
- `flutter analyze`
- `flutter test`
- 适用的 Windows integration tests
- `cargo fmt --check --manifest-path rust\Cargo.toml`
- `cargo clippy --manifest-path rust\Cargo.toml --all-targets -- -D warnings`
- `cargo test --manifest-path rust\Cargo.toml`
- `flutter_rust_bridge_codegen generate` 及仓库约定的 Web artifact/drift 检查
- `flutter build windows --release`

**只读审计清单：** presentation/application/domain/infrastructure 依赖方向；capture callback/queues 不等待 UI/DB/磁盘分析；UI 不监听 PCM/100 Hz raw stream；无逐帧 SQL/无限 ring；日志和 P3-07 报告不含 PCM、完整路径、设备唯一 ID或用户备注；quality gate 先于解释规则；所有文案保持描述性、非医疗；录音/数据库删除与崩溃恢复可追溯。

**验收：** 当前 commit 的本地 gate、Windows release 与 hosted CI 全绿；P3-07 evidence bundle validator 通过；审计发现为 0 个未解决 blocker/high issue。记录命令、版本、commit、artifact hash、未覆盖平台和证据链接，由仓库所有者独立接受。完成后可将已执行的 P4-00→P4-13 从 provisional 更新为正式 Phase 4 基线，但仍不能跳过 P4-14/P4-15。

## 4. 交接提示

下一位 agent 必须完整阅读 `AGENTS.md`、`docs/PROJECT_BLUEPRINT.md`、`docs/IMPLEMENTATION_PLAYBOOK.md`、`docs/FILE_MANIFEST.md`、`docs/RESEARCH_NOTES.md`、本文件和 `docs/PHASE4_TASKS.md`。当前只执行 P3-07P；先分类现有改动、运行全量 gate 并形成不宣称 P3 closure 的 checkpoint。禁止新增功能或提前开始 P3-07A+。只有 P3-07P、P3-07A→C 逐卡接受后，才可在现场仍不可用时进入 P4-00。
