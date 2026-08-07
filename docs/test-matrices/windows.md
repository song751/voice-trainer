# Windows 测试矩阵

状态：Phase 1 建立于 2026-08-04。CI 只验证可构建性和 fake 测试；真实麦克风验证必须在物理 Windows 设备上单独记录。

| 范围 | 自动化 / 手动 | 当前状态 | 验收记录 |
|---|---|---|---|
| Dart/Rust 静态检查 | CI：`Dart and Rust checks` | 本地通过；hosted CI 已首次触发，链接见 C1 执行记录 | 不使用麦克风或模拟设备宣称硬件通过。 |
| Fake capture 集成闭环 | CI：`Windows build`，`flutter test -d windows integration_test/fake_capture_session_flow_test.dart` | 本地通过；hosted CI 已首次触发，链接见 C1 执行记录 | 验证流程恢复，不计入硬件覆盖。 |
| Release 构建 | CI：`Windows build`，`flutter build windows --release` | 本地通过；hosted CI 已首次触发，链接见 C1 执行记录 | 上传 release runner artifact。 |
| 内置 Realtek PCM16 48 kHz 长音与暂停恢复 | 手动，真实设备 | P3-07 部分通过 | 2026-08-06 明确选择 Realtek 麦克风阵列：10 秒为 48 kHz/mono/PCM16、样本误差 0%、interval P95 47.437 ms；出现 1 次间隔代理断点（max 169.969 ms），不可将稳定度视为无断点。另有 default 60 秒（含 5 秒 pause/resume）捕获成功，但默认 device identity 不作为内置设备确证。 |
| USB Audio PCM16 48 kHz 长音 | 手动，真实设备 | P3-07 部分通过 | 2026-08-06 明确选择 USB Audio：60 秒活动采集加 5 秒 pause/resume，48 kHz/mono/PCM16、样本误差 0.2167%、interval P95 47.587 ms、0 odd bytes、0 discontinuity proxy；pause/resume 调用分别 0.629/0.723 ms。物理拔下后，重新插入并由 Windows 正常枚举，显式选择该设备完成 10 秒恢复采集：样本误差 0.2%、interval P95 47.276 ms、0 discontinuity proxy。随后完成一次连续 1,800 秒采集；其 PCM16 WAV data chunk 为 172,800,000 bytes，独立换算时长恰为 1,800 秒。 |
| 权限拒绝/撤回、无设备、设备拔插、采样率变化 | 手动，真实设备 | P3-07 部分通过 | 2026-08-06 物理拔下 USB Audio 后，Windows 端点枚举不再出现该设备；以保存的 USB 选择运行真实 capture inspector 明确失败为 “Requested input device was not found”。重新插入后的恢复采集已通过。枚举为 44.1 kHz 的真实输入在请求 48 kHz 后仍交付 48 kHz 流，说明可能发生重采样，故格式变化仍 Pending；权限撤回亦 Pending。 |
| 有线/蓝牙路由、睡眠恢复、系统独占、崩溃后录音恢复 | 手动，真实设备 | Pending | 不以 fake capture 或 CI 代替。 |

P3-07 尚未完成：权限拒绝/撤回、全部输入端点不可用、可观察的格式变化、真实磁盘失败、crash/restart、端到端 P50/P95、正式 Live UI frame time 和正式录音链路内存趋势仍需同一 Windows 实机矩阵；不能由上述 capture-only 统计替代。capture inspector 的第 26 至 30 分钟 working set 从约 418 MiB 到 435 MiB、private memory 从约 397 MiB 到 412 MiB，但它会缓存 PCM 以在结束时生成 WAV，因此不作为 streaming recorder 性能结论。

剩余工作按 `docs/PHASE3_TASKS.md` 的 P3-07A→E 执行。A–C 为远程证据工具与 runbook，D 为需要仓库所有者在电脑旁操作的真实矩阵，E 为远程汇总。A–C 的 synthetic/fake 报告必须保留标记，不能把本表的 Pending 改为通过。

每个新手动结果须记录设备类别、有效采样率/声道/处理器设置、chunk cadence、持续时间、dropped/discontinuity，以及应用版本和日期；不得提交录音内容。
