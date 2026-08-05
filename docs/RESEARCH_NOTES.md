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

### C2 执行记录（2026-08-05，进行中）

- 范围：Analysis worker 有限恢复状态机、每个 worker request 的 timeout、无响应 worker 的直接 terminate、异常路径测试和 Edge dedicated-worker smoke。
- 修改文件：`analysis_worker_supervisor.dart`、FRB/Web worker adapters、`web/analysis_worker_client.js`、worker tests、`tool/c2_edge_worker_smoke.mjs`、分析排除与 manifest。
- 已实现：supervisor 明确执行 `primary → restartOnce → fallback → terminalFailure`，只重启一次；`initialize`、`pushPcm`、`finish`、`reset` 和 factory/初始化均带 timeout。timeout/crash 后先同步 `terminate()`，不等待 worker 回复；`dispose()` 同样直接 terminate。Web client 会拒绝所有 pending promise 并调用 `Worker.terminate()`。
- 执行命令与结果：`dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool` 通过（99 files / 0 changed）；worker 窄测试 10/10 通过；`flutter analyze` 通过；`node --check tool/c2_edge_worker_smoke.mjs` 通过；`flutter test` 30/30 通过；默认 `flutter build web --release` 通过。该次 build 的 Flutter Wasm dry-run 成功，但不等同于 `flutter build web --wasm` 或 Edge dedicated-worker 验收，默认发布策略仍是 Flutter JS + Rust WASM。
- 未覆盖项或外部阻塞：真实 Edge smoke 未能启动。`flutter run -d edge --release --web-port 7390 --web-browser-flag=--remote-debugging-port=9222` 在 web build 后被本机拒绝本地调试 socket；尝试使用独立本地静态服务和专用 Edge CDP 实例时，环境启动策略拒绝该 Edge 调试进程。当前会话也没有可调用的 Windows/Browser control runtime 以替代 CDP。因而未实际运行 `tool/c2_edge_worker_smoke.mjs`，没有将 fake 测试或 web build 冒充为 Edge 通过。
- 验收结论：部分通过；Windows/Edge frame-count、sample checksum、RMS/pitch tolerance 对比和 DataCloneError 的真实运行时结论仍待 Edge 环境可用后执行。
- 下一张允许执行的卡：C2（外部运行时阻塞）；不得进入 C3 或 Phase 2。
