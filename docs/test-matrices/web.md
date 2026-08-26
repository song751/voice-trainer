# Web 测试矩阵

状态：Phase 1 建立于 2026-08-04；P4-09 于 2026-08-26 完成本地采集/worker 生产组合，P4-10/P4-11 于 2026-08-27 完成本地持久化、生命周期与自包含部署合同。默认发布路径是 Flutter JS + dedicated Rust WASM worker，显式保留单线程 fallback；Flutter `--wasm` 不是此矩阵的通过条件。

| 范围 | 自动化 / 手动 | 当前状态 | 验收记录 |
|---|---|---|---|
| Dart/Rust 静态检查与 fake 会话 | CI：`Dart and Rust checks` | 本地通过；hosted CI 已首次触发，链接见 C1 执行记录 | headless 测试不请求真实浏览器麦克风权限。 |
| FRB Rust WASM | CI：`Web build`，`flutter_rust_bridge_codegen build-web --release` | 本地通过；首轮 drift 已修复并重新触发，链接见 C1 执行记录 | 检查提交的 `web/pkg` 无漂移。 |
| 默认 JS Web 构建 | CI：`Web build`，canonical self-contained flags | P4-13 hosted通过（`b221014`） | 固定 `--no-web-resources-cdn --csp`及`nightly-2026-08-02`；不把Flutter `--wasm` dry-run当作通过。 |
| Edge 512-sample PCM16 48 kHz | 手动，真实麦克风 | Phase 0 已通过 | 60 秒样本误差 0.0356%，interval P95 19.761 ms，无 discontinuity。 |
| Edge 1024-sample fallback | 手动，真实麦克风 | Phase 0 已通过 | 60 秒样本误差 0.0533%，interval P95 30.070 ms，无 discontinuity。 |
| P4-09 dedicated Rust worker | 自动，Edge headless + synthetic PCM | 最终候选本地通过 | 94 frames / checksum 2,098,080；8-band DTO，unknown operation、crash pending rejection、replacement worker 通过；`crossOriginIsolated=false`，不依赖 SharedArrayBuffer。Edge 151额外browser-owned page由origin-aware CDP选择排除。 |
| P4-09 `record_web` capture | 自动，Edge fake audio device | 部分通过：明确 typed unsupported | permission deny 未启动 capture；grant 路径收到 94×512 frames / 48,128 samples，effective 44.1 kHz stereo，Rust 正确返回 `unsupportedFormat`。这不是真实麦克风/voiced 证据。 |
| P4-09 single-thread fallback/backpressure | Flutter unit/contract tests | 本地通过 | supervisor 覆盖 restart-once、fallback、terminal failure、timeout 和 oldest-drop accounting。 |
| P4-10 Web persistence | 自动，Edge headless + synthetic PCM/metadata | 最终候选本地通过 | Drift `sharedIndexedDb` + recording OPFS；创建、reload、历史、删除、重建通过。JS contract另覆盖OPFS append cleanup、IndexedDB fallback、quota/private typed result；失败后server listener也按command line验证并清理。录音不进SQLite。 |
| P4-10 sample-index limit | Flutter unit + Edge release | 本地通过 | 60 秒按 sample index，跨界 chunk 精确裁剪；暂停 wall-clock 不计入。Edge gate 用 1 秒同构测试参数减少测试数据量。 |
| P4-11 self-contained deployment/cache | 自动 + Edge headless | 本地通过 | release 固定 `--no-web-resources-cdn --csp`；27 个关键资产/8 个 WASM 的 release hash、统一 header、`no-store`、WASM MIME、CSP、本地 CanvasKit 通过；无 COOP/COEP，`crossOriginIsolated=false`。 |
| P4-11 lifecycle | Flutter unit + Edge headless synthetic lifecycle | 本地通过 | typed permission/devicechange/hidden/visible/AudioContext/worker events；hidden 和 AudioContext interruption 保存 sample-index checkpoint，恢复后仍需用户显式继续。不是实际后台录音或真实麦克风证据。 |
| P4-12 UI/错误/无障碍 | Widget profile matrix + Edge self-contained regression | 本地通过（synthetic） | Web profile 覆盖 393×852、深色、200% 文字、五主页面和歌曲导入、typed errors、worker/quality/completed/delete、touch/mouse/keyboard/back 与 bounded semantics；Edge 再验证自包含 release/header/lifecycle。Flutter WebDriver integration 因本机无 4444 driver 未执行，不误记为产品失败。 |
| P4-13 release seal | CI + local equivalent-server validator | 接受（`b221014`） | 28个关键资产（含NOTICE）、8个WASM通过release hash、no-store、MIME、CSP和本地CanvasKit；P4-09/P4-10/P4-11 Edge gates及hosted Web CI均通过。不是P4-15真实浏览器/麦克风证据。 |
| Chrome、Firefox、Safari/iOS Web | 手动，真实浏览器与麦克风 | Pending | 同时检查权限、有效采样率、后台 tab、设备路由与部署的 WASM MIME/CSP/缓存 headers。 |

普通 CI 的 fake capture 和 Edge fake audio device 不可用于通过真实麦克风、真人声 cadence、后台限频或麦克风质量项目。
