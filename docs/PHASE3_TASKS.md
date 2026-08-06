# Phase 3 固定任务卡

更新时间：2026-08-06  
状态：**已接受。P3-00 已完成；当前只允许执行 P3-01。**

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
| P3-07 | Windows 故障与性能 Gate | 用内置与 USB 麦克风覆盖权限拒绝、无设备、拔插、格式变化、暂停恢复、磁盘失败、崩溃恢复；完成 30 分钟 soak、P50/P95 延迟、丢样率、UI frame time、内存记录。 |
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

### P3-02 — 有效采集格式与背压合同

**前置：** P3-01 完成。  
**范围与验收：** 用 `CaptureSession.effectiveFormat` 初始化/验证 DSP，显式处理格式变化、奇数字节、sequence/sample-index 缺口、丢样和暂停恢复。48 kHz/mono/PCM16 以外的当前不支持格式（包括 44.1 kHz）必须返回可映射的 typed failure，不得回退为 48 kHz。测试须验证背压丢弃计数进入 quality/timeline、断点使跨缺口统计失效、恢复后 timeline 不倒退。

### P3-03 — 真实 Coordinator 闭环

**前置：** P3-02 完成。  
**范围与验收：** Windows 默认 provider 使用 `RecordAudioCapture` + `RustAnalysisEngine`；Coordinator 公开 decimated-ready 实时输入、`CaptureHealth` 和 analysis-worker metrics。fake provider 继续作为可替换测试双。集成测试验证默认依赖装配、permission/capture/worker typed failure 路径与 fake flow，且采集不等待 worker、UI、DB 或磁盘。

### P3-04 — UI decimator 与 Live UI

**前置：** P3-03 完成。  
**范围与验收：** 定义 20–30 Hz `UiAnalysisFrame` 和固定长度 pitch ring，Live 页面显示目标音、音名/cents、RMS、quality chip、暂停和结束。测试/metrics 证明 100 Hz raw frame 不被 Riverpod 页面监听；UI 仅随 decimated frame 重建。质量 flag 要可见但不作疾病或发声机理推断。

### P3-05 — Windows 录音与持久化升级

**前置：** P3-04 完成。  
**范围与验收：** 接入 Native WAV sink、`AppDatabase` 和启动恢复；feature BLOB/schema 升级为可保存 P2 字段、100 Hz/持久化降采样契约与 summary。实现最小历史查询、会话删除和录音删除。针对 append/finalize/DB transaction/删除的失败注入测试必须证明不会留下错误引用或不可恢复的不一致状态。

### P3-06 — 摘要、规则、结果与历史

**前置：** P3-05 完成。  
**范围与验收：** 将 Rust segment/session summary 映射到 Dart，按目标练习计算命中率，实施 quality gate 和确定性 `ObservationEngine`，完成结果页及最小历史列表。所有 Observation 必含证据、质量 flags、范围和置信度；低质量或有效帧不足时只给改善录音的建议，不输出强结论或医疗/生理断言。为 hit rate、quality suppression、规则确定性和历史读取添加测试。

### P3-07 — Windows 故障与性能 Gate

**前置：** P3-06 完成。  
**范围与验收：** 在 Windows 内置麦克风与 USB 麦克风各记录一份可复核矩阵，覆盖权限拒绝、无设备、拔插、格式变化、暂停恢复、磁盘失败和崩溃恢复。完成至少 30 分钟连续采集 soak，记录 P50/P95 端到端延迟、丢样率、UI frame time、内存趋势和设备/驱动/有效格式（脱敏）。任何未通过或未测项必须明确列出，不能用 fake capture、模拟器或构建成功替代。

### P3-08 — Phase 3 Closure

**前置：** P3-07 完成。  
**范围与验收：** 运行 AGENTS.md 所列完整静态检查和测试，构建 Windows release，收集 P3-07 手动矩阵；进行只读架构/隐私审计，检查层级依赖、音频/身份信息日志脱敏、无逐帧 SQL、无阻塞采集回调、质量 gate 和安全文案。只有所有证据通过且记录未覆盖项后，才在文档中解锁 Android/Web。

## 4. 交接提示

下一位 agent 必须完整阅读 `AGENTS.md`、`docs/PROJECT_BLUEPRINT.md`、`docs/IMPLEMENTATION_PLAYBOOK.md`、`docs/FILE_MANIFEST.md`、`docs/RESEARCH_NOTES.md` 和本文件。当前只执行 P3-01；先建立 production pipeline 的可比较测试，再修改实现。禁止把 P3-02+ 的采集、UI、持久化或规则改动混入本卡。
