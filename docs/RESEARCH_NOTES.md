# 技术调研与验证记录

调研日期：2026-08-03  
这不是营销性“库清单”，而是架构决策的证据和仍需用 spike 验证的边界。

## 1. 当前决策状态

| 问题 | 当前结论 | 置信度 | 下个验证 |
|---|---|---:|---|
| Flutter 是否适合六平台 UI | 适合；本机 stable 3.44.7 已启用六平台。 | 高 | 各平台 build CI。 |
| 音频采集是否先自研 | 否；`record 7.1.1` 已提供六平台 PCM16 stream。 | 中高 | Phase 0 真实延迟/丢帧/格式。 |
| Rust DSP 是否成立 | 成立，FRB stable 支持六平台与 Web，RustFFT 支持主流 SIMD。 | 中高 | Native/WASM bridge benchmark。 |
| Web 是否能复用 Dart isolate | 不能。Flutter 文档明确 Web `compute` 在主线程运行。 | 高 | Rust WASM worker 单线程 spike。 |
| Web PCM 是否只能 MediaRecorder | 否。检查的 `record_web` PCM 路径使用 AudioWorklet；压缩格式才使用 MediaRecorder。 | 高（当前源码） | Edge/Chrome/Firefox cadence。 |
| 数据是否逐帧 SQLite | 否。用 20 Hz 列式 BLOB + summary。 | 高 | Windows/Edge 24k frame round-trip。 |
| HNR/CPP 是否能直接判断漏气 | 不能。算法、元音、任务、设备和环境均影响数值。 | 高 | Beta 参考/真实数据验证。 |
| 生产运行时是否用 Praat sidecar | 否。仅作为开发 oracle；平台碎片化且 Praat GPLv3+。 | 高 | 开发脚本独立许可清单。 |

## 2. 本机工具链检查

执行了 `flutter --version`、`flutter doctor -v` 和命令可用性检查。

可用：

- Windows 11 专业工作站版 64-bit。
- Flutter 3.44.7 stable，framework revision `84fc5cbb22`。
- Dart 3.12.2，DevTools 2.57.0。
- Visual Studio Community 2022 17.14.36，Windows SDK 10.0.26100.0。
- Windows desktop device。
- Edge 138 Web device。
- Node 24.13.0。
- Git 2.55.0.windows.3。

阻塞：

- `rustc` / `cargo` 未安装。
- Android SDK 未找到。
- Chrome 未找到，但 Edge 已能执行初始 Web spike。
- `flutter doctor` 对 `https://pub.dev/`、Google Storage 和 CocoaPods 报 cryptographic/TLS handshake error。不能以关闭 SSL 验证绕过。
- CMake/Ninja 不在全局 PATH，但 Flutter 已识别完整 VS Windows 工具链；只有后续构建实际失败时才处理。

因此本轮没有伪造 Flutter/Rust 可编译性测试。Phase 0 首先修复这些前置条件。

## 3. `record` 采集研究

### 3.1 发布能力

