# 实施手册

版本：1.0  
目标：让后续较便宜模型按小任务可靠实现，而不是重新做架构判断。

## 1. 工作方式

一次只执行一个 Phase 或一个任务卡。每张任务卡必须写明：

- 目标结果，而非“研究/优化一下”。
- 允许修改的目录。
- 不允许触碰的模块。
- 可执行验收命令和数值门槛。
- 需要更新的文档/测量结果。

每个 Phase 结束后先运行 gate、更新 `RESEARCH_NOTES.md` 和当前状态，再进入下一阶段。任何 spike 推翻架构时，先改蓝图，后改代码。

## 2. 模型选择建议

### 2.1 推荐组合

主开发默认使用：**`gpt-5.6-terra` + Medium**。

原因：当前 Codex 官方手册把 Terra 定位为日常工程主力和 GPT-5.5 工作的自然起点；它比 Sol 更适合持续、边界清楚的实现任务。Medium 是规划、工具调用和检查之间的默认平衡。

按任务切换：

| 工作 | 模型 / 思考深度 | 说明 |
|---|---|---|
| Phase 0 工具链、FRB/Web spike、首次 DSP 框架 | Terra / High | 跨语言和平台选择仍有权衡，需要更强检查。 |
| 普通 Dart 页面、repository、模型、迁移、单元测试 | Terra / Medium | 主推荐。 |
| 已有明确接口和 golden 的机械实现、补测试、文档整理 | Luna / Medium | 最省；任务必须小而具体。 |
| 独立算法函数、失败条件清楚但细节较难 | Luna / High 或 Terra / Medium | 先用 Luna；两次修复仍失败就升 Terra。 |
| 间歇性音频并发、WASM worker、内存/延迟疑难故障 | Sol / High 或 XHigh | 只用于高价值难题和最终架构审计。 |
| 全项目最终安全/性能/一致性审计 | Sol / High | 在 MVP 候选完成后运行一次。 |

不推荐把 Sol/Max/Ultra 作为日常默认：官方说明 Max/Ultra 适合少数最难任务；Ultra 还会用并行子 Agent，同一工作区实现容易产生重叠编辑。也不建议为新项目选 GPT-5.5：Terra 是官方给出的 5.5 自然替代起点。

**不要选 GPT-5.4 作为长期主力。** 当前 Codex 手册说明，使用 ChatGPT 登录的 Codex 将在 2026-08-31 退役 GPT-5.4/5.4-mini，并建议分别迁移到 5.6 Terra/Luna。API key 模式不受该退役影响，但本项目没有理由依赖即将从当前 Codex 登录路径退出的型号。

官方资料：

