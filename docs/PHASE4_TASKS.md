# Phase 4 固定任务卡

更新时间：2026-08-07  
状态：**远程预备路径已获仓库所有者授权。当前先执行 P3-07P，再执行 P3-07A→C；这些卡接受后，若仓库所有者仍不在电脑旁，可从 P4-00 开始逐卡执行到 P4-13。P4-14/P4-15 和最终 Closure 需要真实设备或人工操作，保持锁定。**

## 1. 为什么允许提前进入远程路径

P3-07D 依赖仓库所有者在 Windows 电脑旁执行权限、物理设备、真实磁盘故障和正式产品链路操作。该外部条件不应让可自动化的 Android/Web/UI 工作长期停摆。仓库所有者明确授权在 P3-07D 等待期间推进后续工作，但这是一条**实现路径**，不是验收捷径：

- P3-07P 必须先核验并封存当前 P3 工作树；随后 P3-07A→C 完成，使 Android/Web 能复用同一证据合同、性能观测和故障 runbook。
- P4-00→P4-13 可以在 P3-07D 未完成时逐卡实施，每卡独立测试和记录。
- P3-07D→E、P3-08 仍决定 Windows Phase 3 是否关闭；模拟器、ADB root、fake 或构建不能替代。
- P4-14 Android 真机 Gate、P4-15 真实浏览器/麦克风 Gate 和 P4-16 Closure 均保持锁定。
- 仓库所有者回到电脑旁后，只能在一个任务卡已接受、工作树已形成清晰 checkpoint 时切回 P3-07D，禁止把两张卡的未提交改动交叉在同一工作树中。

## 2. 已知 Android 模拟器基线

2026-08-07 只读探测确认：

| 项目 | 当前事实 | 验收含义 |
|---|---|---|
| 产品 | MuMu Player 12，设备模型伪装为 `V2362A` | 只记录为 emulator，不写成 vivo 真机 |
| ADB | Android SDK `adb 37.0.1` 可连接显式实例端点；2026-08-26 复验竖屏实例为 `127.0.0.1:16384` | 可供 Flutter、安装、日志和自动化使用；多实例时禁止依赖默认端点 |
| 系统 | Android 15 / API 35，x86_64 | 必须验证 APK 的 x86_64 Rust library 与 FRB runtime |
| 显示 | 1080×1920，480 dpi，竖屏 | 可做手机 viewport、触摸和文字缩放测试 |
| 音频声明 | microphone、low-latency audio；AudioFlinger 有 48 kHz PCM16 input path | 可做插件/合同 smoke；不能当真实麦克风质量证据 |
| root | `adb root` 后 adbd 为 uid 0；普通镜像内没有 `su` | root 仅用于可恢复的测试注入，不得成为产品前提 |

标准 SDK ADB 当前不在 shell PATH；任务必须使用解析后的 SDK 路径或新增只读 helper，不得依赖 MuMu 私有 ADB 的隐式全局状态。

## 3. 全局执行规则

- 一次只执行一张卡。先写失败测试/探测，再做最小实现；下一卡必须等当前卡接受并记录。
- Windows 已验收的 production composition 必须持续回归。Android/Web 只在对应卡通过后从 fake 提升。
- emulator/root/fake/headless 证据必须标为 `synthetic` 或 `emulator`，永远不能满足 `real_device_required`。
- 页面只消费 application/domain state；平台差异集中在 `PlatformCapabilities`、composition、capture、persistence 和 lifecycle adapter。
- 不新增 P2/P3 DSP 算法，不调整 Observation 阈值，不实现 Phase 5 的个人基线、导出、三个完整练习模板或高级分析。
- root 命令只能作用于测试包、其沙箱或明确的可丢弃测试目录；每个命令须有读取前置状态、dry-run/目标打印和恢复步骤。不得修改宿主机或宽泛删除模拟器目录。
- 模拟器音频可能由宿主转发、重采样或生成；只验证 API/格式/状态传播，不验证真实延迟、AGC、路由、音色或掉帧门槛。

