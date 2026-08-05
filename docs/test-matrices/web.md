# Web 测试矩阵

状态：Phase 1 建立于 2026-08-04。默认发布路径是 Flutter JS + 单线程 Rust WASM；Flutter `--wasm` 不是此矩阵的通过条件。

| 范围 | 自动化 / 手动 | 当前状态 | 验收记录 |
|---|---|---|---|
| Dart/Rust 静态检查与 fake 会话 | CI：`Dart and Rust checks` | 本地通过；仓库尚无 remote，首次 hosted CI 未运行 | headless 测试不请求真实浏览器麦克风权限。 |
| FRB Rust WASM | CI：`Web build`，`flutter_rust_bridge_codegen build-web --release` | 本地通过；仓库尚无 remote，首次 hosted CI 未运行 | 检查提交的 `web/pkg` 无漂移。 |
| 默认 JS Web 构建 | CI：`Web build`，`flutter build web --release` | 本地通过；仓库尚无 remote，首次 hosted CI 未运行 | 不把 Flutter `--wasm` dry-run 当作已通过。 |
| Edge 512-sample PCM16 48 kHz | 手动，真实麦克风 | Phase 0 已通过 | 60 秒样本误差 0.0356%，interval P95 19.761 ms，无 discontinuity。 |
| Edge 1024-sample fallback | 手动，真实麦克风 | Phase 0 已通过 | 60 秒样本误差 0.0533%，interval P95 30.070 ms，无 discontinuity。 |
| Phase 1 dedicated DSP worker | 手动，真实浏览器 | Pending | 验证 worker crash/restart、fallback、主线程响应与 1024-sample DTO 限制。 |
| Chrome、Firefox、Safari/iOS Web | 手动，真实浏览器与麦克风 | Pending | 同时检查权限、有效采样率、后台 tab、设备路由与部署的 WASM MIME/CSP/缓存 headers。 |

普通 CI 的 fake capture 不可用于通过浏览器权限、真实音频 cadence、后台限频或麦克风质量项目。