- [Codex model selection](https://learn.chatgpt.com/docs/models)
- [OpenAI model guidance](https://developers.openai.com/api/docs/guides/latest-model)
- [OpenAI models](https://developers.openai.com/api/docs/models)

注意：官方 API token 价格可以说明 Sol/Terra/Luna 的相对定位，但 Codex App 的套餐/额度不一定按同一价格直接折算，因此不要承诺某任务的精确花费。

### 2.2 降价模型任务模板

```text
先完整阅读 AGENTS.md，以及本任务引用的蓝图章节。

只完成：<一个明确结果>。
允许修改：<目录/文件>。
不要修改：<目录/模块>。
必须满足：<行为和数值门槛>。
必须运行：<命令>。
若发现架构假设不成立：停止扩展实现，把复现数据写入 docs/RESEARCH_NOTES.md，并说明需要修改的决策。
最终报告只包含：变更文件、验证结果、残余风险。
```

连续两次在同一失败上打补丁，或需要跨越任务卡边界，停止 Luna，切到 Terra/High；不要用更多模糊提示消耗上下文。

## 3. Phase 0：工具链与架构 Spike（下一步唯一范围）

### 3.1 修复工具链

当前机器已有 Flutter 3.44.7、Dart 3.12.2、VS 2022、Windows/Edge；缺 Rust/Cargo、Android SDK。先完成：

1. 从 [rustup 官方安装页](https://rustup.rs/) 安装 Rust，固定 1.97.1 安全补丁线。
2. 安装 Android Studio/SDK、platform tools、对应 build tools，并让 `flutter doctor -v` 识别。
3. Edge 已能作为 Web 设备，Chrome 非硬性阻塞；浏览器矩阵阶段再装 Chrome/Firefox/Safari 设备。
4. 调查 pub.dev、Google Storage、CocoaPods TLS 握手错误：检查系统时间、代理和企业根证书。**禁止**关闭 SSL 校验或永久设置不安全镜像。
5. 确认 `flutter pub get`、Cargo crates.io 和 FRB 下载链路可用。

检查命令：

```powershell
flutter --version
flutter doctor -v
rustup show
rustc --version
cargo --version
git --version
curl.exe -Iv https://pub.dev
curl.exe -Iv https://storage.googleapis.com
```

Rust 目标（Windows 开发机）：

```powershell
rustup toolchain install 1.97.1
rustup default 1.97.1
rustup target add --toolchain 1.97.1 wasm32-unknown-unknown
```

Android Rust targets由 Cargokit/NDK 集成验证后再显式添加，避免先装错误 ABI。Apple target 只能在 macOS runner 上构建。

**Gate 0A**：`flutter doctor -v` 的 Flutter、Windows、Android、至少一个 Web 设备通过；网络资源不再报证书错误；`rustc/cargo` 可用。把完整版本和仍存在的非阻塞警告写回研究笔记。

### 3.2 初始化仓库和工程

确认用户尚未指定正式应用 ID 时，开发期使用 `com.local.voice_trainer`，发布前必须更换。

```powershell
git init
flutter create --empty --org com.local --project-name voice_trainer --platforms=android,ios,linux,macos,web,windows .
flutter pub get
```

保留现有 `README.md`、`AGENTS.md` 和 `docs/`；如果 `flutter create` 覆盖文件，恢复本仓库版本而非接受模板文本。提交第一笔“planning + scaffold”基线。

加入当前批准的最小依赖，不要一次加入所有候选：

- `flutter_riverpod`
- `go_router`
- `record`
- `drift`、`sqlite3`、`path_provider`
- dev：`drift_dev`、`build_runner`

FRB：

```powershell
cargo install flutter_rust_bridge_codegen --version 2.12.0 --locked
flutter_rust_bridge_codegen integrate
flutter_rust_bridge_codegen generate
```

若 `integrate` 生成结构与 `FILE_MANIFEST.md` 不同，优先保留工具的可靠 build glue，再把业务 Rust 模块移动到规定位置并更新 manifest；不要手拼所有平台链接脚本。

**Gate 0B**：空应用在 Windows 与 Edge 启动；Rust `hello`/版本函数在 Windows FFI 和 Web WASM 都返回；生成命令可重复运行且 Git 无意外漂移。

### 3.3 Spike A：采集检查器

实现开发专用 `CaptureInspector`，不做正式页面。用 `record 7.1.x` 采集 PCM16 mono 48 kHz，测试 Web `streamBufferSize` 512/1024/2048，并收集：

- 请求格式与有效格式。
- chunk 字节数、样本数、到达间隔 min/median/P95/max。
- 60 秒样本总数与墙钟期望差。
- dropped/discontinuity 代理指标。
- AGC、echo cancellation、noise suppression 的实际值（平台能报告时）。
- start/first-chunk/stop 时延。
- WAV 写出后的 header、文件时长、sha256。

Windows 至少测试内置麦克风和一个可用外接设备（若存在）；Web 用 Edge。测试暂停 20 秒再恢复，因为 `record_web` 源码包含长暂停后的重连 workaround。

**Gate 0C**：

- 有效格式能被准确记录和消费。
- 60 秒无崩溃，样本总数误差可解释且无持续积压。
- 512 或 1024 buffer 能达到蓝图延迟门槛；否则记录 2048 结果。
- 录音时长与样本计数误差 <0.5%。
- 未达标时只写问题报告，不立刻自研插件。

### 3.4 Spike B：Rust 批量桥与 DSP 骨架

建立最小 `RealtimeAnalyzer`：PCM16 → f32 → RMS/Peak → 2048 Hann/FFT → MPM/YIN candidate。用 Rust 合成信号，不需要麦克风即可运行。

基准批次：512、1024、2048 samples；比较：

- bridge 调用开销与数据复制。
- 单批处理 P50/P95。
- 10 分钟模拟流吞吐与内存。
- Windows native 与 Edge Rust WASM 单线程。

实时路径预先分配 buffer、复用 FFT plan。benchmark 结果以机器、build mode、commit、配置为前缀写入研究笔记。

**Gate 0D**：处理速度至少为实时的 10 倍余量（10 分钟音频 ≤1 分钟离线处理，且单批 P95 不积压）；稳定内存；Windows/Web 输出在浮点容差内一致；chunk 任意切分不改变最终帧序列。

### 3.5 Spike C：Drift 与 packed BLOB

只建最小 `analysis_runs`、`feature_series` 表和 codec。生成 24,000 帧（20 分钟、20 Hz）Float32/bitset BLOB，在 Windows 和 Edge 完成写入、读取、校验和、迁移 v1 测试。

**Gate 0E**：round-trip bit-exact；不产生逐帧 SQL；Web 能报告选用 OPFS/IndexedDB 实现；测试不会把 100 MB 音频塞进 SQLite。

### 3.6 Phase 0 决策会议（文档动作）

更新 `RESEARCH_NOTES.md`：

- record 每个平台当前 verdict：adopt / conditional / replace。
- FRB native/Web verdict。
- 选定 stream buffer 和桥 batch。
- Pitch spike 暂定 MPM 或 YIN及阈值范围。
- packed BLOB 编码决定。
- 未决风险、负责人/下个 Phase。

只有 Gate 0A–0E 全部通过或有明确批准的 ADR，才能进入 Phase 1。

## 4. Phase 1：可测试骨架

目标：完成 domain contract、Riverpod 注入、router、主题、Drift schema 和 fake implementations；页面只有可导航的最小内容。

任务：

1. 按 manifest 创建 `core/domain` 和 `infrastructure` 边界。
2. 定义 session 状态机：idle → requestingPermission → ready → running/paused → finalizing → completed/failed。
3. 用 fake capture + fake analysis 完成一次内存闭环。
4. 建 Drift 迁移 v1 和 repository 测试。
5. 建日志脱敏和全局错误映射。

Gate：domain 测试无需 Flutter binding；fake integration test 完成会话且错误路径可恢复；页面不能直接导入 record/Drift/FRB。

## 5. Phase 2：DSP MVP

目标：在 Rust 内完成 PCM、ring、DC blocker、重采样、STFT、MPM/YIN、level、band power、稳定度和 quality flag。

顺序：

1. 确定性信号生成与 golden manifest。
2. 任意 chunk 切分不变量。
3. 音高与 voiced decision。
4. 全带宽频谱和 UI bins。
5. segment aggregator 和稳定度。
6. FRB DTO/mapper。
7. Windows/WASM benchmark。

不要实现 HNR、Formant、CPPS、Jitter/Shimmer。

Gate：达到蓝图合成基准；`cargo fmt/clippy/test/bench` 通过；没有实时循环大分配；Web 单线程可运行。

## 6. Phase 3：Windows 实时闭环

目标：内置/外接麦克风在 Windows 完成长音练习、录制、结果和保存。

顺序：capture adapter → bounded queue → coordinator → UI decimator → Live UI → native WAV sink → summary/rules → result/history。

可视化先 pitch curve、目标表和 quality；频谱作为专业展开项，spectrogram 放到性能 gate 后。

Gate：30 分钟 soak、权限/设备拔插/暂停恢复/磁盘失败、恢复临时文件；P50/P95 延迟和 UI frame time 达标；无逐帧数据库写入。

## 7. Phase 4：Android 与 Web

Android：实机测试至少一台中端设备；处理器实际值、后台/来电、蓝牙/有线耳机、权限撤销。  
Web：Edge + Chrome + Firefox；Safari/iOS Web 由 macOS/iPhone runner 验证。默认 Flutter JS + Rust WASM，60 秒录音上限明确显示。

Gate：两个平台都完成相同长音闭环；平台不支持项由 `PlatformCapabilities` 控制，不用页面散布条件判断；Web 部署验证 WASM MIME、缓存、CSP 和必要 headers。

## 8. Phase 5：MVP 完整性

1. 三个练习模板（长音完整，目标音/滑音可用）。
2. 同任务历史和个人基线的最小版本。
3. 保存/删音频/仅指标策略与导出/删除测试。
4. 练习内容 review 状态和中英文关键安全文案。
5. 第三方 license audit、隐私说明、发布配置。
6. Sol/High 做一次只读架构、安全、性能审计，再由 Terra 修复明确问题。

MVP gate 采用蓝图第 17 节，不因演示好看而放宽数据和安全要求。

## 9. Phase 6：Beta 高级分析

按单独 feature flag 和算法版本依次加入：

1. HNR/periodicity。
2. Vibrato。
3. Formant/Burg vowel-only。
4. CPP/CPPS。
5. A/B 对齐、Progress、训练计划。

每个指标先完成参考 oracle、跨实现误差、设备/环境敏感性、文案审查，最后才进入 UI。Jitter/Shimmer 和自动“疲劳风险”保持研究状态，除非有充分验证。

## 10. 标准验证命令

格式/静态检查：

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool
flutter analyze
cargo fmt --check --manifest-path rust\Cargo.toml
cargo clippy --manifest-path rust\Cargo.toml --all-targets -- -D warnings
```

生成与漂移检查：

```powershell
dart run build_runner build --delete-conflicting-outputs
flutter_rust_bridge_codegen generate
git status --short
```

生成后检查 `git status`，确认变化只来自预期的源文件和 generated 文件；在提交预期输出后再运行一次生成，并用 `git diff --exit-code` 证明生成可重复。不要在尚有正常开发改动时把全仓库 `git diff` 非空误判为生成器失败。

单元/集成：

```powershell
flutter test
cargo test --manifest-path rust\Cargo.toml
flutter test integration_test\fake_capture_session_flow_test.dart
```

构建：

```powershell
flutter build windows --release
flutter_rust_bridge_codegen build-web --release
flutter build web --release
flutter build apk --debug
```

Flutter `--wasm` 是额外构建：

```powershell
flutter build web --wasm --release
```

它不能替代默认 Web 构建，除非浏览器矩阵和部署 headers 全部通过。

## 11. CI 策略

- Windows runner：Dart/Rust checks、Windows release build、Rust native benchmark smoke。
- Ubuntu runner：Dart/Rust checks、Linux build；安装 Linux recorder runtime deps只用于手动 integration。
- macOS runner：macOS/iOS compile；真实麦克风仍为手动矩阵。
- Web：默认 JS + Rust WASM build、headless fake capture tests；浏览器真实麦克风不能由普通 CI 权限模拟为已通过。
- Android：debug APK + emulator fake capture；真实设备矩阵单列。

benchmark 不以共享 CI 绝对时长作为回归唯一依据；用固定自托管/参考设备或保存相对基线。

## 12. 下一位 Agent 的启动提示词

Phase 0、Phase 1 与 Closure C1–C4 已完成。建议默认选 `gpt-5.6-terra`、Medium；当前一次只执行 `P2-01`：

```text
请先完整阅读仓库根目录 AGENTS.md、docs/PROJECT_BLUEPRINT.md、
docs/IMPLEMENTATION_PLAYBOOK.md、docs/FILE_MANIFEST.md 和 docs/RESEARCH_NOTES.md。

Phase 0、Phase 1 与 Closure C1–C4 已完成，不重复旧 gate，不批量生成产品 UI。
本轮只执行 docs/PHASE1_CLOSURE_PLAN.md 的 P2-01：建立确定性纯音、谐波、缺失基频、
固定种子噪声、滑音、静音、削波和断点信号，保存参数、SHA-256 与预期指标。
不得修改生产 pitch/spectrum/resampler，不得提前进入 P2-02，不得恢复 FRB 2.12 默认 Web WorkerPool，
不得逐帧写 SQL。完成后运行 P2-01 窄测试及 AGENTS.md 中适用的 phase-boundary checks，并更新证据。
```

Phase 2 固定顺序和硬指标见 `docs/PHASE1_CLOSURE_PLAN.md`。Luna 只接收接口、文件和验收已经完全明确的机械任务。
