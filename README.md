# 练声助手（工作名）

这是一个面向 Windows、Android、Web，并逐步覆盖 macOS、iOS、Linux 的本地优先练声应用规划仓库。

当前状态：**Phase 1 与 Closure C1–C4 已全部完成**。可信仓库基线、生成物策略、日志脱敏、统一错误映射、真实 Edge dedicated worker、Windows/Edge 数值对比、录音恢复、feature-series 无损 round-trip、Web OPFS 和 hosted CI 均已有证据。Phase 2 已解锁，但下一张只允许执行 `P2-01` 确定性信号与 golden harness；不得直接开始 MPM/YIN、频谱或重采样实现。

应用提供可覆盖的 audio capture、analysis engine、recording sink/store 和 session repository provider，默认接入确定性 fake session；最小导航包含首页、实时练习、结果、历史和设置。它不直接在页面中引用 `record`、Drift 或 FRB，也不恢复 FRB 2.12 默认 WASM WorkerPool。Gate 0A–0E 的实测证据及 Phase 1 决策见 `docs/RESEARCH_NOTES.md` 和 `docs/adr/0001-frb-2-12-phase0-compatibility.md`。

## 文档入口

后续开发 Agent 必须按顺序阅读：

1. [`AGENTS.md`](AGENTS.md)：仓库内不可违反的工程约束。
2. [`docs/PROJECT_BLUEPRINT.md`](docs/PROJECT_BLUEPRINT.md)：产品范围、总体架构、DSP 与数据设计。
3. [`docs/IMPLEMENTATION_PLAYBOOK.md`](docs/IMPLEMENTATION_PLAYBOOK.md)：阶段任务、命令、验收门槛和模型使用建议。
4. [`docs/FILE_MANIFEST.md`](docs/FILE_MANIFEST.md)：计划目录树及每个文件的职责。
5. [`docs/RESEARCH_NOTES.md`](docs/RESEARCH_NOTES.md)：选型证据、本机检查结果、待验证假设。
6. [`docs/PHASE1_CLOSURE_PLAN.md`](docs/PHASE1_CLOSURE_PLAN.md)：Phase 1 审计结论、收尾任务卡和 Phase 2 解锁顺序。

桌面上的原始 `WINDOWS_CODEX_FLUTTER_AGENT_GUIDE.md` 是需求来源。若它与本仓库文档冲突，以本仓库文档为准。

## 已定技术方向

- Flutter 负责 UI、流程、状态管理、规则编排和本地数据访问。
- `record` 作为首个六平台 PCM 采集适配器，但必须通过 Phase 0 的延迟、格式和丢帧测试；不合格才开发联邦音频插件。
- Rust 负责实时/离线 DSP；原生通过 `flutter_rust_bridge`，Web 通过单线程 Rust WASM，避免在 UI isolate 上运算。
- 采集保持 48 kHz、单声道、PCM16。频谱使用全带宽分支，音高分支经过抗混叠降采样，不能把整条链路直接降到 16 kHz。
- Drift/SQLite 只存元数据、摘要和列式 BLOB；不逐帧插入数据库。录音使用独立 BlobStore。
- MVP 只给“观察结果”和训练建议，不做医疗诊断，不自动断言声带损伤、疲劳、漏气或挤压。

## 当前机器前置条件

2026-08-03 Phase 0 实测：Flutter 3.44.7、Dart 3.12.2、Visual Studio 2022、Windows/Edge、Rust 1.97.1、Android SDK 36、JDK 17、`wasm32-unknown-unknown`、FRB 和 `wasm-pack 0.15.0` 均已可用；全部现有静态检查和测试通过。Windows FFI 与 Edge 单线程 Rust WASM 均实际返回 `Hello, Tom!`，Android debug APK 也已完成一次全量构建。Gradle 下载仍受本机间歇性 TLS/代理故障影响；复现、缓解参数与不可绕过的安全边界见研究记录。

## 下一步

继续按 [`docs/PHASE1_CLOSURE_PLAN.md`](docs/PHASE1_CLOSURE_PLAN.md) 的固定顺序执行 `P2-01`。本卡只建立确定性信号、参数/哈希 manifest 和 golden harness，不修改生产 pitch/spectrum 算法；达到本卡 gate 并记录证据后才允许进入 `P2-02`。真实麦克风覆盖继续按 [`docs/test-matrices/`](docs/test-matrices/) 中的平台矩阵进行；不要用 fake capture、emulator 或构建成功冒充真实设备通过。
