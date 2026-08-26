# Android 测试矩阵

状态：Phase 1 建立于 2026-08-04。P4-13 将 Android CI 提升为 release APK；emulator/fake capture 与真实设备采集分别记录。

| 范围 | 自动化 / 手动 | 当前状态 | 验收记录 |
|---|---|---|---|
| Android 兼容性补丁 | CI：`Android build` 的 patch audit | 本地通过；hosted CI 已首次触发，链接见 C1 执行记录 | 要求 Kotlin incremental cache workaround、Cargokit `ExecOperations` 修复和 FRB library `compileSdkVersion 36` 同时存在。 |
| Debug/release APK 与 Rust bridge | CI/本地：build + emulator smoke | 通过（P4-02；emulator/synthetic） | 2026-08-26 在显式 endpoint `127.0.0.1:16384` 复验：debug integration 与 release sentinel 均真实调用 Rust greeting 和 deterministic production analyzer；94 frames、sample checksum `2,098,080`、8 bands、无 spectrum payload。release 两次强停重启均成功且没有 app 相关 native crash。仅为 synthetic bridge evidence，不声称录音功能通过。 |
| MuMu Android 15 x86_64 emulator preflight | 本地 ADB/Flutter，只读探测 | 通过（P4-00；emulator） | 2026-08-07：`dart run tool/p4_00_android_preflight.dart --endpoint 127.0.0.1:7555` 通过。SDK Platform-Tools ADB 显式连接 endpoint；Flutter device id=`127.0.0.1:7555`；API 35、`x86_64`、1080×1920、480 dpi、microphone/low-latency=true、`rootShellObserved=false`。报告固定 `emulator=true`、`realDevice=false` 并脱敏 model/product/serial 与绝对 SDK 路径；不算 vivo 或任何真实 Android 真机。 |
| Emulator fake capture flow | CI/本地自动化 | 通过（P4-03；synthetic） | Android composition integration 覆盖 provider override、allow/deny、start/pause/resume/stop、unsupported/changed format、worker failure 与 oldest-drop queue accounting；不计入真实麦克风覆盖。 |
| Emulator record/Rust production flow | 本地模拟器 | 通过（P4-03；emulator） | 2026-08-26，`127.0.0.1:16384`：真实 record plugin permission granted/denied 均复验；allow 得到 PCM16 mono 48 kHz effective format、188 chunks / 48,128 samples 和 94 Rust frames，deny 明确为 not-started / 0 frame。音频可能由宿主转发/重采样，不作为真人声或音质证据。P4-03 当时 persistence 仍为 fallback，随后由 P4-04 独立提升。 |
| Emulator native persistence/recovery | 本地模拟器 + release ADB gate | 通过（P4-04；emulator） | 2026-08-26，显式 endpoint `127.0.0.1:16384`：Android 默认复用 Windows 的 Drift repository、streaming WAV sink 和 startup recovery，并写入 application-support。debug integration 4/4 覆盖 append/finalize、save/read/history/delete、关闭后重开、file-backed DB rollback、tombstone/partial recovery 和 v1→v4 fixture。release gate 清空测试包 sandbox 后首次写入，ADB force-stop/relaunch 后读回；JSON 固定 `emulator=true`、`realDevice=false`，Flutter app log 未输出持久化绝对路径。 |
| Emulator lifecycle/fault automation | 本地模拟器 + SDK ADB gate | 通过（P4-05；emulator/synthetic） | 2026-08-27，仅 `127.0.0.1:16384`：普通 ADB permission allow/deny、HOME/foreground、force-stop/relaunch、gate-only sandbox read-only failure 与 partial recovery 全部返回 typed/sentinel 结果。应用层后台自动暂停、前台恢复、手动暂停保护与 sample discontinuity 由 tests 覆盖；root 未使用，permission/app-op/mode/app entry/gate directory 均在 finally 恢复。来电、蓝牙与真实硬件 route 保持 Pending。 |
| P4-08 release production-composition soak | 本地模拟器 + release ADB/evidence validator | 通过（emulator/synthetic；real mic Pending） | 2026-08-27，仅 `127.0.0.1:16384`：release APK 覆盖 permission deny→grant、start/manual pause/resume、HOME/foreground、stop、result/history/recording delete、force-stop/relaunch/session delete。600 s test source 精确生成 28,800,000 samples，analysis/recording queue drop 均 0，primary worker restart 0；pipeline/UI build/UI raster P95=`68.535/0.666/1.405 ms`，21 个 memory samples 有界。bundle validator 通过，root 未使用，原安装/权限/运行状态和临时文件已恢复。真实麦克风、route、AGC、latency、真人 voiced input 与 Android 真机仍 Pending。 |
| P4-12 portrait UI + SAF cancel | Widget matrix + emulator integration/ADB | 通过（emulator + synthetic adapters） | `127.0.0.1:16384` 上 Android target integration 通过 393×852、深色、200% 文字和 typed permission UI；另由产品歌曲页真实进入 DocumentsUI SAF 并 Back 取消返回。未选择/读取文件，未请求真实麦克风；完成后恢复原 APK 且 SHA-256 一致。 |
| P4-13 release seal | CI + local release build + final emulator bundle | 接受（`b221014`） | 正式APK 127,134,834 bytes，SHA-256 `1b99fc3f…b987f`；merged release manifest禁用backup/transfer。`127.0.0.1:16384` final gate为600秒、28,800,000 samples、两队列drop 0、worker restart 0、21点PSS 84.729–106.975 MiB，validator与hosted Android CI均通过、root未用；仍不满足P4-14真机。 |
| Flutter 3.44.7 release registrant | CI release build + release audit | 通过（`b221014`） | release命令自行刷新pub/plugin配置；audit拒绝`--no-pub`，避免dev-only `integration_test`注册代码残留而原生模块已从release classpath排除。测试插件不进入production dependency。 |
| 至少一台中端 Android 真机 | 手动，真实麦克风 | Pending | 记录权限、有效格式、长音/暂停恢复、dropped/discontinuity、后台和来电恢复。 |
| 蓝牙与有线耳机路由 | 手动，真实设备 | Pending | 记录 AudioRecord route 改变和处理器实际设置。 |
| 运行中权限撤回、无设备/被系统占用、应用崩溃后临时文件恢复 | 手动，真实设备 | Pending | P4-05 只证明 emulator 的预置 permission 与 gate partial recovery；不用 emulator 或 fake capture 标记真实设备通过。 |

Android 依赖下载保留 TLS/代理环境风险；构建失败应附日志与失败阶段，不能通过关闭 TLS 校验、替换镜像或预置未校验 AAR 绕过。

MuMu 的 `adb root` 只用于隔离故障注入；root-only 结果不能满足普通 Android 设备 Gate。P4-14 在取得至少一台真实中端 Android 设备前保持阻塞。
