# 练声助手（工作名）

这是一个面向 Windows、Android、Web，并逐步覆盖 macOS、iOS、Linux 的本地优先练声应用规划仓库。

当前状态：**Phase 1 与 Closure C1–C4、P2-01 至 P2-07，以及 Phase 3 的 P3-00 至 P3-06、工作树 checkpoint `P3-07P`、证据合同 `P3-07A`、性能观测 `P3-07B` 和故障运行手册 `P3-07C`，以及 P4-00 至 P4-02 均已形成可复验基线；P4-03 Android capture/DSP production composition 已完成，等待集成接受**。Android 当前默认使用 record + native Rust worker，但持久化仍保持 fallback，P4-04 前不宣称 durable save/recovery。模拟器 integration 可用 `tool/p4_03_android_permission_test.ps1 -Endpoint 127.0.0.1:16384 -Permission allow` 由标准 SDK ADB 自动授予录音权限，不需要 root；`deny` 同样可自动覆盖拒绝路径。仓库所有者于 2026-08-26 授权在保持文件边界和证据真实性的前提下并行推进可独立工作。`P3-07D`、Android 真机、真实浏览器麦克风和最终 Closure 仍明确阻塞，任何模拟器/root/fake 结果都不能替代。

首页现提供“导入歌曲并准备原唱对比”入口：可跨平台选择本地音频、确认处理权利，并走 typed 分离任务合同。当前生产构建尚未包含通过数值/许可 gate 的模型 runtime，因此会诚实显示 unavailable；开发期 UMX-HQ oracle 与部署研究位于 `tool/song_separation/`，不会用伪 stem 冒充自动分离成功。

应用提供可覆盖的 audio capture、analysis engine、recording sink/store 和 session repository provider，默认接入确定性 fake session；最小导航包含首页、实时练习、结果、历史和设置。它不直接在页面中引用 `record`、Drift 或 FRB，也不恢复 FRB 2.12 默认 WASM WorkerPool。Gate 0A–0E 的实测证据及 Phase 1 决策见 `docs/RESEARCH_NOTES.md` 和 `docs/adr/0001-frb-2-12-phase0-compatibility.md`。

## 文档入口

后续开发 Agent 必须按顺序阅读：

1. [`AGENTS.md`](AGENTS.md)：仓库内不可违反的工程约束。
2. [`docs/PROJECT_BLUEPRINT.md`](docs/PROJECT_BLUEPRINT.md)：产品范围、总体架构、DSP 与数据设计。
3. [`docs/IMPLEMENTATION_PLAYBOOK.md`](docs/IMPLEMENTATION_PLAYBOOK.md)：阶段任务、命令、验收门槛和模型使用建议。
4. [`docs/FILE_MANIFEST.md`](docs/FILE_MANIFEST.md)：计划目录树及每个文件的职责。
5. [`docs/RESEARCH_NOTES.md`](docs/RESEARCH_NOTES.md)：选型证据、本机检查结果、待验证假设。
6. [`docs/PHASE1_CLOSURE_PLAN.md`](docs/PHASE1_CLOSURE_PLAN.md)：Phase 1 审计结论和已关闭的 Phase 2 历史记录。
7. [`docs/PHASE3_TASKS.md`](docs/PHASE3_TASKS.md)：Phase 3 固定任务卡、依赖关系与逐卡验收标准。
8. [`docs/PHASE4_TASKS.md`](docs/PHASE4_TASKS.md)：授权的远程 Android emulator/UI/Web 路径，以及锁定的真实设备 Gate。

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

按 [`docs/PHASE3_TASKS.md`](docs/PHASE3_TASKS.md) 在仓库所有者电脑旁时执行 `P3-07D`；否则可进入 [`docs/PHASE4_TASKS.md`](docs/PHASE4_TASKS.md) 的 `P4-00`，按卡推进到 `P4-13`。不得并行混合两张卡，也不得把 MuMu 模拟器证据写成 Android 真机通过。
