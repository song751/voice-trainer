# Linux 测试矩阵

状态：Pending。当前机器未实测 Linux；没有对应 GitHub workflow，也不将 Flutter scaffold 视为采集验证。

| 范围 | 自动化 / 手动 | 当前状态 | 验收记录 |
|---|---|---|---|
| Linux release build 与 Dart/Rust checks | Ubuntu runner，待 Beta 增加 | Pending | 安装和记录构建依赖；不要把构建结果当成麦克风通过。 |
| `record_linux` runtime prerequisites | 手动 | Pending | 记录 `parecord`、`pactl`、`ffmpeg` 的版本及 PipeWire/PulseAudio 环境。 |
| 真实麦克风长音、暂停恢复、设备拔插 | 手动，物理设备 | Pending | 记录 effective format、chunk cadence、dropped/discontinuity。 |
| 权限/门户、蓝牙、有线耳机、休眠、崩溃恢复 | 手动，物理设备 | Pending | 记录发行版、桌面环境、音频服务与设备类别。 |

若 Linux 的 `record` adapter 未达到已记录的采集门槛，先形成失败复现和 contract tests，再决定是否创建单平台替换实现。
