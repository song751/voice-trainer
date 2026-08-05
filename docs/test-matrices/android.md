# Android 测试矩阵

状态：Phase 1 建立于 2026-08-04。Android CI 构建 debug APK；emulator/fake capture 与真实设备采集分别记录。

| 范围 | 自动化 / 手动 | 当前状态 | 验收记录 |
|---|---|---|---|
| Android 兼容性补丁 | CI：`Android build` 的 patch audit | 本地通过；hosted CI 已首次触发，链接见 C1 执行记录 | 要求 Kotlin incremental cache workaround、Cargokit `ExecOperations` 修复和 FRB library `compileSdkVersion 36` 同时存在。 |
| Debug APK | CI：`flutter build apk --debug` | 本地通过；hosted CI 已首次触发，链接见 C1 执行记录 | 上传 APK；CI 不声称录音功能通过。 |
| Emulator fake capture flow | CI/本地自动化 | Pending | 只验证应用流程与错误恢复；不计入真实麦克风覆盖。 |
| 至少一台中端 Android 真机 | 手动，真实麦克风 | Pending | 记录权限、有效格式、长音/暂停恢复、dropped/discontinuity、后台和来电恢复。 |
| 蓝牙与有线耳机路由 | 手动，真实设备 | Pending | 记录 AudioRecord route 改变和处理器实际设置。 |
| 权限撤回、无设备/被系统占用、应用崩溃后临时文件恢复 | 手动，真实设备 | Pending | 不用 emulator 或 fake capture 标记通过。 |

Android 依赖下载保留 TLS/代理环境风险；构建失败应附日志与失败阶段，不能通过关闭 TLS 校验、替换镜像或预置未校验 AAR 绕过。