所有实现卡至少运行适用的窄测试及：

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool
flutter analyze
flutter test
cargo fmt --check --manifest-path rust\Cargo.toml
cargo clippy --manifest-path rust\Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path rust\Cargo.toml
```

只记录实际运行结果；平台不适用项明确写 skipped，不写 passed。

## 4. 固定顺序

| 顺序 | 卡片 | 核心结果 | 当前人工依赖 |
|---|---|---|---|
| P4-00 | 远程入口与 ADB 基线 | 固化连接、能力和证据边界 | 无；P3-07P、P3-07A→C 接受后解锁 |
| P4-01 | PlatformCapabilities 与组合边界 | 平台能力集中、页面无平台分支 | 无 |
| P4-02 | Android build 与 Rust bridge smoke | APK/ABI/FRB 在模拟器真实运行 | 无 |
| P4-03 | Android capture/DSP production composition | record → queue → Rust 在模拟器闭环 | 无 |
| P4-04 | Android 原生持久化与恢复 | Drift/WAV/删除/恢复使用 Android 文件路径 | 无 |
| P4-05 | Android 生命周期与故障自动化 | ADB 权限、后台、强停、存储故障有 typed 结果 | 无 |
| P4-06 | 自适应 UI 基础 | 手机/桌面/Web 的导航、布局和状态容器统一 | 无 |
| P4-07 | 五页产品流程完善 | Home/Live/Result/History/Settings 基于现有合同完整可用 | 无 |
| P4-08 | Android 模拟器闭环 Gate | release APK 的 emulator evidence bundle | 无；不替代真机 |
| P4-09 | Web capture + Rust worker composition | Web 从 fake 提升到真实 capture/worker | 无 |
| P4-10 | Web 持久化与 60 秒上限 | Drift/OPFS/IndexedDB/恢复闭环 | 无 |
| P4-11 | Web 生命周期与部署合同 | 权限、后台、worker、MIME/CSP/cache 可验证 | 无 |
| P4-12 | 跨平台 UI/错误/无障碍回归 | 三类 viewport 与全部关键状态自动化 | 无 |
| P4-13 | 远程实现基线封存 | Windows + emulator + Web 自动化全绿 | 无 |
| P4-14 | Android 真机 Gate | 真机音频、路由、来电、性能、soak | **缺少 Android 真机，阻塞** |
| P4-15 | 真实浏览器/麦克风 Gate | Edge/Chrome/Firefox，Safari 单列 | **需要电脑旁/Apple runner** |
| P4-16 | Phase 4 Closure | 三平台证据与只读审计 | P3-08、P4-14、P4-15 均完成 |

## 5. 逐卡定义

### P4-00 — 远程入口与 ADB 基线

**前置：** P3-07P、P3-07A→C 已接受；P3-07D 因仓库所有者不在电脑旁保持 Pending。

**目标结果：** 固化可复现的 SDK ADB 连接、emulator identity/capability report、Flutter device detection 和隐私/真实性边界，不改产品代码。

#### P4-00 执行记录（2026-08-07，已接受）

- 新增 `tool/p4_00_android_preflight.dart` 与对应单元测试。helper 只从 Android SDK Platform-Tools 解析 `adb.exe`（或接受显式 SDK 路径），从不调用 MuMu 私有 ADB，也不依赖 shell PATH；它显式连接 `127.0.0.1:7555` 后读取 API、ABI、物理分辨率/density、microphone/low-latency feature、当前 shell root 状态和 Flutter machine device id。
- 实测报告：API 35、`x86_64`、1080×1920、480 dpi、microphone/low-latency 均为 `true`，Flutter device id 为 `127.0.0.1:7555`，当前 SDK ADB shell 观察到 `rootShellObserved=false`。完整脱敏字段已记录在 Android matrix；没有读取或保存 model/product/serial。
- 报告固定写入 `evidenceType=emulator`、`emulator=true` 和 `realDevice=false`，并明确声明不能满足真实设备或真实麦克风要求。该 helper 只执行连接和只读查询；不会调用 `adb root`、修改模拟器全局配置或产品/平台工程。
- 实际命令：`flutter test test/tool/p4_00_android_preflight_test.dart`（6 项）与 `dart run tool/p4_00_android_preflight.dart --endpoint 127.0.0.1:7555` 均通过。完整 repository gate 结果见本卡最终复验。
- 2026-08-26 多实例复验：仓库所有者确认原竖屏 MuMu 实例，SDK ADB 将其映射为 `127.0.0.1:16384`；只读 preflight 再次得到 API 35、`x86_64`、1080×1920、480 dpi 和相同 emulator-only 边界。后续命令必须显式传入该实例端点，不能误用其他已连接模拟器。

**允许修改：** `tool/` 下 Android preflight helper、对应 tests、Android matrix、`RESEARCH_NOTES.md`、本文件和状态文档。

**禁止修改：** `lib/`、`rust/`、Android 平台工程、依赖、模拟器全局配置。

**验收：** helper 能发现 SDK `adb.exe`、连接显式 endpoint、输出 API/ABI/分辨率/density/audio features/root 状态和 Flutter device id；连接失败给出可操作错误。报告脱敏且固定标记 `emulator=true`、`realDevice=false`。接受后只解锁 P4-01。

### P4-01 — PlatformCapabilities 与组合边界

**目标结果：** 建立不可变、可测试的 `PlatformCapabilities`，统一表达 capture、persistence、worker、最大录音时长、设备选择和生命周期能力；平台检测只存在于外层 composition。

#### P4-01 执行记录（2026-08-07，已接受）

- 新增平台无关、不可变的 `core/platform/PlatformCapabilities`：profile 明确涵盖 capture、persistence、analysis worker、最大录音时长、设备选择和 lifecycle。它不导入 Flutter、`dart:io`、JS interop、record、Drift 或 FRB。
- `app/platform_capabilities_*` 是唯一的运行时平台检测边界：Windows 继续 `RecordAudioCapture` + `RustAnalysisEngine` + native persistence；Android、Web 与其他 native 都是显式 fallback。Web 的公开 60 秒录制上限已集中在 profile，尚不表示 Web capture/persistence 已提升。
- providers 和 default adapter/persistence composition 只读取该 profile；已删除原 adapter/persistence composition 中散落的 `Platform.isWindows`。features/presentation/domain 未发现 `dart:io`、JS interop、record、Drift、FRB 或 platform-detection import。
- 新增 profile 与 composition tests：Windows production/native persistence 与 Android/Web/other-native fallback 均被覆盖。完整 repository gate 结果见本卡最终复验。

**允许修改：** `lib/core/platform/`、`lib/app/` composition/providers、对应 tests。

**禁止修改：** 具体 capture/DSP/persistence 实现、页面功能、Rust、schema。

**验收：** Windows 继续 production；Android/Web 此卡仍为明确 fallback。tests 覆盖 Windows、Android、Web、其他 native；`features/` 和 presentation 不导入 `dart:io`、JS interop、record、Drift、FRB或散落平台判断。接受后解锁 P4-02。

### P4-02 — Android build 与 Rust bridge smoke

**目标结果：** 在 API 35/x86_64 模拟器安装并运行 debug/release 候选，直接调用 Rust bridge 验证 ABI、native library、批次 DTO 和进程重启。

#### P4-02 执行记录（2026-08-07；2026-08-26 复验并封存）

- `integration_test/p4_02_android_rust_bridge_smoke_test.dart` 通过共享的 `tool/p4_02_bridge_probe.dart` 在 native FRB runtime 实际初始化 Rust、调用 greeting，并向 `FrbAnalysisWorker` 推送一秒 48 kHz PCM16 deterministic 220 Hz synthetic signal（每 batch 1024 samples）。Windows 与 Android emulator 都得到 94 frame、sample checksum `2,098,080`、pitch checksum `20,681.109375`；RMS checksum保持在跨平台 `0.001` 容差内。复验同时补齐最小 widget tree，避免 Windows integration binding 在 teardown 阶段错误使用已释放的 `FocusManager`。
- Android emulator integration 成功安装并调用 x86_64 Rust bridge；受限 DTO 始终是 8 band powers、无 spectrum payload，且 `voiced == (f0Hz != null)`。这些是 synthetic bridge evidence，不是 microphone/capture evidence。
- 实际完成 `flutter build apk --debug` 与以 `tool/p4_02_android_release_main.dart` 为目标的 release APK 构建。release APK 包含 `lib/x86_64/librust_lib_voice_trainer.so`；该 release 入口会真实执行同一个 production analyzer probe，只有 greeting、94 frames、sample checksum `2,098,080`、RMS/pitch 容差和受限 DTO 全部满足才显示 `P4_02_RELEASE_BRIDGE_OK`。`tool/p4_02_android_release_smoke.ps1` 要求显式 endpoint，在 `127.0.0.1:16384` 安装 release、两次 force-stop/relaunch、两次读取可见 sentinel，并仅检查本次 app PID/包名相关 crash。报告固定 `evidenceType=emulator`、`emulator=true`、`realDevice=false`。
- 本卡没有改变 Android default capture/persistence composition、DSP 算法、Observation 规则或 UI；Android 仍是 P4-01 定义的 fallback，P4-03 才能提升 capture/DSP production composition。
- 仓库所有者于 2026-08-26 明确授权不再以逐卡人工等待阻塞可并行工作；P4-02 以本次完整复验结果作为后续分支基线。该授权不改变 emulator/synthetic 的证据等级，也不解锁真机或真实麦克风 gate。

**允许修改：** Android 构建/manifest 的最小必要配置、Android integration/tool smoke、现有生成流程产生的文件、矩阵。

**禁止修改：** 默认 Android capture/persistence composition、DSP算法、UI功能、新依赖。

**必须交付：** `flutter build apk --debug`、至少一次 release 构建；标准 ADB 安装/启动；设备内 Rust greeting/生产 analyzer deterministic signal 输出与 Windows baseline 对比；检查 APK 含 x86_64 Rust library。保留 fake 默认。

**验收：** smoke 在显式选择的目标 emulator 上真实返回受限 DTO，app 无 native crash/UnsatisfiedLinkError；生成物可重复，Windows/Web 回归全绿。接受后解锁 P4-03。

### P4-03 — Android capture/DSP production composition

**目标结果：** Android 默认使用 `RecordAudioCapture` + `RustAnalysisEngine`，按 `effectiveFormat` 初始化并走 P3 的有界队列、断点和 25 Hz UI 合同；fake provider 继续可覆盖。

#### P4-03 执行记录（2026-08-26，已完成，待集成接受）

- `PlatformCapabilities.android` 仅将 capture 提升为 production、analysis worker 提升为 native worker；persistence 与 lifecycle 仍是 fallback。既有 native composition 因此在 Android 复用 `RecordAudioCapture`、`RustAnalysisEngine`、P3 coordinator 有界队列/断点和 25 Hz decimator，没有复制平台实现或改变 Web。
- 首次真实 composition smoke 暴露默认 native analyzer 未自行初始化 FRB：record 插件成功运行后，worker 会以 `flutter_rust_bridge has not been initialized` 进入 terminal failure。修复收敛在 `FrbAnalysisWorker` adapter，以共享 Future 幂等执行 `RustLib.init()`，失败时允许下一次初始化重试；未修改 Rust 算法、DTO 或 worker 恢复状态机。
- 新增 `p4_03_android_contract_test.dart`，在 Windows 与 API 35/x86_64 emulator 覆盖 Android production 类型、persistence fallback、fake override、permission allow/deny、start/pause/resume/stop、unsupported/changed format、worker processing failure 和 oldest-drop queue accounting。全部失败继续映射为既有 typed domain result。
- `p4_03_android_capture_smoke_test.dart` 在显式 endpoint `127.0.0.1:16384` 运行真实 record 插件。permission granted 运行请求/有效格式均为 PCM16 mono 48 kHz，采集 188 chunks / 48,128 samples，pause/resume/stop 成功，Rust production analyzer 返回 94 frames；permission 预先固定 denied 时返回 `PermissionDenied`、capture 未启动、0 frame。报告固定 `evidenceType=emulator`、`emulator=true`、`realDevice=false`，不记录 PCM、设备标识或路径，也不把 emulator 输入解释为真实人声/voiced 证据。
- Android persistence 仍为 in-memory fallback，P4-04 之前不得宣称 durable save/recovery 已支持。

**允许修改：** Android conditional composition、capture mapper、Android integration、矩阵。

**禁止修改：** persistence 默认、Web composition、Rust算法、Observation规则、页面扩张。

**验收：** 模拟器上权限 allow/deny、start/pause/resume/stop、unsupported/changed format、worker failure 与 queue drop 均有 typed 结果；能得到真实插件 PCM/或明确 zero-input 状态，绝不伪造 voiced 数据。报告记录请求/有效格式并标为 emulator；Windows production/fake tests持续通过。接受后解锁 P4-04。

### P4-04 — Android 原生持久化与恢复

**目标结果：** 将 Windows 已验收的 native Drift + streaming WAV + recovery 组合安全推广到 Android application-support 路径。

#### P4-04 执行记录（2026-08-26，已完成，待集成接受）

- Android capability 的 persistence 已从 fallback 提升为 production；native composition 仅在 Windows/Android production profile 下启用，并由重命名后的共享 lazy host 复用同一个 `DriftSessionRepository`、`NativeRecordingSink`、`NativeRecordingStore` 和 `RecordingRecoveryService`。没有复制实现、修改 schema version/BLOB 编码或触碰 Web/UI/Rust。
- file-backed v1 fixture 暴露既有迁移问题：v1→v2 使用当前 metadata 表定义时已经包含 v3 列，原 v3 步骤会再次添加同名列。迁移现仅在列实际缺失时补 `feature_schema_version`；目标 schema、版本和 packed BLOB 语义不变。
- `p4_04_android_native_persistence_test.dart` 在 Windows 和 API 35/x86_64 emulator `127.0.0.1:16384` 均为 4/4：覆盖 application-support 下 WAV append/finalize、save/read/history/delete、adapter close/reopen、file-backed transaction rollback、失败删除 tombstone、orphan partial/startup recovery 和 v1 fixture 升级后写读。
- release probe 清空的仅是测试包 `com.local.voice_trainer` sandbox；首次启动显示 created sentinel，SDK ADB force-stop 后再次启动显示 restored sentinel。报告固定 `evidenceType=emulator`、`emulator=true`、`realDevice=false`，并检查 Flutter application-authored log 无数据库/录音绝对路径及 app crash signature。该证据不能替代 Android 真机、真实麦克风或 P4-14。

**允许修改：** native persistence composition 的通用化、Android integration、测试和矩阵。

**禁止修改：** schema/BLOB 语义、Web persistence、UI、新训练功能。

**验收：** Android 默认不再使用 in-memory persistence；Windows/Android 复用同一 repository/sink而非复制。模拟器验证 save/read/history/delete、append/finalize/DB failure、tombstone、force-stop/relaunch、旧 schema fixture；日志无绝对路径。接受后解锁 P4-05。

### P4-05 — Android 生命周期与故障自动化

**目标结果：** 使用普通 ADB 优先、root 仅作隔离故障注入，覆盖权限、后台/前台、进程终止、存储失败和应用恢复；系统事件进入 application state，不由页面直接处理。

**允许修改：** lifecycle adapter、typed failure mapping、gate-only config/tool、integration tests和矩阵。

**禁止修改：** root 成为产品依赖、自动改宿主/全局网络、宽泛删除、DSP/规则。

**必须交付：** `pm grant/revoke` 或 appops、`am force-stop`/重新启动、后台/恢复、测试沙箱内只读/空间失败、DB/partial recovery；每个脚本读取并恢复原状态。模拟器无法真实产生的来电、蓝牙和硬件路由固定 Pending。

**验收：** 所有场景输出 P3 evidence schema 并标 `emulator`；root-only 结果不能满足普通设备门槛。资源/subscription 无泄漏，sample timeline 不跨中断连续。接受后解锁 P4-06。

### P4-06 — 自适应 UI 基础

**目标结果：** 在不新增业务能力的情况下，建立手机竖屏、桌面宽屏和窄 Web 的统一布局/导航/设计 token，使后续页面不为每个平台重写。

**允许修改：** `lib/app/theme/`、shell、共享 presentation widgets、widget/golden tests。

**禁止修改：** capture/DSP/persistence、业务规则、数据库、新 chart 依赖、Phase 5功能。

**验收：** 360×640、393×852、1080×1920@3x、桌面和窄 Web viewport 无 overflow；手机使用合适 bottom navigation/back，宽屏使用 rail；文字缩放 200%、深色/高对比、横竖屏基本状态可用。测试不依赖真实麦克风。接受后解锁 P4-07。

### P4-07 — 五页产品流程完善

**目标结果：** 基于现有 P3 domain/application 合同完成 Home、Live、Result、History、Settings 的 MVP 交互和全状态覆盖，不提前实现 Phase 5 新业务。

**允许修改：** 五个 feature 的 application/presentation、共享 widgets、fake fixtures、widget/integration tests。

**禁止修改：** DSP、schema、新练习算法、个人基线、导出、云端、多语言全面铺开、高级声学指标。

**必须满足：** Home 有快速开始/最近结果/历史入口；Live 有目标、note/cents、RMS、quality、pitch ring、权限/无输入/暂停/失败/finalizing；Result 有有效性、命中率、证据、质量抑制、建议；History 有列表/空态/删除确认与录音状态；Settings 展示当前能力/麦克风/隐私存储事实，不显示尚未实现的开关。语义、键盘/触摸 target、loading/empty/error 均测试。

**验收：** Windows widget、Android 竖屏 emulator 和 Web viewport 的 fake/production-available flow 无 overflow/崩溃；页面无 record/Drift/FRB/平台判断。接受后解锁 P4-08。

### P4-08 — Android 模拟器闭环 Gate

**目标结果：** 在 release APK 上完成 Android emulator 的 production composition 闭环并形成可校验证据包。

**必须运行：** 安装/冷启动；权限拒绝再授权；开始/暂停/恢复/结束；结果/历史/删除；后台/强停/重启恢复；10 分钟稳定运行；UI frame/memory/queue metrics。若 emulator 麦克风无可靠输入，使用明确的 test source 做 DSP流并把 real-mic 项保持 Pending。

**验收：** 自动化全绿、报告 validator 通过、所有项目正确标注 emulator/synthetic；不得写“Android 已支持”或解锁 P4-14。接受后解锁 P4-09。

### P4-09 — Web capture + Rust worker production composition

**目标结果：** Web 默认从 fake 提升为 `record_web` capture + 显式 dedicated Rust WASM worker，主 UI isolate 不执行 DSP。

#### P4-09 执行记录（2026-08-26，已完成，待集成接受）

- `PlatformCapabilities.web` 仅将 capture 提升为 production，analysis 提升为 dedicated Web Worker；persistence 继续是 in-memory fallback，60 秒上限不变。Web 默认组合复用 `RecordAudioCapture` + `RustAnalysisEngine`，fake capability/provider override 继续可用。
- `record_web` 首先请求 512-sample stream buffer；启动拒绝该配置时仅重试一次 1024-sample fallback。权限拒绝等已有 typed capture failure 不会被误重试。analysis 始终以 `CaptureSession.effectiveFormat` 初始化，Rust 仍明确拒绝当前不支持的有效格式，未添加隐式重采样或修改 DSP 算法。
- worker/client 继续使用 dedicated Worker 持有 Rust WASM analyzer，PCM 通过 transferable `ArrayBuffer` 传递。回复 envelope、frame/summary shape 和 quality bit 现在严格验证；unknown operation/DTO、worker crash、pending rejection、replacement worker 与 1024-sample 上限都有自动化。现有 supervisor 测试持续覆盖 restart-once、显式单线程 FRB/WASM fallback 与 oldest-drop backpressure，不要求 `SharedArrayBuffer`/COOP/COEP。
- Edge headless 本地 release 证据全部标为 synthetic browser：权限 deny 返回 typed `permissionDenied` 且 capture 未启动；48 kHz mono synthetic PCM 直接 worker 得到 94 frames、start-sample checksum `2,098,080`，crash pending 被拒绝且 replacement worker 成功，`crossOriginIsolated=false`。Edge fake audio device 的真实 `record_web` 插件路径采集 94 chunks / 48,128 samples，实际有效格式为 44.1 kHz stereo，因此如实返回 typed `unsupportedFormat`；未将其伪造为 voiced 或完整 end-to-end 成功。
- artifact validator 同时校验 FRB WASM header/大小、worker/client/index 引用、transfer/crash/unknown-op 合同、Web production composition 与无 `SharedArrayBuffer` 硬依赖。真实浏览器麦克风、后台限频、devicechange 和多浏览器矩阵仍是 P4-15 人工 gate，本卡不宣称通过。

**允许修改：** Web conditional composition、capture/DSP adapters、worker/client、FRB Web生成物、tests。

**禁止修改：** Flutter `--wasm` 成为唯一构建、SharedArrayBuffer硬要求、Rust算法、Web persistence、UI新功能。

**验收：** effective AudioContext format、512默认/1024 fallback、permission/worker crash/restart/fallback/backpressure/unknown DTO 自动化通过；Web release和artifact validator通过。真实浏览器麦克风留给 P4-15。接受后解锁 P4-10。

### P4-10 — Web 持久化与 60 秒上限

**目标结果：** Web 默认使用 Drift Wasm 与 OPFS/IndexedDB recording store；60秒上限按 sample index执行，结果/历史/删除/恢复不依赖内存 fallback。

**验收：** storage kind可报告；录音不进SQLite；quota/append/finalize/DB/delete/tombstone/reload测试不留坏引用；private mode/不可持久化返回typed failure；60秒安全finalize且暂停时间不误算。接受后解锁 P4-11。

### P4-11 — Web 生命周期与部署合同

**目标结果：** 固化 permission/devicechange、hidden/background、AudioContext、worker生命周期和 WASM MIME/CSP/cache/version合同。

**验收：** 背景恢复显式断点；缓存不混用旧JS/new WASM；本地等价server通过header/cache validator；默认单线程路径不被错误要求COOP/COEP。Edge automation smoke和Web release通过。接受后解锁 P4-12。

### P4-12 — 跨平台 UI/错误/无障碍回归

**目标结果：** 用统一 fixture 矩阵复验 Windows、Android emulator、Web 的五页和所有关键状态，修复平台适配造成的 UI 回归，不增加功能。

**必须覆盖：** permission denied、no device/input、unsupported format、worker restart/failure、recording/persistence failure、low quality、no voiced frames、completed/history/delete；触摸/鼠标/键盘、back、200%文字、深色、窄屏。

**验收：** widget/integration矩阵全绿，无页面平台分支、overflow、逐帧语义播报或100Hz重建。接受后解锁 P4-13。

### P4-13 — 远程实现基线封存

**目标结果：** 在不声称真实设备通过的情况下，封存 Windows回归、Android emulator和Web自动化实现基线，为人工Gate提供稳定commit。

**必须验收：** 标准Dart/Rust gates、FRB生成/worker artifact、Windows release、Android release APK、Web release、Android emulator bundle和hosted CI全绿；架构/隐私只读审计无未解决blocker/high。更新状态时必须同时列出P3-07D、Android真机、真实浏览器麦克风仍Pending。

**解锁：** 只解锁等待人工的P4-14/P4-15；不能完成Phase4 Closure。

### P4-14 — Android 真机 Gate（阻塞）

**前置：** P4-13完成且至少一台中端Android真机可用。

**人工必测：** 真实麦克风/有效格式/处理器实际值；权限拒绝与运行中撤回；后台/来电；有线/蓝牙路由；强停恢复；至少10分钟soak；延迟、丢样、UI frame、内存。使用蓝图原生门槛。emulator/root/fake不能替代。

### P4-15 — 真实浏览器/麦克风 Gate（阻塞）

**人工必测：** Edge、Chrome、Firefox 的真实麦克风、permission、effective rate、512/1024 cadence、后台、devicechange、worker、60秒、storage/reload和Web性能门槛；Safari/iOS Web需要Apple runner，缺少时明确为未支持。

### P4-16 — Phase 4 Closure

**前置：** P3-08、P4-14、P4-15均完成并接受。

**验收：** Windows/Android/Web同一长音闭环、构建/CI、证据bundle和只读架构/隐私/性能审计全部通过；未支持平台明确。closure审计不顺手修实现，问题另立小卡。仓库所有者接受后才规划Phase5。

## 6. Terra 通用交接模板

```text
先完整阅读 AGENTS.md、docs/PROJECT_BLUEPRINT.md、docs/IMPLEMENTATION_PLAYBOOK.md、
docs/FILE_MANIFEST.md、docs/RESEARCH_NOTES.md、docs/PHASE3_TASKS.md 和
docs/PHASE4_TASKS.md。

当前只执行：<唯一卡号>。
先确认上一卡已接受、工作树没有与本卡交叉的未归档改动，再写失败测试/探测。
严格遵守允许/禁止范围。emulator、root、fake、headless结果必须保留证据类型，
不得写成真实设备或真实麦克风通过。
最终只报告：变更文件、实际命令/结果、证据路径、未覆盖项、是否可解锁下一卡。
```
