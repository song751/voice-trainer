# Apple 平台测试矩阵

状态：Pending。当前 Windows 机器未实测 macOS 或 iOS；没有对应 GitHub workflow，也不将 Flutter scaffold 视为平台验证。

| 平台 | 构建 | 真实麦克风手动矩阵 | 当前状态 |
|---|---|---|---|
| macOS | macOS runner 的 compile/build，待 Beta 增加 | 权限、内置/USB/蓝牙路由、48 kHz effective format、睡眠恢复、设备拔插、崩溃恢复 | Pending |
| iOS | macOS runner 的 archive/compile，待 Beta 增加 | 权限拒绝/撤回、来电/后台、蓝牙/有线耳机、Audio Session 路由、录音恢复 | Pending |

未来新增工作流前，先确认 `Info.plist` 麦克风用途说明和 macOS `audio-input` entitlement，并保留 FRB/Rust Apple target 的实际构建证据。
