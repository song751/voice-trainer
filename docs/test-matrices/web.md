# Web 测试矩阵

状态：Phase 1 建立于 2026-08-04；P4-09 于 2026-08-26 完成本地生产组合与 synthetic browser 自动化。默认发布路径是 Flutter JS + dedicated Rust WASM worker，显式保留单线程 fallback；Flutter `--wasm` 不是此矩阵的通过条件。

| 范围 | 自动化 / 手动 | 当前状态 | 验收记录 |
|---|---|---|---|
| Dart/Rust 静态检查与 fake 会话 | CI：`Dart and Rust checks` | 本地通过；hosted CI 已首次触发，链接见 C1 执行记录 | headless 测试不请求真实浏览器麦克风权限。 |
| FRB Rust WASM | CI：`Web build`，`flutter_rust_bridge_codegen build-web --release` | 本地通过；首轮 drift 已修复并重新触发，链接见 C1 执行记录 | 检查提交的 `web/pkg` 无漂移。 |
| 默认 JS Web 构建 | CI：`Web build`，`flutter build web --release` | 本地通过；hosted CI 已首次触发，链接见 C1 执行记录 | 不把 Flutter `--wasm` dry-run 当作已通过。 |
| Edge 512-sample PCM16 48 kHz | 手动，真实麦克风 | Phase 0 已通过 | 60 秒样本误差 0.0356%，interval P95 19.761 ms，无 discontinuity。 |
| Edge 1024-sample fallback | 手动，真实麦克风 | Phase 0 已通过 | 60 秒样本误差 0.0533%，interval P95 30.070 ms，无 discontinuity。 |
| P4-09 dedicated Rust worker | 自动，Edge headless + synthetic PCM | 本地通过 | 94 frames / checksum 2,098,080；8-band DTO，unknown operation、crash pending rejection、replacement worker 通过；`crossOriginIsolated=false`，不依赖 SharedArrayBuffer。 |
| P4-09 `record_web` capture | 自动，Edge fake audio device | 部分通过：明确 typed unsupported | permission deny 未启动 capture；grant 路径收到 94×512 frames / 48,128 samples，effective 44.1 kHz stereo，Rust 正确返回 `unsupportedFormat`。这不是真实麦克风/voiced 证据。 |
| P4-09 single-thread fallback/backpressure | Flutter unit/contract tests | 本地通过 | supervisor 覆盖 restart-once、fallback、terminal failure、timeout 和 oldest-drop accounting。 |
| Chrome、Firefox、Safari/iOS Web | 手动，真实浏览器与麦克风 | Pending | 同时检查权限、有效采样率、后台 tab、设备路由与部署的 WASM MIME/CSP/缓存 headers。 |

普通 CI 的 fake capture 和 Edge fake audio device 不可用于通过真实麦克风、真人声 cadence、后台限频或麦克风质量项目。