调研时 [record 7.1.1](https://pub.dev/packages/record) 声明 Android、iOS、Web、Windows、macOS、Linux 均支持 PCM16 stream。其实现概览：

- Android：AudioRecord。
- iOS/macOS：AVFoundation。
- Windows：Media Foundation。
- Web：浏览器 API。
- Linux：依赖 `parecord`、`pactl`、`ffmpeg`。

因此选择它作为 `AudioCapture` 的首个实现，而不是把它直接散布到业务层。

### 3.2 源码检查

本机以只读方式检查上游 commit：

- commit `453fee077d6649c01ce9c137f607ec68fd445af9`
- commit date `2026-07-30`

发现：

1. [Web PCM worklet](https://github.com/llfbandit/record/blob/453fee077d6649c01ce9c137f607ec68fd445af9/record_web/assets/js/record.worklet.js) 使用 `AudioWorkletProcessor`，默认 `streamBufferSize=2048`，允许 256–8192；聚合、重采样并发送 Int16Array。
2. [Web mic delegate](https://github.com/llfbandit/record/blob/453fee077d6649c01ce9c137f607ec68fd445af9/record_web/lib/src/recorder/delegate/mic_recorder_delegate.dart) 将 worklet message 转 Uint8List stream；长时间暂停后包含 Chromium 重连逻辑。
3. [Web constraints](https://github.com/llfbandit/record/blob/453fee077d6649c01ce9c137f607ec68fd445af9/record_web/lib/src/recorder/delegate/recorder_delegate.dart) 请求并回读 sampleRate/channelCount/AGC/echo/noise 设置。这正适合 effective format/quality flag。
4. worklet 内含自有重采样器；上采样是线性插值，下采样是 multi-tap。为了避免不透明的频谱影响，尽量请求浏览器有效率并让 worklet passthrough，音高分支由 Rust 做经过验证的抗混叠降采样。
5. [Windows recorder](https://github.com/llfbandit/record/blob/453fee077d6649c01ce9c137f607ec68fd445af9/record_windows/windows/record/record.cpp) 使用异步 Media Foundation SourceReader，不是直接 WASAPI。是否达到练声反馈延迟只能实测。

这次源码检查证明插件架构可作为 MVP 起点，但不能证明所有驱动/浏览器性能。

## 4. Flutter 实时执行与绘制

- [Flutter isolates](https://docs.flutter.dev/perf/isolates) 说明：原生平台可使用长寿命 isolate；Web 不支持 isolate，`compute` 仍在主线程。这排除了“把 Web DSP 丢到 compute”方案。
- [TransferableTypedData](https://api.dart.dev/dart-isolate/TransferableTypedData-class.html) 在原生 isolate 间发送为常数时间，但创建数据仍与字节量成正比。必须测 FRB typed-data 编码，避免重复 copy。
- [CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html) 的 `repaint Listenable` 可以绕过 build/layout，适合 pitch/spectrum 高频图。
- [Flutter performance guidance](https://docs.flutter.dev/perf/best-practices) 要求关注 16 ms frame budget，并提醒 `saveLayer`、opacity、clip 等代价。实时图表应固定 buffer、隔离 repaint。

结论：平台 channel 的 PCM 先到 Flutter 侧，capture callback 要极轻；原生 DSP 在 Rust worker/非 UI isolate，Web DSP 在 Rust WASM worker。UI 只收 20–30 Hz 降采样帧。

## 5. Web 与 WASM

- [Flutter Wasm support](https://docs.flutter.dev/platform-integration/web/wasm) 要求 Flutter 3.24+，多线程运行依赖 COOP/COEP；依赖还必须兼容 `package:web`/静态 JS interop。当前文档也列出 Safari/Firefox/iOS Web 的 Wasm renderer 限制。
- [Web Audio 1.1](https://www.w3.org/TR/webaudio-1.1/) 的默认 render quantum 为 128 sample frames，适合 Worklet 采集，但插件会继续聚合成更大的应用 chunk。
- [Media Capture and Streams](https://www.w3.org/TR/mediacapture-streams/) 定义 sample rate、channel count、echo cancellation、AGC、noise suppression 等 constraints；浏览器最终 effective settings 必须回读。
- [flutter_rust_bridge quickstart](https://cjycode.com/flutter_rust_bridge/quickstart) 提供 `build-web` 并说明标准 Flutter run/build 流程；多线程示例要求 COOP/COEP。
- [FRB WASM limitations](https://cjycode.com/flutter_rust_bridge/manual/miscellaneous/wasm-limitations) 明确 Safari nested worker、panic、SharedArrayBuffer/Atomics 支持差异。

结论：MVP 默认发布 Flutter JS + 单线程 Rust WASM；Flutter `--wasm` 和 Rust WASM SIMD/threads 分别作为后续性能层，不能混为一个开关。

## 6. Rust DSP 依赖研究

- [flutter_rust_bridge 2.12.0](https://pub.dev/packages/flutter_rust_bridge/versions) 是调研时稳定版；2.13 beta 才提供新的 Native Assets backend。为了可重复性选择 2.12/Cargokit。
- [RustFFT 6.4.1](https://docs.rs/rustfft/latest/rustfft/) 是纯 Rust FFT，支持 x86 AVX/SSE、ARM Neon 与可选 WASM SIMD。
- [RealFFT 3.5.0](https://docs.rs/realfft/latest/realfft/) 对真实信号避免完整 complex FFT，长 FFT 文档中报告明显加速。
- [Rubato 4](https://docs.rs/rubato/latest/rubato/) 提供固定/异步、抗混叠的 chunked resampler，并有预分配实时 API。48→16 kHz 还应与专用 3:1 polyphase FIR 比较，避免通用 FFT resampler 的群延迟成为实时反馈瓶颈。
- [pitch-detection 0.3.0](https://docs.rs/pitch-detection) 同时有 autocorrelation、MPM、YIN且面向 WASM，但最后发布于 2022 年，只能作为被 adapter 隔离的 spike 起点。
- [Rust 1.97.1](https://blog.rust-lang.org/2026/07/16/Rust-1.97.1/) 是当前安全补丁版本，修复 1.97.0 的 LLVM miscompilation 风险，适合 toolchain pin。

尚未安装 Rust，因此这些依赖尚未在本机编译。具体版本须以 Phase 0 compatible resolution 和 lockfile 为准。

## 7. Pitch 算法研究

### 7.1 YIN

[YIN 原论文](https://pubmed.ncbi.nlm.nih.gov/12002874/) 在自相关基础上用差分函数、归一化和插值减少错误，结构清楚、实时成本低，适合 baseline/fallback。

优点：实现和测试相对直接、无模型资产、高低音范围可控。  
风险：噪声、气声和谐波结构可能导致 voiced/octave error，需要连续性模型和阈值调优。

### 7.2 MPM

[A Smarter Way to Find Pitch](https://citeseerx.ist.psu.edu/document?doi=60dd4c01f687858a5fbf6c021920c56247bcf2db&repid=rep1&type=pdf) 为单音音乐提出 normalized square difference 和 clarity；这与练声实时反馈很匹配。

优点：自带 clarity，适合 monophonic singing；已有 Rust spike 实现。  
风险：阈值和 peak picking 仍需真实人声分层测试。

### 7.3 CREPE/神经方案

[CREPE 论文](https://arxiv.org/abs/1802.06182) 报告在多个数据集和噪声条件下优于/相当于传统方法。它证明神经 tracker 是有价值的后备路线，但不等于适合本项目 MVP。

风险：模型分发、推理运行时、移动/Web 体积和热量、license/模型卡、跨平台数值一致性。先让 MPM/YIN 通过明确 benchmark；达不到再用同一 `PitchEstimator` contract 做神经 spike。

### 7.4 决定

Phase 0 同时跑 MPM/YIN；默认倾向 MPM + 连续性平滑。不要仅凭纯音准确率定夺，必须加入缺基频谐波、气声/噪声、滑音、vibrato 和许可真人声。

## 8. 高级声学指标的限制

- [Praat Harmonicity](https://praat.org/manual/Harmonicity.html) 将 HNR 定义为周期性/噪声能量关系，并特别展示不同元音高频结构会改变 HNR；不能跨元音套同一结论。
- [Praat HNR autocorrelation](https://praat.org/manual/Sound__To_Harmonicity__ac____.html) 的窗口长度依赖 pitch floor 和每窗周期数，说明算法参数必须随结果版本保存。
- [Praat Burg Formant](https://praat.org/manual/Sound__To_Formant__burg____.html) 会重采样、预加重、加窗并做 Burg LPC；formant ceiling、窗长和极点数都影响结果。
- [CPPS clinical review](https://pmc.ncbi.nlm.nih.gov/articles/PMC7893528/) 指出持续元音和连续语音阈值不同，而且 Hillenbrand、Praat、ADSV 算法产生不同范围。
- [房间与麦克风可重复性研究](https://pmc.ncbi.nlm.nih.gov/articles/PMC6529301/) 显示房间、噪声和麦克风影响 jitter、shimmer、HNR、CPPS 等指标。
- [Praat license](https://praat.org/download_sources.html) 为 GPLv3+。调用独立工具产生开发期对照结果与把源代码/算法直接合入分发应用是不同的许可风险；本项目默认不链接/复制 Praat 代码，并在发布前做法律/许可证审计。

工程含义：高级指标必须有任务 gate、信号质量 gate、算法版本、个人基线和“非诊断”文案。原始指南的固定规则示例不能直接变成产品逻辑。

## 9. Drift 与 Web 存储

- [Drift supported platforms](https://drift.simonbinder.eu/platforms/) 支持 native `NativeDatabase` 和 Web `WasmDatabase`，建议原生数据库在 isolate。
- [Drift Web](https://drift.simonbinder.eu/platforms/web/) 根据浏览器选择 OPFS/shared worker 或 IndexedDB fallback；部分浏览器/多 tab 行为受 COOP/COEP 和 SharedWorker 支持影响。

结论：结构化数据使用 Drift 可行。录音不放数据库；Web recording BlobStore 需要独立容量、增量写和 fallback 设计。MVP 60 秒上限避免一次在内存保留长 PCM。

## 10. UI 依赖研究

实时图表不先依赖通用 chart package。Pitch curve、spectrum 和 energy bars 的输入结构简单，CustomPainter 更容易控制 allocation/repaint。历史统计图如果自绘成本变高，再比较 `fl_chart` 等包；新增包前必须检查可访问性、Web 性能、license 和维护状态。

Spectrogram 是风险最高图：固定 RGBA 环形 buffer、限制高度/历史、10–15 Hz upload，Phase 3 通过 pitch/spectrum gate 后再实现。

## 11. 被否决或延期的方案

| 方案 | 处理 | 原因 |
|---|---|---|
| 全部 DSP 纯 Dart | 否决为主路径 | Native 可用 isolate但 Web仍主线程；高级分析和复用上限较低。可留 fake/reference adapter。 |
| 一开始自研 WASAPI/Oboe/AVAudio/PipeWire | 延期 | 未先证明现有插件失败，维护成本与产品价值不匹配。 |
| Python/Praat 产品 sidecar | 否决 | 移动/Web不可用、部署和 GPL 风险、结果分裂。 |
| CREPE 作为首个 pitch | 延期 | 先用低成本 DSP 建 benchmark，只有失败才引入模型。 |
| 所有 feature frame 写 Drift 行 | 否决 | 20 分钟可达 120k 行；列式 BLOB 更小、更容易版本化。 |
| 只采 16 kHz | 否决 | 会失去 8 kHz 以上频谱，无法支持指南中的高频描述。 |
| 固定频段直接命名胸声/面罩/漏气 | 否决 | 生理映射不足，设备/元音/音高混杂严重。 |
| Flutter `--wasm` 作为唯一 Web 包 | 延期 | 当前浏览器兼容/headers/依赖限制；默认 JS + Rust WASM 更稳。 |

## 12. Phase 0 必答问题

1. `record` 在 Windows/Edge 的有效 sample rate 和 chunk cadence 是什么？512 vs 1024 的 P95 延迟、CPU、丢样如何？
2. `record` Web request 48 kHz 时是否始终 passthrough，哪些浏览器触发内置 resampler？
3. FRB 2.12 在 Flutter 3.44.7/Dart 3.12.2/Rust 1.97.1 下 native + Web 是否无补丁构建？
4. Uint8List → FRB typed buffer 的实际 copy 次数和每批开销是多少？
5. Rust WASM worker 在 Edge/Chrome/Firefox、Flutter JS build 下是否稳定；Safari 单线程 fallback如何？
6. MPM/YIN 在本项目 60–1200 Hz、谐波、噪声、滑音、vibrato 和真人声样本上的分层误差？
7. Drift Web 实际选择哪种 storage，24k frame BLOB round-trip 性能和多 tab 行为？
8. 正式 reverse-domain application ID、产品中文/英文名与发布主体是什么？开发不因这一项阻塞，发布必须解决。

这些问题回答前，不把候选方案写成“六平台已验证”。

## 13. 模型资料来源

Codex 模型建议来自当前官方手册和官方模型指南：

- [Codex model selection](https://learn.chatgpt.com/docs/models)
- [GPT-5.6 model guidance](https://developers.openai.com/api/docs/guides/latest-model)
- [OpenAI models](https://developers.openai.com/api/docs/models)

当前说明将 Sol 定位为复杂开放工作、Terra 为日常主力、Luna 为明确可重复任务；Medium 为平衡起点，High/XHigh用于多步骤权衡，Max/Ultra不适合大多数任务。Codex 使用 ChatGPT 登录时，GPT-5.4/5.4-mini 计划于 2026-08-31 退役。

## 14. Phase 0 执行记录（2026-08-03）

以下是本机实际命令输出的摘要。`通过`只表示已执行的检查成功，不替代尚未开始的真实设备采集测试。

### 14.1 Gate 0A：工具链、Android、TLS

| 检查 | 实测结果 | Gate 状态 |
|---|---|---|
| `flutter --version` | Flutter 3.44.7 stable，Dart 3.12.2，framework `84fc5cbb22`。 | 通过 |
| `flutter doctor -v`（复测） | Flutter、Windows、Visual Studio、Windows device、Edge web device 均为通过。Chrome 缺失为非阻塞警告。网络检查曾通过，但后续复测对 `https://maven.google.com/` 再次报 TLS handshake failure，说明网络稳定性未达门槛。 | 部分通过 |
| Rust | rustup 1.29.0；`rustc 1.97.1 (8bab26f4f 2026-07-14)`；`cargo 1.97.1 (c980f4866 2026-06-30)`；默认工具链 `1.97.1-x86_64-pc-windows-msvc`；已安装 `wasm32-unknown-unknown`。 | 通过 |
| TLS | 初次直接 `curl.exe -Iv https://pub.dev` 在握手失败；经本机已配置的可信 HTTP CONNECT 代理 `127.0.0.1:7890` 显式访问返回 HTTP 200 并完成 TLS。随后 `flutter doctor -v` 的 Network resources 复测通过。`https://storage.googleapis.com` 直接请求返回预期 HTTP 400（根路径）。未关闭 TLS 校验，未使用不安全镜像。 | 通过（仍需在新登录会话复验代理继承） |
| Android SDK | 已发起 `winget install --id Google.AndroidStudio --exact --silent ...`，但未生成 `C:\Program Files\Android\Android Studio\bin\studio64.exe` 或 `%LOCALAPPDATA%\Android\Sdk`。改用官方 command-line tools `commandlinetools-win-15859902_latest.zip`（官方 SHA-256 `90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a`）时，直连和经本机 HTTP CONNECT 代理均在 TLS handshake 失败；`flutter doctor -v` 仍报告 Unable to locate Android SDK。 | 未通过；最小复现保留 |

结论：Gate 0A **未通过**，唯一必需缺项是可由 Flutter 识别的 Android SDK。不要添加 Android Rust ABI target，直到 Cargokit/NDK 实测指出所需 ABI。

### 14.2 Gate 0B：Flutter/FRB 初始化

已执行：

```powershell
git init
flutter create --empty --org com.local --project-name voice_trainer --platforms=android,ios,linux,macos,web,windows .
flutter pub get
cargo install flutter_rust_bridge_codegen --version 2.12.0 --locked
flutter_rust_bridge_codegen integrate
```

前四项均完成：Flutter scaffold 与 `pubspec.lock` 已生成；FRB codegen 2.12.0 在 Rust 1.97.1 下从 crates.io 编译完成（release build 4m32s）；`integrate` 已生成 Cargokit scaffold、`rust/`、`rust_builder/`、`flutter_rust_bridge.yaml` 和初始 generated bridge 文件。

`integrate` 的最小失败复现是其内部命令：

```text
powershell -noprofile -command "& flutter pub add rust_lib_voice_trainer --path=rust_builder"
```

它在 Windows 返回：`Building with plugins requires symlink support. Please enable Developer Mode in your system settings.` Developer Mode 随后由用户启用，`flutter pub get` 成功，FRB 2.12.0 的 `integrate`/`generate` 生成了标准 Cargokit 文件。

`flutter build windows --debug` 仍失败：Cargokit 的 `run_build_tool.cmd` 在 Unicode 工作区 `D:\project\练声软件` 写出的临时 `pubspec.yaml` 将 path 变为 `D:/project/��������/windows/.../cargokit/build_tool`，随后报 `Couldn't resolve the package 'build_tool'`。即使在 `rust_builder/cargokit/build_tool` 先执行 `flutter pub get`，同一构建仍失败，因为真正运行的临时目录是 `build/windows/.../cargokit_build/tool`。这是中文路径通过 Windows batch code page 时损坏的最小复现。`generate` 还警告当前启动会话未将 `%USERPROFILE%\.cargo\bin` 传给子 PowerShell，因而找不到 `rustfmt`；生成器明确记录 warning 后继续完成，项目级 `cargo fmt --check` 已通过。

结论：Gate 0B **未通过**。Developer Mode 不再是阻塞项；当前阻塞项是 FRB 2.12/Cargokit Windows batch 对中文工作区路径的编码错误。除非用户明确同意以 ASCII 路径创建临时、可丢弃的验证工作副本，或上游提供修复，不进入 Capture、DSP 或 Drift spike。

Web 侧执行 `flutter_rust_bridge_codegen build-web --release` 也未通过：工具先执行 `where.exe wasm-pack`，本机未安装该工具，随后 codegen 在读取 Windows 命令输出时抛出 `FormatException: Missing extension byte (at offset 1)`。`cargo search wasm-pack --limit 1` 无法访问 crates.io，报 `SSL connect error (schannel: failed to receive handshake)`；在 TLS 恢复前不得以未校验下载或关闭证书验证安装 `wasm-pack`。这提供了 FRB Web gate 的独立、最小失败复现。

### 14.3 已批准的 Phase 0 直接依赖

| 依赖（实解版本） | 用途/平台 | 许可核对 | 回退与移除成本 |
|---|---|---|---|
| `flutter_riverpod` 2.6.1 | Flutter 应用层依赖注入；全平台。 | 待 Phase 5 license audit；上游为 MIT。 | 可用普通构造器替换；应用层会受影响。 |
| `go_router` 17.3.0 | Flutter 路由；全平台。 | 待 Phase 5 license audit；上游为 BSD-3-Clause。 | 可替换为 Router API；只影响导航。 |
| `record` 7.1.1 | Phase 0 PCM capture spike；Android/iOS/Web/Windows/macOS/Linux。 | 待 Phase 5 license audit；上游为 MIT。 | `AudioCapture` contract 后的单平台联邦适配器；不允许现在创建。 |
| `drift` 2.34.3、`sqlite3` 3.5.0、`path_provider` 2.1.6 | Phase 0 packed BLOB persistence spike；native/Web。 | 待 Phase 5 license audit；分别核对上游与 native/transitive license。 | repository/BlobStore contract；移除成本限于 infrastructure。 |
| `drift_dev` 2.34.5、`build_runner` 2.15.1 | Drift 生成开发工具。 | 待 Phase 5 license audit。 | 仅生成流程；不进入运行时。 |
| `flutter_rust_bridge`/codegen 2.12.0 | Rust 批量 bridge 与 Cargokit；native/Web。 | 待 Phase 5 license audit；上游为 MIT。 | `AnalysisEngine` adapter；移除成本为 bridge glue，不影响 Rust DSP core。 |
| `crypto` 3.0.7 | Phase 0 WAV/feature BLOB SHA-256；纯 Dart、全平台。 | BSD-3-Clause（本地 LICENSE 核对）。 | 可替换为平台/自有 SHA-256；调用面很小。 |
| `rustfft` 6.4.1 | Phase 0 2048 Hann FFT 与 FFT autocorrelation pitch candidate；Native/WASM。 | MIT OR Apache-2.0（Cargo metadata 与 LICENSE 核对）。 | 隔离在 Rust pipeline；可换 RealFFT/自有实现，不影响 bridge DTO。 |

`flutter_riverpod` 解析为 2.6.1 而非蓝图快照中候选的 3.4.x；在其升级兼容性实际验证前，不把 3.x 写为已采用版本。

### 14.4 已运行的静态检查

| 命令 | 实测结果 | 状态 |
|---|---|---|
| `cargo fmt --check --manifest-path rust\Cargo.toml` | 退出码 0。 | 通过 |
| `cargo clippy --manifest-path rust\Cargo.toml --all-targets -- -D warnings` | 退出码 0。 | 通过 |
| `cargo test --manifest-path rust\Cargo.toml` | 退出码 0；初始 FRB scaffold 暂无 Rust test（0 passed / 0 failed）。 | 通过 |
| `dart format --output=none --set-exit-if-changed .` | 连续两次均报告改写 `lib/main.dart` 和 3 个 FRB generated Dart 文件，尽管随后 3 秒哈希稳定且没有 Dart/FRB watch 进程；命令退出码仍为 0。此生成/格式化组合不满足“无漂移”证据，不能报告通过。 | 未通过；待在完整 `generate` 后复验 |
| `flutter analyze` | 退出码 255。分析服务器的 LSP 读取 `FormatException: Unexpected end of input`；错误位置包含本项目百分号编码的中文路径 `.../%E7%BB%83%E5%A3%B0%E8%BD%AF%E4%BB%B6/...`。这是最小复现：在 `D:\project\练声软件` 运行该命令即可发生，尚未产生 Dart lint/类型诊断。 | 未通过；Flutter/Dart 路径兼容性待修复 |
| `flutter test` | 退出码 1，`Test directory "test" not found.`。初始化 empty project 未生成测试目录；不能把“无测试目录”报告为已通过的测试。 | 未通过；待在 Gate 0B 后添加最小 bridge/scaffold smoke test |

因此 Gate 0B 之外还存在 Flutter analysis path/transport 故障。不得通过忽略分析器、关闭严格 lint 或把工作区静默迁移到其他路径来掩盖它；如需临时 ASCII 路径复验，必须保留此中文路径最小复现并记录是否为 Flutter 缺陷。

### 14.5 ASCII 临时副本复验

经用户明确授权，在 `D:\project\voice-trainer-phase0` 创建了可丢弃的 ASCII 路径副本（未复制 `.git`、`.dart_tool`、根 `build`、Rust `target` 或 IDE 缓存）。在该副本中：

| 检查 | 实测结果 |
|---|---|
| `flutter build windows --debug` | 通过，约 47.8 秒；生成 `build\windows\x64\runner\Debug\voice_trainer.exe`。 |
| `flutter test integration_test\simple_test.dart -d windows` | 通过，约 44.9 秒构建；实际 `RustLib.init()` 后调用 `greet("Tom")` 并断言 `Hello, Tom!`。 |
| `flutter analyze` | 通过，`No issues found`；根 `analysis_options.yaml` 明确排除 FRB generated Cargokit nested build-tool package。 |
| `flutter test` | 通过，Phase 0 scaffold smoke test。 |
| `dart format --output=none --set-exit-if-changed .` | 在 `flutter clean` 后通过（27 files, 0 changed）。未清理时 formatter 会改写 Cargokit build 临时 runner，故正常验证顺序必须先 clean。 |

这证明 FRB 2.12/Cargokit、Rust 1.97.1、Visual Studio 和 Developer Mode 的 Windows 原生组合可以工作；**但不证明原中文路径可用**，也不允许把临时副本当作正式仓库或自动迁移用户工作区。

原工作区随后执行 `flutter clean; flutter pub get; dart format ...; flutter analyze; flutter test` 的实测结果：format 通过（27 files, 0 changed）；analyze 仍以 LSP `FormatException: Unexpected end of input` 退出；test 在 `sqlite3 3.5.0` native asset hook 下载 `sqlite3.x64.windows.dll` 时，连接 `release-assets.githubusercontent.com` 超时（OS error 121）。该下载失败与 Android command-line tools、Maven 和 crates.io 的 TLS/网络不稳定相互印证。不得伪造 SQLite DLL、关闭 TLS 或把测试标记为通过。

### 14.6 更名后的 Android/TLS 复验（2026-08-03）

用户随后明确授权并完成正式仓库从 `D:\project\练声软件` 到
`D:\project\voice-trainer` 的重命名。前述 Unicode 路径失败仍是历史最小复现；
以下结论以 ASCII 正式仓库为准，并取代 14.1 中“尚无 Android SDK”的旧状态。

| 检查 | 实测结果 | Gate 状态 |
|---|---|---|
| Android command-line tools | 下载官方 `commandlinetools-win-15859902_latest.zip`，SHA-256 为 `90AE805D20434428BFFCB699C290860F19BB5F66A67E6B330067E3DE801FB04A`，与官方发布值一致；安装至 `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest`。 | 通过 |
| JDK | `winget` 安装 Eclipse Temurin JDK `17.0.20.8`（安装包哈希由 winget 验证）；`flutter config --jdk-dir` 指向该 JDK。 | 通过 |
| Android SDK | `build-tools;36.0.0`、`platforms;android-36` 和 Platform-Tools `37.0.1` 已安装。Platform-Tools 的 SDK Manager 下载两次在 TLS 握手中断，故改从官方 repository XML 取得 Windows 归档 SHA-1 `e03e78b1d80b396f1c3358e31251cb31740e1110`，经受信任 CONNECT 代理下载、校验后安装。原未完成目录保留为 `platform-tools.sdkmanager-tls-partial-20260803`。 | 通过（安装证据） |
| `flutter doctor -v` | Flutter 3.44.7、Android SDK 36.0.0、Temurin 17.0.20.8、全部 Android 许可、Visual Studio、Windows 与 Edge 均通过；Chrome 缺失为非阻塞 Web 警告；Network resources 通过。 | 通过 |
| JDK HTTPS 最小复现 | 通过 `127.0.0.1:7890` 执行 JShell `URL.openConnection()`，成功读取 Google Maven 的 `gradle-8.11.1.pom` 首字节 `<`；未禁用证书验证。 | 通过 |
| `flutter build apk --debug` | 已实际运行，自动安装并完成 NDK `28.2.13676358`、Android Platform 35/33；最终无 APK，`mergeDebugAssets` 下载 `androidx.window:window:1.2.0`、`window-java:1.2.0`、`activity:1.8.1` 时持续报 `Remote host terminated the handshake`。为最小化变量，已停止旧 daemon、禁用 daemon/parallel、限制一 worker，并向 JVM 显式传入代理参数，仍失败。完整 stdout/stderr 保留在 `%LOCALAPPDATA%\Temp\voice-trainer-phase0-android-build-serial.{out,err}.log`。 | 未通过；最小复现保留 |

决策：Gate 0A 的正式判据（`flutter doctor -v` 的 Flutter/Windows/Android/Web device、
无证书错误的 Network resources、Rust）均已通过，因此 **Gate 0A 通过**。Android 的真实
Flutter/FRB APK 仍被可重复的 Gradle artifact TLS 失败阻断；这是必须保留的 Android native
风险，但不是 Gate 0A 的定义项。不以预下载 AAR、关闭 TLS 验证、替换 Maven 源或自研六平台
插件掩盖该问题。

### 14.7 Gate 0B/0C：正式 ASCII 仓库的 FRB Native 与 Web 复验

| 检查 | 实测结果 | Gate 状态 |
|---|---|---|
| Native scaffold | `flutter build windows --debug` 在 `D:\project\voice-trainer` 成功，48.7 秒，生成 `build\windows\x64\runner\Debug\voice_trainer.exe`。 | 通过 |
| Native bridge | `flutter test integration_test\simple_test.dart -d windows` 成功；`RustLib.init()` 后实际调用 Rust `greet("Tom")`，测试 `1 passed`。 | 通过（Windows） |
| Web tooling | crates.io 解析并安装 `wasm-pack 0.15.0 --locked`（MIT OR Apache-2.0）；FRB Web 构建需要 nightly `rust-src`，已安装。实际 nightly 为 `rustc 1.99.0-nightly (11177f223 2026-08-02)`。 | 通过 |
| FRB Web bridge | `flutter_rust_bridge_codegen build-web --release` 成功，执行 `wasm-opt`，生成 `web\pkg\rust_lib_voice_trainer_bg.wasm`（83,141 bytes）和 JS glue。初次失败只因缺少 nightly `rust-src`；第二次失败只因 wasm-pack 未继承本地代理下载 Binaryen；两项修复后重跑通过。 | 通过 |
| Flutter Web JS | `flutter build web` 成功，生成 `build\web`，包含 `pkg` 与 `main.dart.js`。Flutter 仅提示 FRB 2.12 的 JS interop 令 Flutter `--wasm` dry-run 不兼容；本轮按蓝图采用 JS + Rust WASM，不宣称 Flutter Wasm 通过。 | 通过（JS 路径） |
| Edge runtime（无 COI） | `flutter run -d edge --web-port 7357` 已真实启动 Edge 和 Dart service；FRB 在 `init_app` 处 panic：`WorkerPool` 发送 `WebAssembly.Memory` 时 `DataCloneError: ... could not be cloned`，并警告缺少 cross-origin headers。 | 未通过；最小复现保留 |
| Edge runtime（COI） | `flutter run -d edge --web-port 7361 --cross-origin-isolation` 返回 `COOP: same-origin` 与 `COEP: credentialless`，但在同一 `WorkerPool`/`DataCloneError` 位置仍 panic，随后显示 `RuntimeError: unreachable`。 | 未通过；最小复现保留 |
| Header test harness | `tool/phase0_coep_server.ps1` 仅服务 `build/web`，以便验收生产服务必须发送的 `COOP: same-origin` 和 `COEP: require-corp`；curl 实测 200 与两头均存在。它不是产品服务器，也没有把该头部当作运行时通过证据。 | 通过（响应头） |
| Browser integration | `flutter test integration_test\simple_test.dart -d edge` 退出 1，唯一输出为 Flutter 当前限制 `Web devices are not supported for integration tests yet.` | 不适用；最小复现保留 |
| 静态检查 | `cargo fmt --check`、`cargo clippy -- -D warnings`、`cargo test`、`dart format --set-exit-if-changed .`、`flutter analyze`、`flutter test` 均已在正式 ASCII 仓库通过。FRB 生成的 Rust 初始存在 Rustfmt 漂移，已执行纯机械 `cargo fmt` 后复验通过。 | 通过 |

决策更新：Gate 0B 的 Windows Native FRB 已通过，但 Edge Web WASM 运行时无法执行
`init_app`，所以 **Gate 0B 整体未通过**。FRB Web artifact 与 Flutter Web JS build 的成功，
不构成 Web runtime `hello` 已返回，也不构成 Flutter `--wasm` 验证。按照 playbook，
Capture（Gate 0C）、bridge/DSP（Gate 0D）和 Drift BLOB（Gate 0E）均尚未启动；不能在
Gate 0B 未通过时推进它们。

### 14.8 Gate 0B 解阻与 Android APK 复验（2026-08-03）

上一节保留首次失败证据；本节记录其后的根因与最终复验，不回写历史结果。

| 检查 | 实测结果 | Gate 状态 |
|---|---|---|
| FRB 2.12 根因 | 默认 Cargo feature `thread-pool` 在 WASM 初始化 `WorkerPool`，把非共享 `WebAssembly.Memory` 发送给 Worker；Edge 无法 structured-clone。COOP/COEP 不会把既有 memory 变成 shared memory，所以两种响应头配置同样失败。 | 已定位 |
| Web target 配置 | `rust/Cargo.toml` 按 target 拆分 FRB dependency：Native 保留默认 features，WASM 显式保留默认集合但删除 `thread-pool`。FRB 2.12 在此配置下的默认 handler 存在 `LocalKey<SimpleThreadPool>` 类型不匹配，故 API 模块按其 custom handler 扩展点导出 `DefaultHandler<SimpleThreadPool>`。 | 通过 |
| 生成可重复性 | 连续两次 `flutter_rust_bridge_codegen generate` 后，5 个生成文件的 SHA-256 均不变；Native 与 `wasm32-unknown-unknown` 的 `cargo check` 均通过。 | 通过 |
| Edge runtime | `flutter run -d edge --web-port 7362 --cross-origin-isolation` 后通过 Edge DevTools Protocol 检查：`crossOriginIsolated == true`，页面显示 `Result: Hello, Tom!`，控制台打印 `PHASE0_FRB_GREETING=Hello, Tom!`；未出现 `DataCloneError`、panic 或 `Runtime.exceptionThrown`。 | 通过（Web） |
| Windows 回归 | `flutter build windows --debug` 和 `flutter test integration_test/simple_test.dart -d windows` 重跑通过，实际 Rust 返回 `Hello, Tom!`。 | 通过（Windows） |
| Android deterministic fixes | `android/gradle.properties` 禁用跨 C:/D: 失败的 Kotlin incremental cache；vendored Cargokit 从 Gradle 9 已删除的 `Project.exec` 改为注入 `ExecOperations`；vendored FRB Android library 的 compile SDK 从 33 对齐到 36。 | 通过 |
| Android SDK/build | 官方 `sdkmanager` 安装 CMake 3.22.1；在不关闭 TLS 校验、不换源、不手填 AAR 的前提下，增加 Gradle 内部重试、限制一 worker 并显式使用本机可信 CONNECT 代理后，`flutter build apk --debug` 完成。网络请求仍有随机 EOF/handshake，属于机器环境风险，不是源码 gate。 | 通过一次；待最终回归留存产物哈希 |
| 最终静态检查 | `dart format`、`flutter analyze`、`flutter test`、`cargo fmt --check`、Clippy `-D warnings`、Rust tests 均通过。 | 通过 |

决策：Gate 0B 的正式条件——Windows 与 Edge 启动、Rust hello 在 Native FFI 与 Web WASM 返回、生成命令可重复且无意外漂移——均已满足，因此 **Gate 0B 通过**。Web baseline 是单线程 WASM，不要求跨源隔离；未来 threaded/worker DSP 仍必须保留单线程 fallback，并在 Gate 0D 单独验证。Android/Gradle 补丁及覆盖风险记录在 `docs/adr/0001-frb-2-12-phase0-compatibility.md`。现在才允许进入 Gate 0C。

### 14.9 Gate 0C：CaptureInspector 实测（2026-08-03）

开发入口为 `lib/phase0/capture_inspector_main.dart`。计时从首个 PCM chunk 到达后开始；`startStream` 到首块的冷启动时间单独报告，避免把权限/设备启动时间错误计为持续采样丢帧。WAV 在 Windows 写到系统临时目录，Web 构造并校验完整内存 artifact；两者都解析 header、按 data bytes 计算时长并计算 SHA-256。

| 平台/设备 | 配置 | 60 秒样本误差 | interval P95 | discontinuity 代理 | 结论 |
|---|---|---:|---:|---:|---|
| Windows 默认（Realtek 内置阵列） | PCM16 mono 48 kHz；中途暂停 20 秒 | 0.3167%（59.81 s） | 47.615 ms | 1；max 134.142 ms，未持续 | 通过 |
| Windows USB Audio | PCM16 mono 48 kHz | 0.0167%（60.01 s） | 47.738 ms | 0 | 通过 |
| Edge / 512 samples | PCM16 mono 48 kHz | 0.0356%（60.0213 s） | 19.761 ms | 0 | 通过；首选 |
| Edge / 1024 samples | PCM16 mono 48 kHz | 0.0533%（60.032 s） | 30.070 ms | 0 | 通过；fallback |
| Edge / 2048 samples | PCM16 mono 48 kHz | 0.0533%（60.032 s） | 50.430 ms | 0 | 通过；不首选 |
| Edge / 512 + 暂停 20 秒 | PCM16 mono 48 kHz | 0.0889%（60.0533 s） | 19.690 ms | 0 | 通过；resume 103.181 ms |

所有运行均为偶数字节 chunk，WAV header 为 PCM format 1 / mono / 48 kHz / 16-bit；WAV duration 与样本计数误差为 0%。Windows callback work P95 最大 63 µs，Edge 最大 51 µs，没有持续积压。请求的 AGC、echo cancellation、noise suppression 均为 false；平台没有触发 config-adjusted callback，按 `record` 合约表示请求值被原样接受。Edge 设备列表不报告 per-device sample rates；不能伪造硬件实际值。

决策：**Gate 0C 通过**，暂定 Web `streamBufferSize = 512`、1024 作为负载较高设备的 fallback。Windows 的 `record_windows` stream chunk 约 2400 samples/50 ms，配置项本身不承诺控制 Windows buffer；本轮仍在 UI 延迟总预算内，但 Phase 2 必须结合 DSP/UI 端到端延迟复验。当前不开发自定义采集插件。

### 14.10 Gate 0D：Rust 批量桥与 DSP 骨架（2026-08-03）

Rust `RealtimeAnalyzerCore` 固定 2048 Hann window / 512 hop，预建 RustFFT plan 并复用 spectrum/autocorrelation buffers；输入 PCM16 转 f32，输出 RMS、Peak、spectral centroid 和 FFT-autocorrelation pitch candidate/clarity。该 candidate 只验证管线与吞吐，不是 Phase 2 最终 MPM/YIN 选型。

| 路径 / batch | 600 秒处理时间 | 实时倍数 | 单批 P95 | frames |
|---|---:|---:|---:|---:|
| Pure Rust / 512 | 1.294 s | 463.61× | 未跨桥 | 56,247 |
| Pure Rust / 1024 | 1.264 s | 474.46× | 未跨桥 | 56,247 |
| Pure Rust / 2048 | 1.343 s | 446.44× | 未跨桥 | 56,247 |
| Windows FRB / 512 | 1.588 s | 377.92× | 0.029 ms | 56,247 |
| Windows FRB / 1024 | 1.649 s | 363.78× | 0.062 ms | 56,247 |
| Windows FRB / 2048 | 1.563 s | 383.78× | 0.125 ms | 56,247 |
| Edge WASM / 512 | 9.953 s | 60.28× | 0.140 ms | 56,247 |
| Edge WASM / 1024 | 7.741 s | 77.51× | 0.265 ms | 56,247 |
| Edge WASM / 2048 | 6.578 s | 91.21× | 0.495 ms | 56,247 |

Windows 与 Edge 的 frame count、start-sample checksum 和 RMS checksum 完全相同；pitch checksum 分别为 `12411241.956237793` 与 `12411243.14276123`，累计相对差约 9.56e-8，属于 FFT/浮点平台差异。Rust property-style test 用 `[1,17,511,1024,37,2048,3,777]` 任意 chunk pattern 与整块输入对比，`AnalysisFrame` 序列完全相同。

Edge 同页预热后连续三次各处理 600 秒，强制 GC 后 used heap 约 17.396 → 17.407 → 17.416 MB，backing storage 稳定约 39.358 MB；没有随 28.8M samples 留存 PCM 或帧列表。当前 Phase 0 benchmark 是 FRB 2.12 单线程 fallback，每 64 calls 向事件循环让步；正式 Web `AnalysisWorkerSupervisor` 仍必须使用 dedicated worker，并保留此 fallback。

决策：**Gate 0D 通过**。bridge batch 选 1024 samples：相对 512 仍有 77.5× Web 余量，同时只增加约 21.3 ms 聚合延迟；2048 的额外吞吐不值得把聚合延迟再翻倍。

### 14.11 Gate 0E：Drift packed BLOB（2026-08-03）

`FeatureBlobCodec v1` 使用 32-byte little-endian header、24,000 个 Float32（96,000 bytes）和 3,000-byte validity bitset，总计 99,032 bytes。数据库只建 `analysis_runs`、`feature_series` 与 SQLite 自带 `sqlite_sequence`，一次 spike 写入 1+1 行，不存在逐帧 SQL 表。

| 平台 | Drift executor / storage | 写入 | 读取+解码 | 结果 |
|---|---|---:|---:|---|
| Windows | Native SQLite memory | 2.637 ms | 0.135 ms | bit-exact |
| Edge + COI | `WasmDatabase` / `opfsLocks` | 185.449 ms | 1.285 ms | bit-exact |

两平台的 BLOB SHA-256 均为 `58b65a449ed77a6203bbbe090f4f4a2884dd0ba193344f348f0c00a4a6b8b836`；原始 bytes、Float32 bits、validity 和 checksum 全部通过。Edge 报告缺失 `dedicatedWorkersInSharedWorkers`，因此按 Drift 探测选择 `opfsLocks`，没有静默退化到 unsafe IndexedDB 或 memory。schema/user_version 为 1，migration test 已通过。资源 `web/sqlite3.wasm` 与 `web/drift_worker.js` 来自锁定的 Drift 2.34.3 包内同版产物。

决策：**Gate 0E 通过**。格式规范见 `docs/specs/FEATURE_BLOB_V1.md`；录音仍属于独立 BlobStore，禁止放入 SQLite。

### 14.12 Phase 0 最终决策与回归（2026-08-03）

| 项目 | Verdict | 决策 |
|---|---|---|
| `record` capture | adopt（有条件） | Windows/Edge 通过；Web 512、1024 fallback。Android/Apple/Linux 真实设备仍进平台矩阵。 |
| FRB 2.12 Native | adopt | 保留默认 native thread pool；1024-sample batch。 |
| FRB 2.12 Web | conditional | 单线程 fallback 通过；生产路径必须补 dedicated worker。不要恢复会触发 DataCloneError 的默认 WASM WorkerPool。 |
| Pitch candidate | conditional | FFT autocorrelation 仅作骨架；Phase 2 比较 MPM/YIN、阈值与缺基频/噪声/滑音数据。 |
| Drift / packed BLOB | adopt | schema v1、Feature BLOB v1；Web 接受 OPFS/安全 IndexedDB，unsafe/memory 必须警告。 |
| Android build | adopt with environment risk | 当前 debug APK 构建通过；Gradle artifact TLS/代理仍是机器环境风险。 |

最终 Android debug APK 构建成功，大小 180,181,216 bytes，SHA-256 `8C6D8AEC27BB4282FE133C90124085A428995A24D03CA0D2059CEF8E309F915B`，包含 arm64-v8a、armeabi-v7a、x86_64 的 Rust library。Cargokit 构建末尾仍输出乱码编码的“系统找不到指定路径/文件”清理提示，但 Gradle 退出码为 0，APK 与三 ABI 均独立核验；后续升级 Cargokit 时应复查并移除该噪声。

Phase-boundary 回归：FRB codegen 连续两次 7 个生成文件 SHA-256 不变；`dart format` 54 files/0 changes、`flutter analyze`、5 Flutter tests、Rustfmt、Clippy `-D warnings`、2 Rust tests、default Web release、Windows debug build、Windows FRB integration test 均通过。`flutter clean` 曾提示 `.dart_tool` 目录被占用但返回 0；重新 `pub get` 后所有检查通过。Flutter Web 的 Wasm dry-run 仍指出 FRB 2.12 JS interop 不兼容，因此默认产物保持 Flutter JS + Rust WASM，不宣称 `flutter build web --wasm` 通过。

结论：**Gate 0A–0E 全部通过，Phase 0 完成**。进入 Phase 1 的任务拆分见 `docs/PHASE1_TASKS.md`。

### 15. Phase 1 P1-04：Analysis worker supervisor（2026-08-04）

- 新增 `RustAnalysisEngine`、`AnalysisWorkerSupervisor` 和 FRB DTO mapper。capture-sized 输入会在进入 bridge 前拆成最大 1024 PCM16 samples 的 batch；supervisor 队列上限默认 12,000 samples，溢出丢弃最旧待处理 batch 并累计 dropped samples。
- Native 使用既有 FRB 2.12 target 配置；Web 使用 `web/analysis_worker.js` 的 dedicated Worker。该 worker 持有独立 WASM `WorkerRealtimeAnalyzer` 实例，只接收 transfer 的 PCM16 typed batch，并仅回传 Phase 0 frame DTO。它不启用 FRB 2.12 WASM `WorkerPool`，因此不重现 Edge 的 `WebAssembly.Memory` `DataCloneError`。
- 主 worker 初始化/调用失败时，supervisor 尝试重启一次；重启失败则切换到 Gate 0D 已通过的单线程 FRB/WASM fallback。自动化测试覆盖 crash/restart、fallback、oldest-drop queue overflow、600 秒等效流的主 isolate heartbeat，以及 2400-sample Windows capture chunk 被拆为 `1024 + 1024 + 352`。
- 本轮已通过：`flutter analyze`、`flutter test`、`cargo fmt --check --manifest-path rust/Cargo.toml`、`cargo test --manifest-path rust/Cargo.toml`、`flutter_rust_bridge_codegen build-web --release`、`flutter build web --release`。默认 Flutter JS web build 的 Wasm dry-run 仍只报告既有 FRB 2.12 JS interop incompatibility；未把它报告为 Flutter `--wasm` 通过。

### 16. Phase 1 P1-06：Riverpod composition and minimal navigation shell（2026-08-04）

- 新增以 `ProviderScope` 为根的应用组合。`AudioCapture`、`AnalysisEngine`、`RecordingStore`、`RecordingSink` 与 `SessionRepository` 均有独立 provider，可在测试或后续 bootstrap 中整体覆盖；当前默认实现为确定性 fake/in-memory adapters。
- `GoRouter` 仅提供首页、实时练习、结果、历史、设置五个最小导航目标。实时练习页使用 `LivePracticeController` 驱动既有 fake coordinator 的 start/pause/resume/stop 意图；没有页面直接导入 `record`、Drift 或 FRB。
- widget tests 覆盖 override 后的权限拒绝、采集错误、结果页无数据状态，以及 shell 导航；composition test 覆盖每个外部 adapter provider 的替换。没有批量生成训练、历史或分析 UI。

### 17. Phase 1 P1-07：CI and platform matrices（2026-08-04）

- 新增 GitHub Actions 工作流：`Dart and Rust checks`、`Windows build`、`Web build` 和 `Android build`。前者与 `AGENTS.md` 的格式、分析、Flutter tests、Rustfmt、Clippy `-D warnings` 与 Rust tests 命令一致，并在 clean checkout 中重跑 Drift/FRB generation 后以 `git diff --exit-code` 拒绝 generated-file drift。
- Windows 工作流构建 release runner；Web 工作流构建 FRB Rust WASM 和默认 Flutter JS web bundle，明确不运行/不宣称 Flutter `--wasm` 通过；Android 工作流构建 debug APK，并在构建前审计 Kotlin incremental cache、Cargokit `ExecOperations` 以及 FRB library `compileSdkVersion 36` 三项已记录的兼容性补丁。
- 新建 Windows、Web、Android、Apple、Linux 测试矩阵。CI fake/emulator 覆盖和物理麦克风覆盖严格分列；Apple 与 Linux 在当前 Windows 主机上明确为 Pending。该提交只配置 CI，尚未拥有 hosted workflow 的首次运行结果，不能将工作流配置写作通过证据。
- 本地复验：`dart format --output=none --set-exit-if-changed .`（118 files / 0 changed）、`flutter analyze`、`flutter test`、Rustfmt、Clippy `-D warnings`、Rust tests 均通过；连续两次 FRB generation 的 4 个 bridge 文件 SHA-256 无差异。`flutter_rust_bridge_codegen build-web --release`、默认 `flutter build web --release`、`flutter build windows --release`、Windows fake capture integration flow 与 `flutter build apk --debug` 均通过。Android 构建仍输出既有 Cargokit 清理阶段的乱码“系统找不到指定路径/文件”和 SDK XML version warning，但 Gradle 退出码为 0、APK 已生成；保留为升级 Cargokit/SDK 时的复查项。

### C1 执行记录（2026-08-05）

- 范围：建立首次本地审计基线，审查忽略/敏感内容和大文件，固定生成物策略，并同步 Phase 1 Closure 状态与 Phase 2 范围。
- 修改文件：根 `.gitignore`、`.gitattributes`、`web/pkg/.gitignore`、CI format gate、`AGENTS.md`、`README.md`、蓝图、实施手册、manifest 与 Closure 计划。
- 敏感内容审查：未发现录音、SQLite/BLOB、私钥、keystore、`.env` 或疑似凭据；所有大文件均处于已忽略的 `.dart_tool`、`build` 或 `rust/target`。运行时录音/数据库、媒体格式和凭据现已由根忽略规则覆盖；小型、确定性且有文档/许可的测试 WAV 只能显式 force-add。
- 生成物策略：提交 `pubspec.lock`、`rust/Cargo.lock`、Drift `*.g.dart`、FRB Rust/Dart 输出、`web/pkg/` FRB JS/WASM，以及锁定 Drift 包来源的 `web/sqlite3.wasm`、`web/drift_worker.js`；不手改。FRB 生成的 `web/pkg/.gitignore` 保持 `*`，已跟踪的 bridge 文件与后续新增输出使用 force-add。CI 在 clean checkout 重新生成并拒绝 diff。`.gitattributes` 将 WASM、音频、数据库/BLOB 和图像声明为 binary。
- 执行命令与结果：源码范围 `dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool` 连续执行两次，结果一致；该 gate 不再扫描 `build/`。
- 平台/运行时：Windows 本地工作区；未运行真实麦克风或 Edge Worker 验收，本卡也不将它们当作通过。
- hosted CI：`origin` 已配置为 `git@github.com:song751/voice-trainer.git`，`master` 已推送。首次触发为 commit `1a9b829`： [Dart/Rust](https://github.com/song751/voice-trainer/actions/runs/31004201395)、[Web](https://github.com/song751/voice-trainer/actions/runs/31004201441)、[Android](https://github.com/song751/voice-trainer/actions/runs/31004201885)、[Windows](https://github.com/song751/voice-trainer/actions/runs/31004202562)。其中 Web run 在 `Reject FRB Web artifact drift` 失败；根因是 FRB 生成的 `web/pkg/.gitignore` 被手动改写。修复 commit `664596c` 保留工具生成的 `*` 并 force-add bridge 输出，已重新触发 [Dart/Rust](https://github.com/song751/voice-trainer/actions/runs/31004686198)、[Web](https://github.com/song751/voice-trainer/actions/runs/31004686065)、[Android](https://github.com/song751/voice-trainer/actions/runs/31004686506)、[Windows](https://github.com/song751/voice-trainer/actions/runs/31004683455)。这些运行的最终全绿由 C4 记录，不能在 C1 声称通过。
- 验收结论：通过。首个本地基线、remote 和可链接的首次 hosted CI 结果均可复核。
- 未覆盖项或外部阻塞：C4 仍需记录当前/后续 hosted CI 的最终绿灯；真实麦克风与 Edge Worker 不是 C1 验收项。
- 证据：首个本地基线 commit、`git status`、`.gitignore`/`.gitattributes`、本条记录、CI workflow 与上述 GitHub Actions runs。
- 下一张允许执行的卡：C2。

### C2 执行记录（2026-08-05，已完成）

- 范围：Analysis worker 有限恢复状态机、每个 worker request 的 timeout、无响应 worker 的直接 terminate、异常路径测试和 Edge dedicated-worker smoke。
- 修改文件：`analysis_worker_supervisor.dart`、FRB/Web worker adapters、`web/analysis_worker_client.js`、worker tests、`tool/c2_edge_worker_smoke.mjs`、`tool/c2_windows_worker_smoke.dart`、分析排除与 manifest。
- 已实现：supervisor 明确执行 `primary → restartOnce → fallback → terminalFailure`，只重启一次；`initialize`、`pushPcm`、`finish`、`reset` 和 factory/初始化均带 timeout。timeout/crash 后先同步 `terminate()`，不等待 worker 回复；`dispose()` 同样直接 terminate。Web client 会拒绝所有 pending promise 并调用 `Worker.terminate()`。
- 执行命令与结果：`dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool` 通过（99 files / 0 changed）；worker 窄测试 10/10 通过；`flutter analyze` 通过；`node --check tool/c2_edge_worker_smoke.mjs` 通过；`flutter test` 30/30 通过；默认 `flutter build web --release` 通过。该次 build 的 Flutter Wasm dry-run 成功，但不等同于 `flutter build web --wasm` 或 Edge dedicated-worker 验收，默认发布策略仍是 Flutter JS + Rust WASM。
- 真实运行时：使用用户启动的 Edge 138.0.3351.95（CDP `127.0.0.1:9222`）和本地 release web bundle。`tool/c2_edge_worker_smoke.mjs` 三次连续运行均输出 `48,000` samples / `1024` batch、`90` frames、start-sample checksum `2,050,560`、RMS dBFS checksum `-831.3684525375677`、pitch checksum `19859.106033325195`。脚本直接构造 `VoiceTrainerAnalysisWorker`，因此确认 dedicated worker 实际初始化、传输 PCM 与返回 DTO。
- Windows 对比：`flutter run -d windows -t tool/c2_windows_worker_smoke.dart` 使用相同信号和分批，输出 `90` frames、start-sample checksum `2,050,560`、RMS dBFS checksum `-831.3684525375675`、pitch checksum `19859.104278564453`。frame count/sample checksum 完全相同；RMS 绝对差约 `2.27e-13`，pitch checksum 相对差约 `8.84e-8`，均在 Phase 0 已记录的平台浮点容差内。
- DataCloneError：三次 Edge dedicated-worker 运行均成功，且 CDP 未报告 `Runtime.exceptionThrown`；未复现 DataCloneError。该结果仅适用于本项目禁用 FRB WASM WorkerPool、由 dedicated worker 自行持有 WASM 实例的路径。
- 验收结论：通过。有限状态恢复、timeout/terminate、异常测试、真实 Edge dedicated worker 与 Windows/Edge 数值对比均已完成。
- 下一张允许执行的卡：C3；不得进入 Phase 2。

### C3 执行记录（2026-08-05，已完成）

- 范围：真实 Native/Web 录音 BlobStore、录音删除/启动恢复、feature-series 无损持久化，以及 capture contract 补测。
- 修改文件：Drift schema/repository、`native_recording_sink.dart`、`web_recording_sink.dart`、`recording_recovery_service.dart`、WAV writer、Web storage client、capture/persistence tests 与 C3 Edge smoke。
- 录音生命周期：Native sink 只将完成文件暴露为 `.wav`；输入先进入同目录 `.partial`，PCM 与补写的 WAV header 均执行 flush 后才使用同卷 rename。abort 或启动恢复会清理 `.partial`。删除先写 `pendingDelete` tombstone，物理 Blob 删除成功后才删 DB 行；失败会保留 tombstone 供下次启动恢复。
- Web 存储层级：`VoiceTrainerRecordingStore` 先尝试 OPFS，失败时使用 IndexedDB，二者均不可用时才使用内存并设置明确的不可持久化警告。WAV 在 Web MVP 内存中构造，限制 mono 48 kHz PCM16 为 60 秒（5,760,000 PCM bytes），不写入 Drift/SQLite。
- feature-series：schema v2 新增 `feature_series_metadata`，保存 frame count、明确的起始 sample index、sample-period samples 和算法版本；每个 F0、RMS、Peak、Clarity、voiced、cents、quality-flags 列独立使用校验和保护的 packed BLOB。读取会校验每列 SHA-256，恢复原 sample timeline 与原始特征；未知 band/spectrum 列不会静默丢弃，而是明确拒绝写入直到其 column contract 定义完毕。
- 执行命令与结果：新增的 Drift repository round-trip/checksum、native sink/recovery、transaction rollback 以及 capture contract 窄测试共 11 项通过；最终 `flutter test` 37 项、`flutter analyze` 和默认 `flutter build web --release` 均通过。`dart run build_runner build` 后仅生成预期 Drift 输出。
- Web 运行时：用户启动的 Edge 138.0.3351.95 通过 CDP 执行 `tool/c3_edge_recording_store_smoke.mjs`，结果为 `{storageKind: "opfs", existsBeforeDelete: true, existsAfterDelete: false}`。这确认了实际选用 OPFS、写入、存在性检查与删除；未依赖 SQLite 存放音频。
- 验收结论：通过。Native 半成品保护/恢复、Web 持久化层级、tombstone、无损 feature-series、事务回滚和所列 capture contracts 均已覆盖。
- 下一张允许执行的卡：C4；不得进入 Phase 2。

### C4 执行记录（2026-08-05，已完成）

- 范围：Phase 1 最终本地/hosted gate、FRB Web 跨平台生成物策略修复，以及审计遗漏的日志脱敏和全局错误映射。
- C4 根因：Ubuntu 能成功生成 Rust WASM，但原 workflow 将 Windows 提交的 `wasm-bindgen` JS/WASM 编译产物错误要求为跨 host bit-exact，导致 `Reject FRB Web artifact drift` 持续失败。诊断 annotation 进一步确认声明式文件无漂移，仅编译型 JS/WASM 绑定对存在跨主机字节差异。
- 修复：Dart/Rust 和 Web package/snippet 等声明式输出继续执行严格 diff；JS/WASM 绑定对改为校验预期文件集合、package metadata、JS 语法、`WorkerRealtimeAnalyzer` 关键导出、WASM v1 magic/version，并继续要求 Rust WASM build、Flutter Web release build 和真实 Edge dedicated-worker runtime 通过。新增/忽略的意外生成文件仍会使 CI 失败。
- P1 补漏：新增结构化 `AppLogger`/`LogRedactor`、`AppErrorMapper`/`AppException`、recording/persistence/unexpected typed failures 和全局 providers。logger 不把 PCM/audio bytes、录音路径、设备/用户 ID、用户备注、token/secret/password 或原始异常消息传给 sink；mapper 只保留 failure、operation 和异常类型。
- 本地命令与结果：源码范围 format 111 files / 0 changed；`flutter analyze` 通过；`flutter test` 43/43；Windows fake integration 3/3；Rust fmt、Clippy `-D warnings`、tests 2/2；FRB Web artifact verifier、`node --check`、Rust WASM build、Flutter Web release build、Android debug APK 均通过。
- Edge runtime：`tool/c2_edge_worker_smoke.mjs` 再次得到 48,000 samples、90 frames、start-sample checksum `2,050,560`、RMS checksum `-831.3684525375677`、pitch checksum `19859.106033325195`，未出现 Runtime exception 或 DataCloneError。
- hosted CI：commit `ab66892` 的 [Dart/Rust](https://github.com/song751/voice-trainer/actions/runs/31013919871)、[Web](https://github.com/song751/voice-trainer/actions/runs/31013918939)、[Android](https://github.com/song751/voice-trainer/actions/runs/31013918972)、[Windows](https://github.com/song751/voice-trainer/actions/runs/31013919364) 均 completed successfully。
- 验收结论：通过。P1-01–P1-07 与 C1–C4 均完成，Phase 1 正式关闭。
- 未覆盖项：Apple/Linux 与 Android 真实麦克风仍按平台矩阵保留为后续真实设备覆盖，不属于 C4 自动化 gate，也未被虚报为通过。
- 下一张允许执行的卡：P2-01 确定性信号与 golden harness；不得直接进入 P2-02 或 MPM/YIN。

### P2-01 执行记录（2026-08-05，已完成）

- 范围：新增 `rust/src/golden/` 的确定性 PCM16LE 单声道生成器、`rust/test_assets/p2_01_manifest.json` 及其 JSON schema，并以 `rust/tests/p2_01_golden.rs` 验证。未修改生产 realtime analyzer、pitch、spectrum、resampler 或 bridge DTO。
- 信号集：48 kHz 运行时生成、无提交 WAV/录音；共 8 个 case：220 Hz 纯音、196 Hz 谐波、缺失 196 Hz 基频、seed `7` 的低能量噪声、110→440 Hz 两秒线性滑音、静音、1.25 倍幅度削波正弦，以及 sample `24,123` 相位重置断点。PCM 量化规则固定为 little-endian signed PCM16、`round(clamp(x, -1, 1 - 1/32768) * 32768)`。
- 哈希证据（按 manifest 顺序）：`pure_tone_a3` `0e1cabeb677c62a98e17221a4c91698069bd06502b45854d26593ecfc21c54c6`；`harmonic_series_g3` `b87a3fef20bd06159291f80791bd2a886ffbba46b8ccc03ea95c98e55a7d7dd3`；`missing_fundamental_g3` `5ce67f6df67ddfd6713d44892916c5d8bdfb9daa8f3d9018a62433bfebe9cc63`；`seeded_noise_7` `a95ca291f9915d08fae9b5c05c5e5bad224b377f8ca60d7734bb8703dfc44781`；`linear_glide_a2_to_a4` `929be8c4ea3d4bb2b8cbd62941e87f8214cb15f0b0ffd28b969fedeca163ff6a`；`silence` `55873fecc61a79e87ca550c7072e38ccdd7ecb600ace286fe4717952a97c42b0`；`clipped_sine_a3` `265b496d37f0287ae830bc5e81a360452865fcb27df06b731ae8c665148522d7`；`phase_reset_breakpoint_a3` `46fca510a36f270fbaea6cdca5b0e3ce3244609b10861c965bd955bce1c9fcb3`。
- 真值只记录独立可计算的频率、voiced 期望、RMS 范围、削波数量和断点语义，并保留后续算法 gate；没有将当前 Phase 0 FFT-autocorrelation 输出固化为“正确”答案。测试覆盖 manifest/hash 自校验、固定种子两次生成、PCM sample count/量化事实、削波和 RMS 真值、以及断点恰在声明 sample index 且确实不连续。
- 新增依赖：`sha2 0.10.9` 仅用于 manifest 的 PCM SHA-256；`serde` 的 derive 现在跨 native/WASM 使用以序列化测试 manifest，`serde_json 1.0.149` 仅为 dev-dependency 读取该 manifest。三者均为 Rust/WASM 兼容的 MIT/Apache-2.0 双许可依赖；没有运行时网络或资产加载，移除成本仅限 golden harness。
- 执行命令与结果：`cargo fmt --check --manifest-path rust/Cargo.toml`、`cargo test --manifest-path rust/Cargo.toml --test p2_01_golden`（4/4）和 `cargo clippy --manifest-path rust/Cargo.toml --all-targets -- -D warnings` 通过；完整 phase-boundary gate 见本卡最终复验。
- 未覆盖项：本卡没有评估 MPM/YIN、频谱、重采样、真实人声或跨 CPU/WASM 的 `sin` 数值一致性；这些不应由本输入 harness 冒充通过。
- 验收结论：通过。下一张允许执行的卡：P2-02 signal core；不得跳到 P2-03+。

### P2-02 执行记录（2026-08-05，已完成）

- 范围：新增 `rust/src/signal/{pcm,ring_buffer,dc_blocker,window,resampler}.rs` 和 signal module；将实时 analyzer 的 pending PCM 改为固定容量 `RingBuffer`，因此已移除实时 `Vec::drain`。未实现或修改 MPM/YIN、voicing 策略、full-band spectrum、features、bridge DTO 或持久化。
- PCM/窗口：PCM16 小端字节序会拒绝奇数字节输入并转换到固定半开 `[-1, 1)` f32 范围；DC blocker 固定 20 Hz 一阶 pole，并在 analyzer reset 时清除状态；Hann 窗采用后续 P2-04 使用的 periodic 定义，所有 window application 由调用方提供输出 buffer。
- 重采样：实现 48→16 kHz 专用的 63-tap Hamming-windowed sinc FIR 三相 decimator；因果 group delay 为 31 个输入 samples（约 0.65 ms）。它在 stream 中只保留固定 63-sample history，输出为严格 3:1；10 kHz 输入相对 1 kHz 的已测 alias-rejection gate 要求 `< -45 dB`。44.1 kHz 等非整数比率明确返回 unsupported，留待后续有单独基准/延迟评估时决定是否引入 rubato；没有新增依赖。
- 验证：signal 单元测试 11 项通过；`rust/tests/p2_02_signal_core.rs` 2 项通过，覆盖 P2-01 全部 8 个 case 的 DC-block + resample chunk-invariance、严格输出长度和静音不变；既有 realtime analyzer 的纯音与 chunk-invariance 两项继续通过。完整 Rust gate 与 phase-boundary Dart/Flutter gate 见本卡最终复验。
- 未覆盖项：未在本卡接入 pitch branch 或评估非整数输入率；尚未完成 P2-03 的 MPM/YIN、voiced decision 和真实人声 benchmark，也没有把 P2-04 spectrum 算法提前替换。
- 验收结论：通过。下一张允许执行的卡：P2-03 pitch/voicing；不得跳到 P2-04+。

### P2-03 执行记录（2026-08-06，已完成）

- 范围：新增 `rust/src/pitch/{estimator,mpm,yin,tracker}.rs`。两种 estimator 均实现相同 `PitchEstimator` trait；`PitchTracker` 使用 P2-02 的 DC blocker、48→16 kHz FIR、1024-sample pitch window 和 160-sample hop，并通过固定容量 ring buffer 保留 window。没有修改 spectrum、features、bridge DTO 或持久化。
- 算法与判定：MPM 使用 normalized square difference 的正局部峰并作三点抛物线插值；YIN 使用 CMNDF（threshold 0.12）和同一插值。voiced 判定同时要求 RMS ≥ -55 dBFS、clarity ≥ 0.60 和相邻有效 F0 不超过 250 cents；因此静音/低能量噪声不会仅凭周期候选被标为 voiced。连续滑音每 10 ms 的变化远低于该门槛，二八度突变会被抑制。
- golden 决策：P2-01 合成集上，YIN 的 220 Hz 纯音 P50/P95 绝对误差为约 0.112/0.121 cents，196 Hz 谐波为 0.065/0.067 cents，缺失基频为 0.057/0.060 cents，110→440 Hz 滑音 P95 为约 1.067 cents；静音和 seed-7 低能量噪声均为 0 voiced frames。MPM 保留为对照，但在相同 voiced gate 下有效帧显著更少，且这些稳定 case 的中位误差更高；故 `DEFAULT_PITCH_ALGORITHM` 固定为 YIN。
- 验证：`rust/tests/p2_03_pitch_golden.rs` 5 项通过，覆盖 MPM/YIN 比较与 default 选择、纯音/谐波/缺基频/滑音阈值、silence/noise false-positive、二八度 continuity 拒绝，以及任意 chunk split 的 glide 输出不变。完整 Rust 与 phase-boundary Dart/Flutter gate 见本卡最终复验。
- 未覆盖项：尚未完成 P2-04 full-band spectrum、P2-05 quality/segment aggregation、P2-06 bridge DTO 或真实人声分层 benchmark；MPM 仍保留为可重新调参的对照而非默认。
- 验收结论：通过。下一张允许执行的卡：P2-04 full-band spectrum；不得跳到 P2-05+。

### P2-04 执行记录（2026-08-06，已完成）

- 范围：新增 `rust/src/spectrum/{stft,bands,ui_bins}.rs` 与 module。它实现独立的 streaming 48 kHz full-band core：2048-sample periodic Hann、480-sample（10 ms）hop、预建 RustFFT plan 和固定容量 ring/FFT/window buffers。没有修改 P2-03 pitch/voicing、features、bridge DTO 或持久化。
- 归一化与输出：每个 FFT bin 使用单边、window-energy-normalized power（DC/Nyquist 不翻倍），所有 bin 的线性功率和等于输入 mean-square power；转换为 `10*log10(power)` dBFS，并在 -120 dBFS 截断。输出总 power、power-weighted spectral centroid、8 个物理频段（0–250、250–500、500–1000、1000–2000、2000–4000、4000–8000、8000–12000、12000–24000 Hz）和 20 Hz–24 kHz 的 128 个对数 UI bins。FFT→band/UI-bin 映射在初始化时预计算，实时帧不重新分配大缓冲或重复计算 log。
- 验证：bin-centred 1,875 Hz full-scale sine 的 total power 与所属 band 均为 -3.0103 dBFS（容差 0.02 dB），centroid 容差 0.1 Hz；silence 的 total/band/UI 输出均为 -120 dBFS、centroid 为 0；`p2_04_spectrum_golden` 3 项覆盖这些事实及 P2-01 全部 8 个 case 的 chunk-invariance、480 sample monotonic frame start 和固定 128-bin UI shape。完整 Rust 与 phase-boundary Dart/Flutter gate 见本卡最终复验。
- 未覆盖项：本卡不接入 bridge 或 UI，不实施 P2-05 的 clipping/低输入/断点/聚合，也不以 spectrum 物理量推断声学/医学结论。
- 验收结论：通过。下一张允许执行的卡：P2-05 aggregator/features；不得跳到 P2-06+。

### P2-05 执行记录（2026-08-06，已完成）

- 范围：新增 `rust/src/features/{quality,stability,onset,segment}.rs` 与 module。它接收内部 `FeatureInput`，输出内部 `SegmentSummary`；没有修改 FRB、Web worker、Dart mapper、数据库或 UI。
- 质量与有效性：`QualityFlags` 固定表示 clipping、input-too-low、dropped samples、discontinuity 和 insufficient valid frames。clipping 阈值为饱和 PCM sample 比例 ≥0.1%，低输入阈值为 RMS < -50 dBFS。segment 会比较连续 frame 的 monotonic sample index；任意间隙自动累计 dropped samples、标记 dropped/discontinuity，并将该帧排除出跨缺口稳定度统计。少于 30 个有效帧会标记 insufficient。
- 指标：pitch 先转换为连续 cents，pitch/level 均使用去趋势后的 median absolute deviation；趋势使用 median adjacent-frame slope，避免单个 octave/level outlier 污染稳定度。onset 从 -45 dBFS 能量越阈到连续 3 帧有效 voiced 的 sample-index delay 计算；它是描述性时序，不推断生理原因。
- 验证：`p2_05_features` 3 项通过，覆盖 P2-01 pure/clipped/silence 的物理质量 flag、outlier-resistant stability 与 onset，以及 sample-index gap 的 dropped/discontinuity/insufficient 判定。完整 Rust 与 phase-boundary Dart/Flutter gate 见本卡最终复验。
- 未覆盖项：未实现 P2-06 bridge DTO、P2-07 benchmark/gate、真实人声分层或任何将物理 feature 映射为医学/声门结论的规则。
- 验收结论：通过。下一张允许执行的卡：P2-06 bridge DTO；不得跳到 P2-07。

### P2-06 执行记录（2026-08-06，已完成）

- 范围：新增 Rust `AnalysisFrameDto`、FRB 生成声明、Web dedicated-worker DTO 和统一 Dart mapper；没有开始 P2-07 benchmark/gate，也没有恢复 FRB 2.12 WASM WorkerPool。
- 受限 wire contract：每帧只跨越 `startSample`、RMS/peak dBFS、optional F0、clarity、explicit voiced、8 个固定物理 band power 与 `u16` quality bitset。128-bin UI spectrum、spectral buffers、FFT plan、ring buffer、pitch tracker 与其他内部 DSP state 都不跨 FRB 或 worker 边界。Dart mapper 强制 band 数量恰为 8、拒绝未知质量位，并将五个已知 bit 映射为 domain quality enum；`spectrumBinsDb` 保持为空。
- 批次边界：native FRB `push_pcm16` 与 WASM `WorkerRealtimeAnalyzer.pushPcm16` 都拒绝大于 1,024 个 PCM16 sample 的请求；supervisor 既有的 capture 拆分仍是第一道限制。Web worker 同时保留自己的输入长度检查，所有层使用同一上限。
- 算法与 DTO 分离：`model::AnalysisFrame` 仍是内部类型。当前 realtime path 在既有 FFT 上累计 8 个 band power，并用 P2-05 `FeatureInput` 产出 physical clipping/input-too-low 位；API 层才转换为 dBFS DTO。为让 FRB 2.12 只扫描 `crate::api`，codegen 使用只在生成阶段启用的 `frb` Cargo feature 把 DSP modules 收敛为 crate-private；MPM/YIN unit estimator 标为 FRB opaque，避免 generator 将纯内部 unit struct 误判为桥类型。
- 修改文件：`rust/src/{api/realtime.rs,model.rs,pipeline/realtime_analyzer.rs,web_worker.rs,lib.rs,features/quality.rs,pitch/{mpm,yin}.rs}`、`flutter_rust_bridge.yaml`、FRB generated Dart/Rust、`web/analysis_worker.js`、native/Web mapper、shared Dart mapper 和 mapper unit test。过时的 generated `lib/src/rust/model.dart` 已删除，避免把 internal model 继续暴露给 Dart。
- 验证：`flutter_rust_bridge_codegen generate --stop-on-error` 成功；Rust DTO 固定 8-band 和 oversized native batch 拒绝已有 unit tests，Dart mapper test 覆盖 payload、quality bit 和 oversized spectrum 拒绝。最终复验：`dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool`（112 files/0 changes）、`flutter analyze`、`flutter test`（45/45）、`cargo fmt --check`、`cargo clippy --all-targets -- -D warnings`、`cargo test`（39/39）和 P2-01 窄测试（4/4）均通过；`flutter_rust_bridge_codegen build-web --release`、`node --check web/analysis_worker.js` 及 `flutter build web --release` 也通过。
- 未覆盖项：本卡没有重新设计 pipeline 的 100 Hz composition、没有把 128-bin UI spectrum 传给 Flutter，也没有运行 P2-07 的 Windows/Edge benchmark。真实 Edge runtime smoke 仍应由 P2-07 在新的 DTO contract 上记录。
- 验收结论：通过。下一张允许执行的卡：P2-07 bench/gate；不得跳到后续工作。

### P2-07 执行记录（2026-08-06，已完成）

- 范围：新增 `rust/tests/{chunk_invariance,pitch_golden,spectrum_golden,discontinuity}.rs`、`rust/benches/{realtime_pipeline,bridge_payload}.rs`，以及 `tool/p2_07_{windows,edge}_gate`。没有开始任何后续 Phase。
- Rust gates：四个新测试共 8 项通过。它们分别覆盖 P2-01 的全部 8 个输入在 realtime core、pitch tracker、full-band spectrum 的任意 chunk split 不变；steady P50 `< 1 cent`、harmonic P95 `< 5 cents`/无 octave lock、glide P95 `< 10 cents`、silence/noise 无 voiced；full-scale bin-centred tone 的 -3.0103 dBFS 与 centroid；以及 timeline gap/显式 dropped sample 的 discontinuity、有效帧排除和 insufficient gate。
- Windows release benchmark（`cargo bench --bench realtime_pipeline -- --seconds=10`）：48 kHz、1024 samples/batch、934 frames、25.462 ms，realtime factor `392.734x`。Bridge payload benchmark 同样处理 10 秒：最大输入 `1024 samples / 2048 bytes`、单调用最多 2 帧、每帧固定 8 band power、934 frames、27.187 ms，realtime factor `367.822x`；两项都强制 `>= 10x` realtime gate。
- Windows native runtime：`flutter run -d windows -t tool/p2_07_windows_gate.dart` 通过。48,000 samples / 1024 batch 得到 90 frames、start-sample checksum `2,050,560`、RMS dBFS checksum `-833.5675897598267`、pitch checksum `19858.987274169922`、maxBandPowers `8`、qualityFrameCount `0`。该工具同时拒绝非 8-band 或带有 spectrumBins 的 domain payload，并检查 voiced 与 optional F0 一致。
- 自动化复验：`node --check tool/p2_07_edge_gate.mjs`、Dart format（113 files/0 changes）、`flutter analyze`、`flutter test`（45/45）、Rust fmt、Clippy `-D warnings`、`cargo test`（47/47）和 P2-01 窄测试（4/4）均通过。FRB codegen、FRB Web release build 与 `flutter build web --release` 均通过；WASM release bundle 因此包含新 DTO。
- Edge/WASM dedicated-worker runtime：用户以实际 Edge CDP page 启动 release bundle 后，`node tool/p2_07_edge_gate.mjs 9222 http://localhost:7390` 通过。48,000 samples / 1024 batch 得到 90 frames、start-sample checksum `2,050,560`、RMS dBFS checksum `-833.5675888061523`、pitch checksum `19858.990264892578`、maxBandPowers `8`、qualityMaskOr `0`；1025-sample 输入被拒绝，未出现 browser exception 或 DataCloneError。
- 验收结论：通过。P2-07 的 Rust golden/invariance、bench、Windows native runtime 与实际 Edge/WASM runtime 均已通过，Phase 2 DSP MVP 固定卡正式关闭。
- 未覆盖项：Phase 3 尚未定义；真实麦克风平台矩阵仍须按其独立任务和设备证据执行，不能由本合成流 gate 替代。
- 下一步：在开始任何后续实现前，先定义、审查并接受单独的 Phase 3 任务卡。

### P3-01 执行记录（2026-08-06，已接受）

- `RealtimeAnalyzerCore` 已从 Phase 0 autocorrelation 骨架换为 P2 YIN、48→16 kHz FIR pitch branch、48 kHz 2048/480 full-band STFT、质量帧和 `SegmentAggregator` 的单一生产合成路径。输出只在对应的 100 Hz pitch/full-band frame 都可用时生成；没有为尾窗补零。
- 生产桥新增显式 `startSample` entry，所有 frame/summary timeline 来自该单调 sample index；本卡只允许连续 48 kHz 输入并拒绝不连续 index。有效格式、间隙和 backpressure 的 typed failure 仍留给 P3-02。
- 新 production-entry golden/invariance gate 覆盖 P2-01 全部 8 输入、任意 split、timeline、YIN truth、quality/segment summary 与受限 8-band DTO。当前本地复验：Rust fmt、Clippy `-D warnings`、`cargo test`（49）；Dart format、`flutter analyze`、`flutter test`（45）；FRB generate/build-web、Web worker syntax 和 Flutter Web release build 均通过。
- 未覆盖：未把真实 capture、format 变化、drop/gap、UI、录音或数据库混入该卡；这些不应被本地合成 production gate 冒充为已通过。仓库所有者已接受，P3-02 已解锁。

### P3-02 执行记录（2026-08-06，已接受）

- 完整 `CaptureFormat` 现在进入分析配置；生产 Rust adapter 在 bridge 前明确拒绝 44.1 kHz、非 mono、非 PCM16、奇数字节/非完整 frame、格式变化及倒退 sample index，并保留可映射的 `AnalysisFailureReason`。
- FRB 和 dedicated Web Worker 都改为传递绝对 `startSample` 与断点元数据。Rust 在 gap/pause-resume 后重启内部 streaming windows、保持 sample timeline 单调、设置 frame/summary 的 dropped/discontinuity 证据并使跨断点统计无效；同一缺口不会被重复计数。
- Coordinator 使用 `CaptureSession.effectiveFormat` 初始化 analyzer、在 resume 和格式变化时显式传播状态。自动化复验：Rust fmt/Clippy/tests（51）、Dart format/analyze/tests（47）、Windows fake-capture integration（4）、FRB Web build、Web syntax 与 Flutter Web release 均通过；native smoke 为 48,000 samples、94 frames、8 bands。未把 fake/runtime build 视作真实麦克风或 P3-03 默认装配的替代证据。仓库所有者已接受，P3-03 已解锁。

### P3-03 执行记录（2026-08-06，已接受）

- Windows default provider 已由 fake 改为 `RecordAudioCapture` + `RustAnalysisEngine`，而非 Windows/Web/其他 native 继续各自默认启用。Coordinator 发布 raw frame、capture health、worker metrics；worker metric 包含 drop/restart/fallback/state，且仍通过有界队列防止 capture callback 等待分析/UI/存储。
- Fake override 保持可用。Windows integration 已在真实 plugin runner 检查 default composition；fake integration 覆盖 typed analysis init failure、format/pause/drop 和三类 stream。完整 Rust（51）、Flutter（47）、Windows integrations（6+1）和 Web release build 均通过。
- 未运行真实麦克风，不把 default composition、fake flow 或构建结果表述为 P3-07 的设备证据；仓库所有者已接受，P3-04 的 UI decimator 已解锁。

### P3-04 执行记录（2026-08-06，已接受）

- 以 sample-index 而非 wall clock 将 100 Hz `AnalysisFrame` 降至 25 Hz `UiAnalysisFrame`；每秒 100 个 480-sample raw frames 的确定性测试只产生 25 个 UI snapshots。pitch history 始终限制为 600 个 raw points，并携带 unvoiced/null 与 discontinuity，避免伪造连续 pitch curve。
- Live 页面只 watch decimated StreamProvider，而非 Coordinator 的 raw stream/PCM。它以 `CustomPainter` + `RepaintBoundary` 显示固定 ring，并展示目标音、note/cents、RMS 与描述性 quality chips；未引入 chart 或其他生产依赖。
- 本机复验：窄 Flutter tests 8 项、Dart format、Flutter analyze、Flutter test 50 项、Rust fmt/Clippy/tests 51 项和 Flutter Web release build 都通过。Web build 的 Cupertino font 提示及 Wasm dry-run 信息均非失败。
- 未作真实麦克风、Windows UI frame time、延迟或 soak 量测；不得把该自动化/构建结果视为 P3-07 的设备或性能证据。仓库所有者已接受，P3-05 的录音与持久化已解锁。

### P3-05 执行记录（2026-08-06，已接受）

- Windows persistence 默认通过 application-support 路径懒打开 Native Drift database 与 WAV recordings；`RecordingSink.open` 等待 `.partial` 清理和 recording tombstone recovery，避免恢复尚未完成时写入新 PCM。没有加入新的生产依赖。
- Packed feature schema v2 增加固定 8 个 P2 physical band power 列，仍是 100 Hz shared sample-index timeline 和版本化/校验 BLOB；旧无 band 的 v1 feature series 仍可读取。录音删除使用先 durable tombstone、再删 blob、最后删 locator 的顺序；session delete 在录音成功处理后删除所有 runs/feature metadata/BLOB rows。
- 注入覆盖 append、finalize、DB save、foreign-key transaction、blob deletion tombstone/recovery；全量 Dart 55、Rust 51、Windows default-composition integration 和 Web release build 均通过。Windows real microphone、旧磁盘 migration fixture、磁盘失败、crash/restart、soak 与性能数据仍未执行，均保留给 P3-07。

### P3-06 执行记录（2026-08-06，已接受）

- 将 Rust `SegmentSummary` 增加为 finalization-only DTO，并在 native FRB 和 explicit Web WASM worker 中完成映射；Dart domain 保存 valid/total frame、dropped samples、quality flags、MAD/slope 与 onset measurement。没有扩大 raw frame 或 Web message payload。
- 命中率在 Dart 根据 template target 计算；只计入 voiced、无 clipping/input-too-low/drop/discontinuity 的有效帧。确定性规则先执行 quality gate：低质量/不足帧只建议改善录音，不输出任何医学、声门或发声机理判断。
- session summary 扩展数据经 Drift v4 `summaryJson` 持久化，旧 v3 session 保持可读；结果页和最近历史列表仅消费 session summary/repository，未监听 100 Hz frame stream。
- 新增 hit-rate、quality suppression、determinism、summary persistence/history read 和 Rust finalization bridge 测试。Dart 58 项、Rust 52 项、静态检查、FRB Web build、Web worker syntax 和 Flutter Web release build 通过。仓库所有者已接受；真实设备 P3-07 现已解锁。

### P3-07 剩余工作重排（2026-08-07，规划记录）

- P3-07 仍是未完成状态。已经取得内置/USB 真实 capture、USB 拔插/回插和 30 分钟 capture-only 证据；它们不会因本次重排失效，也不会被扩大解释为正式 product pipeline 通过。
- 仍缺权限拒绝/撤回、全部输入不可用、可观察的格式变化、真实写盘失败、进程崩溃/重启恢复、production 端到端 P50/P95、Live UI frame time 和 streaming recorder 内存趋势。仓库所有者当前远程办公，无法完成 Windows 设置、物理设备和故障介质操作。
- 为避免远程模型反复卡在人工步骤，P3-07 固定拆为 P 工作树核验/封存、A 证据合同、B production metrics、C 故障 runbook/gate hook、D 现场实机矩阵、E 证据汇总。由于已接受的 P3-01→06 仍在大量未提交改动中，当前先解锁 P3-07P；A–C 的 synthetic/fake 结果不得满足 D 的真实设备项。
- Phase 4 Android/Web 固定任务卡已写入 `docs/PHASE4_TASKS.md`。仓库所有者随后授权：P3-07P 与 P3-07A→C 接受后，若现场条件仍不可用，可以逐卡执行 P4-00→P4-13 的远程实现路径；P3-07D/P3-08、Android 真机、真实浏览器麦克风和 P4 Closure 仍保持硬 Gate，模拟器/root/fake 不得替代。

### Android emulator/ADB 远程基线（2026-08-07，规划证据）

- 当前运行 MuMu Player 12；Android SDK `platform-tools` 的 `adb 37.0.1` 已显式连接 `127.0.0.1:7555`，`flutter devices --device-timeout 10` 将其识别为 Android mobile device。
- 设备报告 Android 15/API 35、x86_64、1080×1920、480 dpi，产品/模型伪装字段为 `PD2362`/`V2362A`。这些字段只用于 emulator compatibility，不得记录为 vivo 真机覆盖。
- PackageManager 声明 microphone 与 low-latency audio；AudioFlinger 历史 input path 包含 48 kHz PCM16（同时也存在 16 kHz path）。这足以安排 record/format/bridge smoke，但不能证明宿主转发麦克风的真实性、AGC、路由、延迟、掉帧或音质。
- MuMu 私有 ADB 支持 `adb root`，重启后标准 SDK ADB shell 为 uid 0；镜像没有普通 `su` 命令。root 只允许用于测试包沙箱/明确可丢弃路径的可恢复故障注入，不能成为产品或通过条件。
- 当前 shell PATH 不包含 SDK `adb.exe`，后续 preflight helper 必须从 Android SDK 解析绝对路径或接收显式参数，不能假定裸 `adb` 命令可用。

### P4-00 Android emulator/ADB 基线（2026-08-07，已接受）

- `tool/p4_00_android_preflight.dart` 已将规划基线固化为可重复命令。它优先使用显式 `--adb-path`，否则只查找 `ANDROID_SDK_ROOT`、`ANDROID_HOME` 或 `%LOCALAPPDATA%\\Android\\Sdk` 下的 Platform-Tools；未找到时提供安装/参数提示，绝不回退到 MuMu 私有 ADB 或裸 `adb`。
- 实测 `dart run tool/p4_00_android_preflight.dart --endpoint 127.0.0.1:7555`：SDK ADB 连接、Flutter machine detection 均成功；API 35、ABI `x86_64`、physical 1080×1920 / 480 dpi、microphone 和 low-latency feature 都为 true。当前 shell 是非 root（`rootShellObserved=false`）；工具不执行 `adb root`。
- JSON 仅报告 endpoint、SDK ADB 来源类型、Flutter device id 和能力字段；不输出绝对 SDK 路径或 model/product/serial。每次报告固定 `evidenceType=emulator`、`emulator=true`、`realDevice=false`，因此只能作为模拟器 API/格式/bridge smoke 的入口，不能证明真实麦克风、AGC、路由、延迟、掉帧或真实设备支持。

### P4-01 PlatformCapabilities 与组合边界（2026-08-07，已接受）

- `PlatformCapabilities` 是不含 platform API 的不可变值对象；统一声明 capture/persistence adapter mode、analysis worker mode、maximum recording duration、device selection 和 lifecycle event capability。profile 覆盖 Windows、Android、Web、other native，令未验收平台的 fallback 可由 tests 审核而非散落条件判断。
- 只有 `lib/app/platform_capabilities_native.dart` 和其 Web conditional peer 执行运行时检测。composition 据此选择默认 adapter/persistence：Windows 保留 P3 已接受的 production 组合；Android/Web/other native 仍用 fake/in-memory fallback。P4-03、P4-04、P4-09、P4-10、P4-11 才可以逐项改变相应 profile。
- 本卡没有更改任何 capture、DSP、persistence 实现、数据库、页面或 Rust 算法，也没有将 Android emulator 或 Web fake 结果升级为真实设备/浏览器证据。

### P4-02 Android build 与 Rust bridge smoke（2026-08-07；2026-08-26 复验并封存）

- API 35/x86_64 emulator 上的 `p4_02_android_rust_bridge_smoke_test.dart` 已真实运行 Rust greeting 与 `FrbAnalysisWorker`。一秒 48 kHz mono PCM16 synthetic 220 Hz signal 分为 1024-sample batches；Android/Windows 都为 94 frames、start-sample checksum `2,098,080`、pitch checksum `20,681.109375`。RMS checksum 的跨平台绝对差约 `1.8e-5`，保留浮点容差而非要求 byte-identical float。
- `flutter build apk --debug` 和 release candidate 已实际构建；release archive 检查到 `lib/x86_64/librust_lib_voice_trainer.so`。SDK ADB release smoke 已安装、两次 force-stop/relaunch，并未发现 `UnsatisfiedLinkError`、`FATAL EXCEPTION` 或 `Fatal signal`。
- 所有本条结果固定为 `emulator` / `synthetic`；它们证明 x86_64 library、FRB runtime、bounded DTO 与 process restart，不证明真实麦克风、route、AGC、延迟、掉样或 Android production capture。Android 的 default composition 因此继续保持 fallback，直到 P4-03。
- 2026-08-26 多实例复验时，仓库所有者确认原竖屏实例对应 SDK ADB endpoint `127.0.0.1:16384`；preflight 再次报告 API 35、`x86_64`、1080×1920、480 dpi。`7555` 当前属于另一实例，因此 P4-02 工具不再提供默认 endpoint，调用方必须显式选择，防止把不同模拟器的结果混入同一证据。
- Windows 与该 Android 实例上的 debug integration 均重新通过。Windows 首次受 VS 2022/2026 CMake cache 冲突阻断，`flutter clean` 后复验通过；Android 首次受并发 Gradle/CMake 共享 build 目录文件占用阻断，停止并发、清理后复验通过。这两次均为可再生成缓存/执行串行化问题，不作为产品 gate 通过或失败。
- release 证据由“APK 内存在 `.so` + 进程存活”加强为真实调用：`tool/p4_02_android_release_main.dart` 执行同一 deterministic production analyzer probe，只有完整合同满足才显示 `P4_02_RELEASE_BRIDGE_OK frames=94 samples=2098080`。release APK 在 `127.0.0.1:16384` 两次 force-stop/relaunch 后均读到该 sentinel，且 app PID/包名相关日志没有 `UnsatisfiedLinkError`、`FATAL EXCEPTION` 或 `Fatal signal`。
- MuMu 的 `uiautomator dump` 在成功写出 hierarchy 后会以 139 退出并使 crash buffer 记录 `Cmdline: uiautomator`。脚本因此以可读取的 sentinel XML 为实际 UI contract，并把 crash 检查限制到本次 app PID/包名；不会把工具自身崩溃误报为应用崩溃，也不会接受历史/其他 app 的 last-300 日志。
- 仓库所有者于 2026-08-26 授权在文件边界清楚、证据等级不变的条件下并行推进后续 UI、Android production 和歌曲对比设计。P4-02 因此以本次全 gate 复验作为分支基线，不再等待单独的逐卡口头确认；真实设备、真实麦克风和版权/模型依赖仍分别保留硬 gate。

### 反馈产品化并行切片（2026-08-26）

- `SessionSummary` 新增可空的 `targetDeviationMedianCents`。它由有效 voiced frame 相对练习目标的 signed cents deviation 中位数计算，并随既有 `summaryJson` 向后兼容持久化；旧记录缺少该字段时保持 `null`，不需要 schema migration。
- 在质量 gate 通过后，确定性规则现在可生成以下描述性 Observation：目标音整体偏高/偏低、pitch MAD 较大、pitch slope 上升/下降、level MAD 较大、level slope 上升/下降、稳定音形成延迟。每条都包含测量值、对应技术门槛、confidence、scope 和 quality flags；目标相关建议引用版本化的 `PITCH-MATCH-01` 内容 ID。
- 当前 v1 门槛为 pitch MAD `15 cents`、pitch slope `8 cents/s`、level MAD `2 dB`、level slope `1 dB/s`、onset delay `24,000 samples`（当前生产输入仅接受 48 kHz，即 0.5 s）。这些是可解释的产品起点，不是临床或生理阈值；没有输出提喉、挤压、漏气、闭合不足、疲劳风险等结论。真实人声分层验证前，UI 必须把它们表述为“测得变化”，不能表述为技术诊断。
- 窄测试覆盖 signed median 对离群值的稳健性、全部新增 rule、低质量 suppression 以及 summary round-trip；完整 `flutter test` 为 80/80，format/analyze 通过。

### P4-03 Android capture/DSP production composition（2026-08-26，已完成，待集成接受）

- Android capability 只提升 `RecordAudioCapture` 与 native `RustAnalysisEngine`；persistence/lifecycle 仍为 fallback，Web 与 Rust DSP 算法不变。默认 adapters 继续由 capability 驱动，fake provider override 仍可完整替换。
- 真实 composition smoke 发现应用默认路径没有先调用 `RustLib.init()`；P4-02 的专用 probe 自行初始化因而未暴露该问题。`FrbAnalysisWorker` 现在在创建 analyzer 前幂等初始化 FRB，并在初始化失败时清除缓存 Future，以允许 supervisor restart/fallback 再试。
- API 35/x86_64 emulator `127.0.0.1:16384` permission granted smoke：请求与 effective format 均为 PCM16 mono 48 kHz，188 chunks / 48,128 samples，真实 plugin pause/resume/stop 成功，production Rust analyzer产生 94 frames。报告不保存 PCM，不判断这些输入是否为真实麦克风/真人声。
- 同一 emulator 在 `RECORD_AUDIO` 预先 revoke 且设为 user-fixed/user-set 后，permission smoke 返回 denied、capture 未启动、0 analysis frame；测试结束后 integration package 被卸载。另一个 emulator integration 以 fake/synthetic contract 覆盖 unsupported/changed format、worker failure 和 queue drop，不能替代真机证据。
- `tool/p4_03_android_permission_test.ps1` 在 Flutter 安装 integration package 后轮询包出现，并使用标准 SDK ADB 的 `pm grant/revoke` 与 `appops allow/deny` 自动设置 `RECORD_AUDIO`。这解决了测试包每次重装后权限丢失造成的人工弹窗；正常 allow/deny gate 不使用 root。root 仍只允许用于明确隔离、可恢复的存储故障注入，不能成为产品或录音权限前提。

### P4-04 Android native persistence/recovery（2026-08-26，已完成，待集成接受）

- `PlatformCapabilities.android.persistence` 提升为 production；`default_persistence_native.dart` 将 Windows 专属 lazy host 通用化为 Windows/Android 共享 host。两平台仍只构造同一套 Drift repository、streaming WAV sink/store 与 startup recovery，没有平台复制、schema version/BLOB 语义、新依赖、Web/UI 或 Rust 变化。
- v1 file-backed fixture 发现并修复旧迁移的重复列缺陷：从 v1 新建当前 metadata 表时已经带 `feature_schema_version`，后续迁移现在先核对列是否存在再补列。目标仍是现有 v4 schema，旧/新 packed feature codecs 未改变。
- Windows runner 与 API 35/x86_64 MuMu emulator `127.0.0.1:16384` 上，同一 4 项 integration 均通过：WAV append/finalize、session save/read/history/delete、adapter close/reopen、native transaction rollback、tombstone/partial recovery、v1→v4 migration 和迁移后写读。所有 Android 结果均为 emulator evidence。
- release APK 的 gate-only main 首次写入 application-support 后显示 created sentinel；SDK ADB force-stop/relaunch 后显示 restored sentinel。JSON 明确 `emulator=true`、`realDevice=false`，Flutter application-authored log 没有持久化绝对路径，未发现 app crash signature。脚本只清空测试包自己的 sandbox；不读取录音、设备标识或宿主路径。
- 验证：Dart format（158 files/0 changed）、Flutter analyze、Flutter unit/widget（90/90，排除既有依赖主工作树路径的 P3-07 disposable-root test）、Rust fmt/Clippy/tests（52）均通过；Android debug integration 4/4、release APK build 和两次启动恢复 gate 通过。该 emulator/文件证据不覆盖真机存储权限、磁盘耗尽、厂商清理策略或真实麦克风。

### SRD-01 歌曲人声分离基线（2026-08-26，R&D evidence only）

- 隔离范围：新增独立 `tool/song_separation` Cargo package 与开发期 Python oracle；没有修改 Flutter、FRB、production Rust、P4 composition、DSP 阈值或观察规则。手工 `mixture/vocals/accompaniment` fallback 只校验等长 PCM16 WAV、输出 hash，并固定 `generated_by_model=false`。
- 官方权重：从 Zenodo record 3370489 获取 `vocals-b62c91ce.pth` 到 `%TEMP%`，本地大小 `35,637,796` bytes；MD5 `d918985fad0fedf6d9ce89e279aa7218` 与上游发布值一致，SHA-256 为 `b62c91cedbc7a066f1778ead5b5cecb377aa3a46a31af1cce7c5c8769339d083`。权重和音频均未进入 Git。
- 实际 oracle：Windows CPU、Python 3.13.5、PyTorch `2.11.0+cu128`、Open-Unmix `1.3.0` 对确定性 1 秒、44.1 kHz stereo PCM16 合成输入完成 vocals-only + residual 推理。输入/输出均为 `44,100` frames；warm-run inference `0.021163 s`，进程 peak working set `640,258,048` bytes。vocals 输出 `176,444` bytes / SHA-256 `a6e3ad02db7f07711634f13a810ecaae9507b895f94b4aeb9a04871a614e8488`；accompaniment 输出 `176,444` bytes / SHA-256 `aaa056efd168651f21886fa25491f048c756636d7f15deb5767b1a9d8dd37017`。这是合成 contract smoke，不是分离质量证据。
- 导出实际结果：同一脚本以 `--export-onnx` 进入 core export stage，但隔离环境未安装开发期 `onnx`，返回 typed `export_dependency_missing`；没有创建伪 ONNX 文件。tract/ONNX Runtime 尚未加入或验证，不能据此进入 production。
- 自动化：Rust harness 4 项测试覆盖 deterministic fixture、rights gate、取消和 stem mismatch；Clippy `-D warnings` 通过。未覆盖 30 秒/3 分钟/5 分钟性能、真实许可歌曲质量、ONNX 数值一致性、Windows production/Android/Web runtime；这些仍是 ADR 0002 的下一 gate。
- 产品文件入口采用 Flutter 官方维护的 `file_selector 1.1.0`（BSD-3-Clause），支持 Android、Web 与 Windows 的单文件选择，并解析到已修复 CVE-2024-54461 的 Android endorsed implementation。它只负责用户主动选择本地音频，不读取媒体库、不抓取流媒体、不上传云端；取消选择是正常 typed outcome。平台插件失效时 fallback 为手工重试/功能不可用提示，移除成本局限于 `SongFilePicker` infrastructure adapter 与 pubspec，不进入 domain、分离器或对比算法。

### 歌唱反馈与课程证据地图（2026-08-26，R&D draft）

- 新增 `docs/SINGING_PEDAGOGY_EVIDENCE_MAP.md` 与 ADR 0003，将现有 pitch/level/periodicity/onset/spectrum 和未来歌手 stem 对比收敛为 `measurement → Observation → reviewed exercise`，明确列出证据等级、课程模块、content schema、quality suppression 和不可推断事项。
- 当前最适合先验证的教学路径是舒适音区 pitch matching、3–4 音 pattern 和实时视觉反馈；成人随机训练有正向但短期、个体差异明显的证据。SOVT 有临床 RCT、业余合唱歌手 RCT 和范围综述支持作为候选，但不足以由单一指标自动触发为治疗。
- timing、level、range、spectrum 与 reference A/B 练习仍标为 `U/PED`。所有内容默认 unreviewed；需声乐教师与 SLP/嗓音医学联合复核后才可进入 production catalog。
- 安全边界采用 AAO-HNSF dysphonia 指南：应用不从音频诊断症状；疼痛/严重警示症状停止并转介，持续声音异常 4 周未改善应提示喉科/耳鼻喉评估，临床 voice therapy 前需要诊断性喉镜检查。
- `Recommendation` 产品合同现已携带 content version/review status、confidence、scope、quality flags、数值 evidence、证据等级/source IDs 和 limitations。质量失败只生成 `REC-QUALITY-01`；音准未达目标时生成 `PITCH-MATCH-01`，结果页展示练习步骤、研究等级和“尚未专家审核”状态，并包含疼痛/明显不适/呼吸困难时停止的安全提示。其他低证据课程尚未自动触发。

### SRD-02 UMX-HQ core ONNX/runtime smoke（2026-08-26，R&D evidence only）

- 开发依赖：隔离环境固定 `onnx 1.22.0`（Apache-2.0）用于格式检查/导出，`onnxruntime 1.29.0`（MIT）作为 native 备选 oracle；独立 tool Cargo package 固定 `tract-onnx 0.23.5`（MIT OR Apache-2.0）作为 Rust-first smoke。三者均未加入 production。fallback 仍为手工双 stem；移除时删除 tool scripts/Cargo dependency，不影响 Flutter/FRB/realtime DSP。官方许可来源：[ONNX](https://github.com/onnx/onnx)、[ONNX Runtime](https://github.com/microsoft/onnxruntime/blob/main/LICENSE)、[tract](https://github.com/sonos/tract)。
- 初次 direct trace 暴露真实失败：上游 forward 的 `.data.shape` 固化 32-frame reshape，ORT 47-frame 运行失败，tract 47-frame prepare 返回 typed `backend_incompatible`。导出器改为语义等价、保留动态 `.size()` 的 development-only wrapper 后，opset 17 core 重复导出 hash 一致：`1dd15a2be2f15ba035205f866a035df38d85b27824ad67fe53566e80ec1f4258`，`35,626,526` bytes；模型不入 Git。
- ORT CPU 32/47/300-frame 对 PyTorch max-abs 为 `8.27e-7 / 8.53e-7 / 1.53e-6`；300-frame inference `0.0568 s`、session `0.0551 s`、报告时 RSS `804,552,704` bytes。tract CPU 对应 max-abs `1.05e-6 / 1.04e-6 / 1.13e-6`，300-frame release inference `0.2679 s`、load/prepare `0.1155 s`。
- Windows unstripped `tract_smoke.exe` 为 `25,375,744` bytes，只是全 ONNX loader 的 harness 尺寸，不是 production 增量。tract 上游现建议 facade/NNEF 路线；若未来采用，应评估固定模型转 NNEF/OPL、裁剪 operator、stripped size、Android/Web 与许可证清单，不能直接复制本 harness。
- 当前成功仅限 vocals magnitude core；尚无 production STFT/ISTFT、mask/Wiener/residual、长音频分块、取消延迟、Android/Web 内存或许可歌曲质量证据，不关闭歌曲导入功能。

### 发声方式、声区与音色多维框架（2026-08-26，R&D contract）

- 新增 `docs/REGISTER_AND_TIMBRE_FRAMEWORK.md` 与 ADR 0004。框架把假声、头声、胸声、混声（强混/弱混）和金属性分成任务意图、人工听感标签、radiated acoustic output 与实验室 physiology/aerodynamics 四层；明确拒绝“闭合程度单轴”和 consumer-mic 自动唱法分类。
- 证据结论保留分歧：Roubeau/Henrich 的 M0–M3 是 EGG/laryngeal-mechanism 层；Castellengo 5 人 voix-mixte 研究支持 M1/M2 内的强度/频谱调整，Kochis-Jennings 7 名女性显示 chest→mix→head 的多参数梯度，Lee 等 12 人研究则报告 mix 的独特 aeromechanical profile。差异说明 label、任务、样本和 modality 必须成为 scope，不能挑一个研究写全局阈值。
- CVT `metal/density` 的 2026 double-case 只有两名歌手，虽然 SPL、Psub、CQ、harmonic richness 等形成多维差异，仍仅支持保存 CVT-specific perceptual label 与研究假设；不支持从谱质心/2–4 kHz 能量自动识别 metal、twang 或喉部收窄。
- 新增平台无关 `voice_production_profile.dart`：human label provenance 保存词表版本且没有 algorithm source；measurement 强制 domain/modality 对应，consumer microphone alone 不能构造 vocal-fold contact、kinematics、muscle 或 aerodynamic evidence；comparison scope exact-match pitch/vowel/loudness/style/capture/protocol/algorithm，并在 label-targeted task 中匹配词表版本和目标 label；confidence 取 signal/task/repeatability/label-agreement 的保守最小值。6 项 domain tests 通过。
- 本切片没有修改 Rust/DSP、Drift/schema、Observation rules、UI 或依赖。它只提供研究与未来产品的数据边界；自动 head/mix/metal classifier 仍需授权分层数据、跨标注者协议、实验室子样本、外部验证和设备 error/suppression analysis 后另立任务卡。

### P4-09 Web capture + Rust worker production composition（2026-08-26，已完成，待集成接受）

- Web profile/default adapter 现在使用 `RecordAudioCapture` + `RustAnalysisEngine`，dedicated Worker 是主路径，已验证的 FRB/WASM 主 isolate 路径仅作 supervisor 的显式 fallback。Web persistence 仍为 in-memory fallback，未新增依赖，未修改 Rust 算法。
- capture adapter 在 512-sample 配置启动失败时可有界重试 1024，但不吞掉 permission/device 类 typed failure。Web worker 的 request/reply envelope、frame/summary 和 quality mask 严格校验，malformed/unknown DTO 不再被宽松接受。
- 本地 Edge release 自动化：权限 deny 正确阻止 capture；canonical 48 kHz mono synthetic worker 输入得到 94 个有界 8-band DTO，start-sample checksum `2,098,080`，unknown operation/crash/pending rejection/replacement 均通过，且 `crossOriginIsolated=false`。fake audio device 经过真实 `record_web` 插件路径输出 94 个 512-frame chunk / 48,128 samples，报告的 effective format 为 44.1 kHz stereo，production analyzer 因而返回 typed `unsupportedFormat`。该证据是 synthetic browser capture，不是真人声或真实麦克风通过。
- P4-15 仍需在 Edge/Chrome/Firefox 上用真实麦克风覆盖 effective format、512/1024 cadence、background、devicechange 和性能门槛；Safari/iOS Web 仍需 Apple runner。

### SRD-03 许可质量与 reference-F0/DTW gate（2026-08-27，非人工实现完成）

- 无 production 依赖变化：新增代码仅在既有 `tool/song_separation` package 内，复用固定的 serde/sha2；没有修改 Flutter、FRB、production Rust 或 platform composition。移除成本为删除 quality module/schema/tests/protocol，不影响录音或实时 DSP。
- 数据门禁：strict v1 manifest 逐 case 固定 license/source/verifier/date、`model_output|synthetic_identity` provenance、`monophonic_lead|not_eligible` pitch scope、Git 外相对路径与四个 SHA-256。运行时拒绝未确认 rights、未知字段、重复 ID、路径越界、hash、格式或长度不符；报告不输出路径、曲名或 PCM。
- 算法：44.1 kHz stereo PCM16 whole-excerpt SI-SDR、mixture baseline/improvement、residual error、RMS/clipping。F0 分支 stereo→mono、3 点均值降到 14.7 kHz，1024 window/147 hop，60–1000 Hz normalized autocorrelation，随后 20%/至少 10 帧 bounded DTW；版本 `srd03-quality-v1`。这不是 museval/BSS Eval v4，也不是 production pitch 或教学规则。
- 安全边界：和声、叠唱、多人声或未经听觉核对的 reference 必须 `not_eligible`；此时 `pitch_interpretation_suppressed=true`，但不抹掉有效 waveform evidence。waveform confidence 取 level/clipping/residual 的保守最小值，pitch confidence 取 reference/estimate voiced coverage 的较小值。
- 实际 Windows smoke：通过官方 `MUSDB18-7-STEMS.zip` 获取一个 6.80 s/300,032-frame research sample。MUSDB 官方说明其 150 曲来源和许可混合、访问限 academic；本 case 属 DSD restricted，仅用于本地研究，资产未提交。官方 UMX-HQ oracle inference `0.12564 s`、peak RSS `748,175,360 bytes`；mixture/reference/estimate/residual SHA-256 分别为 `247a97eb75a5be90d621a3b11bcfcd26f5fb3785fa77c79f25a2d5add322851b`、`e854bb2c388c8bfc4e9c164c0fd6dca29965a329808e030146cb077d3151a0ff`、`272a76e259cec66831d5f12b672757b08b34a8b8dfaf49c131113df578f913b1`、`4af7724430d253833f0f13b840cfb30c61933cb09bc0e9c62047fc5c7b14b781`。
- evaluator 结果：vocals SI-SDR `12.287948 dB`，mixture baseline `-4.924369 dB`，improvement `17.212317 dB`，residual error `-98.628172 dBFS`，reference/estimate clipping 均 `0`。因没有人工听觉核对，本 case 的 pitch scope 为 `not_eligible`，不生成 F0/DTW 质量结论。6 项新增确定性测试加既有 4 项 contract 全通过。
- 剩余 gate：仓库所有者逐曲确认可用的授权集并人工标记单旋律 reference；运行多曲 MUSDB18-HQ/等价授权全带宽集合和听感复核。SRD-04 才能实现 production decode/resample→STFT/core/mask/ISTFT→vocals/residual、长音频分块/边界/取消与 Flutter adapter；当前产品自动分离继续 unavailable。

### P4-10 Web persistence + 60-second sample limit（2026-08-27，已完成，待集成接受）

- Web default persistence 已从 fallback 提升为 production。Drift Wasm 负责会话/summary/packed feature columns，独立 OPFS→IndexedDB BlobStore 负责 WAV；若 Drift 选择 `inMemory` 或录音两种持久化 API 都不可用，组合返回 typed `PersistenceFailure`，不保存内存假历史。
- `PersistenceStorageReport` 提供脱敏 storage kind。Edge 真实 release runtime 在无 cross-origin isolation 的本地服务上选择 Drift `sharedIndexedDb` 与 recording `opfs`；1 秒同构边界得到精确 `96,044` bytes WAV，创建后整页 reload 能从 history/DB 读回 locator 并确认 Blob 存在，tombstone delete 后 DB/Blob 均消失，随后可重新创建。typed persistence reason 会保留到 application `Failed.failure`。证据固定为 `synthetic_browser_storage`、`realMicrophone=false`。
- JS deterministic contract 覆盖 OPFS 成功/reload/delete、OPFS quota append 失败清理后 IndexedDB fallback、两侧不可用的 `privateMode` 结果与 quota typed 结果。Dart tests 覆盖结果到 `PersistenceFailureReason` 的映射以及 Drift `inMemory` 拒绝。录音 bytes 没有 SQLite column，repository 只存 locator/storage kind。
- 60 秒 Web MVP 上限由首块 PCM sample index 与有效 sample rate计算；边界 chunk 按 frame 裁剪，之后不再累积 PCM。测试覆盖非零起始 sample、跨界、discontinuity、sample-rate change 和暂停 wall-clock 远大于录音时长但 sample index 连续的情况。Edge runtime 用 1 秒同构 gate 验证 finalize/reload，避免生成不必要的 5.76 MB 合成 PCM。
- 本机普通 Web release 会尝试从 gstatic 获取 CanvasKit；网络阻断时页面白屏与 persistence 无关。本卡 browser gate 使用 `--no-web-resources-cdn` 自包含构建隔离该变量，不改变正式部署策略；P4-11 必须固化自包含资源、MIME、CSP、cache/version 合同。

### P4-05 Android lifecycle/fault automation（2026-08-27，已完成，待集成接受）

- Android lifecycle 由 app composition 的唯一 Flutter binding adapter 转为 `foreground/background/detached` application state；页面不处理系统事件。运行会话后台自动 pause，只有该自动 pause 会在 foreground resume；手动 pause 与 detached 不会被误恢复。coordinator 既有 resume discontinuity 合同保证 sample timeline 不跨中断伪连续。
- API 35/x86_64 竖屏 MuMu `127.0.0.1:16384` 的 SDK ADB gate 实测通过 permission grant/revoke、HOME/foreground、force-stop/relaunch、gate-only read-only directory 的 typed `recordingUnavailable` 与 `.partial` recovery。证据固定 `emulator=true`、`real_device=false`、`root_used=false`。脚本读取并恢复原 permission/app-op、目录 mode、普通 app entry 与原运行状态，且删除 gate-only 目录。
- incoming call、Bluetooth 与真实有线/硬件 route 无法由 emulator 真实产生，继续 Pending。read-only mode injection 是 synthetic storage failure，不是磁盘 quota、厂商清理策略或真机文件系统通过。
### SRD-04 production 依赖采用记录（2026-08-27）

- `symphonia 0.5.5`（MPL-2.0）加入 production Rust，用于在本地离线解码 WAV/AIFF/CAF/MP4/MKV/WebM/OGG 及 PCM/FLAC/MP1-3/AAC-LC/ALAC/Vorbis。Windows、Android 与 Web/WASM 均使用同一 pure-Rust decoder；不调用系统 codec、不上传音频。fallback 为 typed `unsupported_format|decode_failed`，不会静默调用 ffmpeg；移除时只替换 `song::decode` adapter，STFT/model/Flutter contract 不变。发布物须保留 MPL notice/source 获取方式。官方支持表与许可：<https://docs.rs/symphonia/0.5.5/symphonia/>、<https://github.com/pdeljanov/Symphonia/blob/main/LICENSE>。
- `tract-onnx 0.23.5`（MIT OR Apache-2.0）从 R&D tool 提升为 **native-only** production model runtime；Windows/Android 编译，Web 明确不编译/不声称可用。它只加载 SHA-256 `1dd15a2be2f15ba035205f866a035df38d85b27824ad67fe53566e80ec1f4258` 的 reviewed dynamic UMX-HQ core；模型仍不进 Git。fallback 为 typed `model_not_found|model_hash_mismatch|runtime_unavailable|backend_incompatible`。移除成本限制在 `song::tract_backend` 与 native composition；波形合同和 unavailable fallback 保留。Android 包体/RSS 与许可证 NOTICE 仍需本卡实测，失败则不在该平台提升 capability。
- 两项依赖均固定在 `rust/Cargo.toml`/`Cargo.lock`；没有 Python/PyTorch/ffmpeg product sidecar。引入 tract 后其 build script 要求 `cc` 的 `cargo_warnings` API，因此 lock 将 `cc` 从 `1.0.83` 提升并固定解析到 `1.4.4`；这是构建依赖兼容修复，不改变产品逻辑。

### P4-11 Web lifecycle + self-contained deployment（2026-08-27，已完成，待集成接受）

- Web lifecycle 通过页面加载前的轻量 JS observer 进入 P4-05 已建立的 platform-neutral lifecycle contract：Permissions API microphone state、mediaDevices `devicechange`、visibility 和由 `record_web` 后续创建的 AudioContext state 都映射为封闭 enum。Android 继续使用 Flutter phase 自动 pause/resume；Web 的细粒度 stream 由同一 `LivePracticeController` 串行化且只开放显式恢复，避免两套 observer 重复恢复。observer 不记录设备标识或路径；浏览器不支持 Permissions API microphone query 时，权限事实继续由 capture adapter 的实际请求负责，不猜测状态。
- hidden/AudioContext interruption 会暂停 active capture 并以 monotonic sample index 保存 typed checkpoint；visible/running 只令 recovery ready，必须用户显式 resume。permission revoked 进入 `PermissionDeniedFailure`；worker client 和 supervisor 的 interrupted/recovered/restart/fallback 事件建立 checkpoint，并把下一 batch 标 discontinuity，避免跨断点解释稳定性。
- 部署合同选择最保守的版本一致性策略：HTML/JSON/JS/WASM 均 `Cache-Control: no-store, max-age=0`，每次 release 对关键资产生成 SHA-256 manifest，server 在全部响应附相同 release id。该策略牺牲关键 runtime 长缓存，以直接避免无内容哈希文件名下的旧 JS/new WASM 拆配；图片等非关键资源仍可短期缓存。Flutter 生成的 service worker 只执行 unregister/reload，也纳入 release hash。
- 正式命令固定为 `flutter build web --release --no-web-resources-cdn --csp`。自包含 CanvasKit 避免 gstatic 阻断白屏；WASM MIME 为 `application/wasm`。CSP 为 self-only runtime/worker，加 `wasm-unsafe-eval`、worker `blob:` 和 Flutter inline style 所需的最小例外。默认 Rust WASM 仍在 dedicated worker 内单线程运行，不要求 SharedArrayBuffer，等价 server 故意不发送 COOP/COEP。
- 本地 validator 实测 27 个关键资产、8 个 WASM 的 hash/release header/cache/MIME/CSP；Edge 报告 `crossOriginIsolated=false`，synthetic lifecycle 覆盖 permission granted、hidden/visible、devicechange、AudioContext suspended/closed、worker interrupted/recovered/replacement。`realMicrophone=false`；真实后台限频、设备拔插、permission revoke、Edge/Chrome/Firefox 与 Safari/iOS 仍属于 P4-15。

### Android file selector build reproducibility（2026-08-27）

- 新增 `file_selector_android 0.5.2+9` 后，fresh/offline Gradle 曾在插件内嵌 AGP `8.13.1` 的 `com.android.databinding:baseLibrary` 未缓存时失败，online 则受本机 Google Maven TLS 影响。本卡实际 Flutter build 的首次直连又先在 sqlite3 官方 GitHub native asset 超时；使用显式、进程级可信 HTTP CONNECT proxy 后下载成功，sqlite3 hook 按发布包固定 SHA-256 验证，构建完成。没有关闭 TLS、替换仓库或留下全局 init script。
- 后续独立构建修复固定官方 `file_selector_android 0.5.2+9`（pub archive SHA-256 `1d45e9910f68c16eb0c74f0b10097ad81aed516ea28054c027137e8f7d75e840`）到 `third_party/`，保留 BSD-3-Clause LICENSE/AUTHORS/README/changelog 与原生产代码。唯一 local patch 删除插件自带的 AGP/Kotlin buildscript 与重复 repositories，令 `com.android.library` 统一使用仓库 `android/settings.gradle.kts` 已固定的 AGP `9.0.1`。这消除第二套 AGP `8.13.1`/`baseLibrary` 解析，不降级到受 GHSA-r465-vhm9-7r5h 影响的 `<=0.5.1+11`；更新/移除流程记录在 vendoring record。
- vendor audit tests 与 song import/controller/widget regressions 通过；`:file_selector_android:assembleRelease --offline --rerun-tasks` 真实从 vendored Java/Kotlin/Pigeon source 生成 AAR，未请求 AGP `8.13.1`。canonical `flutter build apk --release` 成功，APK `61,350,870` bytes，SHA-256 `369d3bd6900bafb8bbca173fe0cfbf740f4cff93b3a3fff65db08d2efd4a3ab2`。这证明当前依赖组合可构建，不替代 SAF 实际用户选择/取消的 Android emulator UI 回归。
