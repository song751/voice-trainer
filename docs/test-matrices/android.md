# Android 测试矩阵

状态：Phase 1 建立于 2026-08-04。Android CI 构建 debug APK；emulator/fake capture 与真实设备采集分别记录。

| 范围 | 自动化 / 手动 | 当前状态 | 验收记录 |
|---|---|---|---|
| Android 兼容性补丁 | CI：`Android build` 的 patch audit | 本地通过；hosted CI 已首次触发，链接见 C1 执行记录 | 要求 Kotlin incremental cache workaround、Cargokit `ExecOperations` 修复和 FRB library `compileSdkVersion 36` 同时存在。 |
| Debug APK | CI：`flutter build apk --debug` | 本地通过；hosted CI 已首次触发，链接见 C1 执行记录 | 上传 APK；CI 不声称录音功能通过。 |
| MuMu Android 15 x86_64 emulator preflight | 本地 ADB/Flutter，只读探测 | 已连接，待 P4-00 固化 | 2026-08-07：SDK ADB 37.0.1 连接 `127.0.0.1:7555`；Flutter 识别 API 35/android-x64；1080×1920、480 dpi；声明 microphone/low-latency audio。模型字段为 emulator 伪装，不算 vivo 真机。 |
| Emulator fake capture flow | CI/本地自动化 | Pending（P4-02/P4-08） | 只验证应用流程与错误恢复；不计入真实麦克风覆盖。 |
| Emulator record/Rust/persistence production flow | 本地模拟器 | Pending（P4-03→P4-08） | 可验证插件 API、effective-format 传播、FRB x86_64、WAV/Drift、权限/生命周期和UI；音频可能由宿主转发/重采样，必须标记 emulator。 |
| 至少一台中端 Android 真机 | 手动，真实麦克风 | Pending | 记录权限、有效格式、长音/暂停恢复、dropped/discontinuity、后台和来电恢复。 |
| 蓝牙与有线耳机路由 | 手动，真实设备 | Pending | 记录 AudioRecord route 改变和处理器实际设置。 |
| 权限撤回、无设备/被系统占用、应用崩溃后临时文件恢复 | 手动，真实设备 | Pending | 不用 emulator 或 fake capture 标记通过。 |

Android 依赖下载保留 TLS/代理环境风险；构建失败应附日志与失败阶段，不能通过关闭 TLS 校验、替换镜像或预置未校验 AAR 绕过。

MuMu 的 `adb root` 只用于隔离故障注入；root-only 结果不能满足普通 Android 设备 Gate。P4-14 在取得至少一台真实中端 Android 设备前保持阻塞。
