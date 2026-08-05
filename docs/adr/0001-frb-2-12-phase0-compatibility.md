# ADR 0001：FRB 2.12 Phase 0 兼容策略

- 状态：Accepted
- 日期：2026-08-03
- 范围：Phase 0 scaffold；不决定 Phase 1 最终 Web DSP worker 实现

## 背景

FRB 2.12.0 的默认 `thread-pool` feature 会在 Web 初始化 `WorkerPool`，并把当前非共享的 `WebAssembly.Memory` 发送给 Worker。Edge 在有无 COOP/COEP 时都以 `DataCloneError` 拒绝该对象。关闭该 feature 后，FRB 2.12 的默认 handler 宏又会把无线程池 stub 包装为不兼容的 `LocalKey`，因此仅改 Cargo feature 仍不能编译。

Android 还暴露三项与当前工具链有关的问题：Kotlin 增量缓存不能把 C: 的 pub cache 相对化到 D: 工作区；Gradle 9 移除了旧 `Project.exec` API；FRB 模板的 `compileSdkVersion 33` 低于当前 AndroidX 元数据要求。

## 决策

1. Web baseline 禁用 FRB 的 `thread-pool` feature，显式保留其余默认 features；Native target 继续使用 FRB 默认线程池。
2. API 模块导出 `FLUTTER_RUST_BRIDGE_HANDLER`，使用 `DefaultHandler<SimpleThreadPool>`。Native 上该类型是真实池，Web 上是无操作 stub。`init_app` 和 Phase 0 `greet` 标记为同步；这只适合极短调用，DSP 不得据此放到浏览器主线程。
3. Android 设置 `kotlin.incremental=false`；vendored Cargokit task 通过注入的 `ExecOperations` 执行命令；vendored Android library 的 compile SDK 与应用统一为 36。
4. 不升级到 FRB prerelease，不关闭 TLS 校验，不切换未批准镜像，也不手工下载 AAR 填充 Gradle cache。

## 后果

- Gate 0B 的 Web hello 可在 Edge 上运行，且 baseline 不依赖 `SharedArrayBuffer` 或跨源隔离。
- Phase 0D 必须另外验证批量 DSP 不阻塞 UI；正式 Web 架构仍需 dedicated worker 与单线程 fallback，不能把同步 hello 路径扩展为实时 DSP 路径。
- 再次运行 FRB `integrate` 或替换 `rust_builder/` 可能覆盖 Cargokit 与 compile SDK 补丁。任何 FRB/Gradle 升级都要先删除临时补丁做上游复验，再更新本 ADR。
- `kotlin.incremental=false` 会牺牲 Android 增量编译速度，直到 Kotlin 修复跨盘符缓存问题或依赖缓存与工作区位于同一卷。

## 复验

```powershell
flutter_rust_bridge_codegen generate
cargo check --manifest-path rust/Cargo.toml
cargo check --manifest-path rust/Cargo.toml --target wasm32-unknown-unknown
flutter_rust_bridge_codegen build-web --release
flutter build web --release
flutter build windows --debug
flutter test integration_test/simple_test.dart -d windows
flutter build apk --debug
```

Edge runtime 不能以“构建成功”代替。启动 `flutter run -d edge --cross-origin-isolation` 后，必须确认页面显示 `Hello, Tom!`，控制台包含 `PHASE0_FRB_GREETING=Hello, Tom!`，且没有 `DataCloneError`、panic 或未处理异常。
