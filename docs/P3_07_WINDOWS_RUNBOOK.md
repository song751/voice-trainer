# P3-07D Windows现场运行手册

本手册只在 `P3-07C` 已接受、仓库所有者在 Windows 电脑旁时执行。所有
结果使用 `P3_07_EVIDENCE_V1` 保存；不得提交 PCM、录音、设备 ID、完整路径
或用户名。每个场景先执行 dry-run，例如：

```powershell
dart run tool/p3_07_fault_gate.dart plan windows_permission_initial_denied --dry-run
dart run tool/p3_07_fault_gate.dart plan windows_disk_write_failure --dry-run --recording-root E:\P3-07-disposable-recordings
```

helper 从不自动修改权限、设备、进程或文件。它只打印操作计划，并拒绝盘符根、
workspace、用户目录、相对路径和未解析变量。磁盘场景必须由仓库所有者指定一个
可丢弃目录/可移除介质；在实际操作前人工核对 helper 输出的绝对路径。

| 场景 | 人工动作与期望 typed 状态 | 证据/清理/停止条件 |
|---|---|---|
| 初始权限拒绝 | 在启动 release app 前于 Windows 隐私设置拒绝麦克风；开始练习应为 permission-denied。 | 记录脱敏报告；恢复原权限。若系统不支持应用级拒绝，记录 pending 原因。 |
| 运行中撤权 | 开始 capture 后手动撤回权限；应停止并显示可恢复 capture failure。 | 记录报告；重新允许权限并确认 app 可重新开始。 |
| 无输入端点 | 手动断开/禁用所有输入，再启动；应为 no-device/typed capture failure，不得静默退回默认。 | 先截图/记录端点为空的脱敏事实，随后恢复设备。 |
| USB 拔插/回插 | 显式选择 USB 后运行中拔出、重新枚举并选择回插端点。 | 分别记录拔出失败和回插恢复；不得把 inspector 结果当 product pass。 |
| 可观察格式变化 | 尝试不同端点或驱动格式；记录 requested/effective format。 | 若驱动始终重采样 48 kHz，保留 `pending` 和平台限制，不能写 pass。 |
| 真实写盘失败 | 只对已验证的可丢弃 recording root/介质制造写入中断。 | 应停止录音并显示错误，无坏 locator；恢复介质后检查 partial 可清理。路径异常、影响非测试文件或无法确认目标时立即停止。 |
| crash/restart | 只终止本应用 release/test 进程，随后重启。 | 检查 `.partial`、tombstone、DB 引用与既有历史；任何不确定数据丢失即停止并保留 fail evidence。 |
| product performance | 内置与 USB 各跑正式 product 链路；含短流程及至少一次 30-minute soak。 | P50/P95、queue drop、UI build/raster、内存和 effective format 进入 report。capture-only、debug、synthetic 均不能满足。 |

现场每次操作在开始前确认 release build/commit，并在结束后执行 validator。若报告含
pending、synthetic 或 capture-only，P3-07D 仍不通过。完成所有场景后才由 P3-07E
汇总；没有现场条件时保持 P3-07D 为“等待现场”。
