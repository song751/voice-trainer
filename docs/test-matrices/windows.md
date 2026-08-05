# Windows 测试矩阵

状态：Phase 1 建立于 2026-08-04。CI 只验证可构建性和 fake 测试；真实麦克风验证必须在物理 Windows 设备上单独记录。

| 范围 | 自动化 / 手动 | 当前状态 | 验收记录 |
|---|---|---|---|
| Dart/Rust 静态检查 | CI：`Dart and Rust checks` | 本地通过；仓库尚无 remote，首次 hosted CI 未运行 | 不使用麦克风或模拟设备宣称硬件通过。 |
| Fake capture 集成闭环 | CI：`Windows build`，`flutter test -d windows integration_test/fake_capture_session_flow_test.dart` | 本地通过；仓库尚无 remote，首次 hosted CI 未运行 | 验证流程恢复，不计入硬件覆盖。 |
| Release 构建 | CI：`Windows build`，`flutter build windows --release` | 本地通过；仓库尚无 remote，首次 hosted CI 未运行 | 上传 release runner artifact。 |
| 内置 Realtek PCM16 48 kHz 长音与暂停恢复 | 手动，真实设备 | Phase 0 已通过 | 60 秒样本误差 0.3167%，interval P95 47.615 ms；一次非持续 discontinuity。 |
| USB Audio PCM16 48 kHz 长音 | 手动，真实设备 | Phase 0 已通过 | 60 秒样本误差 0.0167%，无 discontinuity。 |
| 权限拒绝/撤回、无设备、设备拔插、采样率变化 | 手动，真实设备 | Pending | 记录有效格式、错误恢复和 quality flag。 |
| 有线/蓝牙路由、睡眠恢复、系统独占、崩溃后录音恢复 | 手动，真实设备 | Pending | 不以 fake capture 或 CI 代替。 |

每个新手动结果须记录设备类别、有效采样率/声道/处理器设置、chunk cadence、持续时间、dropped/discontinuity，以及应用版本和日期；不得提交录音内容。
