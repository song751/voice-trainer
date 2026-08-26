# 练声助手（工作名）

这是一个面向 Windows、Android、Web，并逐步覆盖 macOS、iOS、Linux 的本地优先练声应用规划仓库。

当前状态：**P4-00 至 P4-12 已形成可复验实现；P4-13 的 release workflow、许可 NOTICE、同一候选的 Windows/Web/Android release、竖屏 emulator 600 秒 bundle 与零 high 审计均已通过，当前只等待 hosted CI 接受**。Android 默认使用 `record` + native Rust worker + native Drift/WAV persistence；Web 默认使用 `record_web` + dedicated single-thread Rust WASM worker、Drift shared IndexedDB 与 OPFS recording store，并有自包含 CSP deployment gate。歌曲分离在 Windows/Android native 使用 Git 外固定哈希模型与 typed capability probe，Web 明确 unavailable。`P3-07D`、P4-14 Android 真机、P4-15 真实浏览器/麦克风及最终 Closure 仍 Pending，任何 build、模拟器、root、fake 或 synthetic 结果都不能替代。

首页现提供“导入歌曲并准备原唱对比”入口。模型权重不进入 Git 或 release artifact；Windows/Android 只有在用户提供固定哈希模型且本机 probe 成功时才开放 native runtime，Web 保持 typed unavailable。开发期质量工具位于 `tool/song_separation/`，不会用伪 stem 冒充分离成功。

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

先完成 P4-13 候选的 hosted CI 接受；本地 release、最终 emulator bundle 与零 blocker/high 审计已经完成。这只封存远程实现基线。随后 P4-14 Android 真机、P4-15 真实浏览器/麦克风仍需人工设备，P3-07D 也仍须仓库所有者在 Windows 工作站旁执行。
