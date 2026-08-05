# 目录与文件清单

本文件定义项目初始化后的目标结构。`[现有]` 表示本轮已创建；`[生成]` 表示由 Flutter、Drift、Riverpod/Freezed 或 FRB 生成；其余文件按实施阶段创建，不应现在用空文件占位。

## 1. 目标目录树

```text
voice-trainer/
├─ AGENTS.md                                      [现有]
├─ README.md                                      [现有]
├─ .gitignore                                    [现有；忽略构建、录音、数据库和凭据]
├─ .gitattributes                                 [现有；文本换行和二进制属性]
├─ analysis_options.yaml
├─ build.yaml
├─ pubspec.yaml
├─ pubspec.lock                                   [生成并提交]
├─ flutter_rust_bridge.yaml
├─ assets/
│  ├─ content/
│  │  ├─ exercises.zh-CN.json
│  │  └─ content.schema.json
│  ├─ icons/
│  └─ licenses/
│     └─ NOTICE.template.md
├─ lib/
│  ├─ main.dart
│  ├─ phase0/                                    [现有；开发 spike，Phase 1 后仍保留诊断入口]
│  │  ├─ capture_inspector.dart
│  │  ├─ capture_inspector_main.dart
│  │  ├─ dsp_benchmark_main.dart
│  │  ├─ drift_blob_spike_main.dart
│  │  └─ persistence/
│  │     ├─ feature_blob_codec.dart
│  │     ├─ phase0_database.dart
│  │     └─ phase0_connection_*.dart
│  ├─ bootstrap.dart
│  ├─ app/
│  │  ├─ app.dart
│  │  ├─ app_config.dart
│  │  ├─ app_lifecycle_observer.dart
│  │  ├─ router/
│  │  │  ├─ app_router.dart
│  │  │  └─ route_names.dart
│  │  ├─ theme/
│  │  │  ├─ app_theme.dart
│  │  │  ├─ app_colors.dart
│  │  │  └─ app_typography.dart
│  │  └─ shell/
│  │     └─ adaptive_app_shell.dart
│  ├─ core/
│  │  ├─ domain/
│  │  │  ├─ audio/
│  │  │  │  ├─ audio_capture.dart
│  │  │  │  ├─ capture_format.dart
│  │  │  │  ├─ capture_health.dart
│  │  │  │  └─ pcm_chunk.dart
│  │  │  ├─ analysis/
│  │  │  │  ├─ analysis_config.dart
│  │  │  │  ├─ analysis_engine.dart
│  │  │  │  ├─ analysis_frame.dart
│  │  │  │  ├─ analysis_quality_flag.dart
│  │  │  │  ├─ feature_series.dart
│  │  │  │  └─ session_summary.dart
│  │  │  ├─ observation/
│  │  │  │  ├─ observation.dart
│  │  │  │  ├─ evidence.dart
│  │  │  │  ├─ recommendation.dart
│  │  │  │  └─ observation_engine.dart
│  │  │  ├─ practice/
│  │  │  │  ├─ practice_template.dart
│  │  │  │  ├─ practice_target.dart
│  │  │  │  └─ subjective_check_in.dart
│  │  │  └─ persistence/
│  │  │     ├─ recording_locator.dart
│  │  │     ├─ recording_sink.dart
│  │  │     ├─ recording_store.dart
│  │  │     └─ session_repository.dart
│  │  ├─ audio/
│  │  │  ├─ audio_math.dart
│  │  │  ├─ note_mapper.dart
│  │  │  └─ wav_header.dart
│  │  ├─ errors/
│  │  │  ├─ app_exception.dart
│  │  │  └─ failure.dart
│  │  ├─ logging/
│  │  │  ├─ app_logger.dart
│  │  │  └─ log_redaction.dart
│  │  ├─ platform/
│  │  │  └─ platform_capabilities.dart
│  │  └─ widgets/
│  │     ├─ async_value_view.dart
│  │     ├─ empty_state.dart
│  │     └─ quality_flag_banner.dart
│  ├─ features/
│  │  ├─ home/
│  │  │  ├─ application/home_controller.dart
│  │  │  └─ presentation/home_page.dart
│  │  ├─ live_practice/
│  │  │  ├─ application/
│  │  │  │  ├─ live_practice_controller.dart
│  │  │  │  ├─ live_practice_state.dart
│  │  │  │  ├─ practice_session_coordinator.dart
│  │  │  │  └─ ui_frame_decimator.dart
│  │  │  ├─ domain/
│  │  │  │  ├─ practice_session_state.dart
│  │  │  │  └─ ui_analysis_frame.dart
│  │  │  └─ presentation/
│  │  │     ├─ live_practice_page.dart
│  │  │     ├─ live_practice_controls.dart
│  │  │     ├─ note_readout.dart
│  │  │     ├─ target_deviation_meter.dart
│  │  │     ├─ signal_quality_chip.dart
│  │  │     └─ charts/
│  │  │        ├─ pitch_curve_painter.dart
│  │  │        ├─ spectrum_painter.dart
│  │  │        ├─ spectrogram_controller.dart
│  │  │        └─ band_energy_painter.dart
│  │  ├─ session_result/
│  │  │  ├─ application/session_result_controller.dart
│  │  │  └─ presentation/
│  │  │     ├─ session_result_page.dart
│  │  │     ├─ observation_card.dart
│  │  │     └─ recommendation_card.dart
│  │  ├─ history/
│  │  │  ├─ application/
│  │  │  │  ├─ history_controller.dart
│  │  │  │  └─ trend_service.dart
│  │  │  └─ presentation/
│  │  │     ├─ history_page.dart
│  │  │     ├─ session_list_item.dart
│  │  │     └─ trend_chart_painter.dart
│  │  └─ settings/
│  │     ├─ application/settings_controller.dart
│  │     └─ presentation/
│  │        ├─ settings_page.dart
│  │        ├─ microphone_settings_section.dart
│  │        └─ privacy_settings_section.dart
│  ├─ infrastructure/
│  │  ├─ audio/
│  │  │  ├─ record_audio_capture.dart
│  │  │  ├─ record_capture_mapper.dart
│  │  │  ├─ fake_audio_capture.dart
│  │  │  └─ capture_metrics_collector.dart
│  │  ├─ dsp/
│  │  │  ├─ rust_analysis_engine.dart
│  │  │  ├─ rust_dto_mapper.dart
│  │  │  └─ analysis_worker_supervisor.dart
│  │  ├─ observation/
│  │  │  ├─ deterministic_observation_engine.dart
│  │  │  ├─ quality_gate.dart
│  │  │  └─ rules/
│  │  │     ├─ input_quality_rules.dart
│  │  │     ├─ target_pitch_rules.dart
│  │  │     └─ sustained_note_rules.dart
│  │  └─ persistence/
│  │     ├─ database/
│  │     │  ├─ app_database.dart
│  │     │  ├─ connection/
│  │     │  │  ├─ open_database.dart
│  │     │  │  ├─ open_database_native.dart
│  │     │  │  └─ open_database_web.dart
│  │     │  ├─ tables/
│  │     │  │  ├─ profiles.dart
│  │     │  │  ├─ practice_templates.dart
│  │     │  │  ├─ practice_sessions.dart
│  │     │  │  ├─ recordings.dart
│  │     │  │  ├─ analysis_runs.dart
│  │     │  │  ├─ feature_series_table.dart
│  │     │  │  ├─ segment_summaries.dart
│  │     │  │  ├─ observations.dart
│  │     │  │  ├─ recommendations.dart
│  │     │  │  ├─ calibrations.dart
│  │     │  │  └─ app_settings.dart
│  │     │  └─ daos/
│  │     │     ├─ session_dao.dart
│  │     │     ├─ analysis_dao.dart
│  │     │     └─ settings_dao.dart
│  │     ├─ repositories/
│  │     │  ├─ drift_session_repository.dart
│  │     │  └─ drift_settings_repository.dart
│  │     ├─ recordings/
│  │     │  ├─ native_recording_sink.dart
│  │     │  ├─ web_recording_sink.dart
│  │     │  ├─ recording_recovery_service.dart
│  │     │  └─ wav_stream_writer.dart
│  │     └─ codecs/
│  │        ├─ feature_blob_codec.dart
│  │        └─ bitset_codec.dart
│  ├─ l10n/
│  │  ├─ app_zh.arb
│  │  └─ app_en.arb
│  └─ generated/
│     └─ frb/                                    [生成，不手改]
├─ rust/
│  ├─ Cargo.toml
│  ├─ Cargo.lock                                 [生成并提交]
│  ├─ rust-toolchain.toml
│  ├─ build.rs                                   [仅 FRB/Cargokit 需要时]
│  ├─ src/
│  │  ├─ lib.rs
│  │  ├─ error.rs
│  │  ├─ model.rs
│  │  ├─ api/
│  │  │  ├─ mod.rs
│  │  │  ├─ realtime.rs
│  │  │  └─ offline.rs
│  │  ├─ pipeline/
│  │  │  ├─ mod.rs
│  │  │  ├─ realtime_analyzer.rs
│  │  │  ├─ offline_analyzer.rs
│  │  │  └─ frame_aggregator.rs
│  │  ├─ signal/
│  │  │  ├─ mod.rs
│  │  │  ├─ pcm.rs
│  │  │  ├─ ring_buffer.rs
│  │  │  ├─ dc_blocker.rs
│  │  │  ├─ window.rs
│  │  │  └─ resampler.rs
│  │  ├─ pitch/
│  │  │  ├─ mod.rs
│  │  │  ├─ estimator.rs
│  │  │  ├─ mcleod.rs
│  │  │  ├─ yin.rs
│  │  │  └─ continuity.rs
│  │  ├─ spectrum/
│  │  │  ├─ mod.rs
│  │  │  ├─ stft.rs
│  │  │  ├─ bands.rs
│  │  │  └─ ui_bins.rs
│  │  ├─ features/
│  │  │  ├─ mod.rs
│  │  │  ├─ level.rs
│  │  │  ├─ stability.rs
│  │  │  ├─ onset.rs
│  │  │  ├─ hnr.rs                         [Beta]
│  │  │  ├─ vibrato.rs                     [Beta]
│  │  │  ├─ formant.rs                     [Phase 6 Beta]
│  │  │  └─ cpps.rs                        [Phase 6 Beta]
│  │  └─ frb_generated.rs                        [生成，不手改]
│  ├─ tests/
│  │  ├─ chunk_invariance.rs
│  │  ├─ pitch_golden.rs
│  │  ├─ spectrum_golden.rs
│  │  └─ discontinuity.rs
│  └─ benches/
│     ├─ realtime_pipeline.rs
│     └─ bridge_payload.rs
├─ test/
│  ├─ core/
│  │  ├─ note_mapper_test.dart
│  │  └─ feature_blob_codec_test.dart
│  ├─ features/
│  │  ├─ live_practice_controller_test.dart
│  │  ├─ practice_session_coordinator_test.dart
│  │  └─ session_result_controller_test.dart
│  ├─ infrastructure/
│  │  ├─ deterministic_observation_engine_test.dart
│  │  ├─ quality_gate_test.dart
│  │  └─ recording_recovery_service_test.dart
│  ├─ widgets/
│  │  ├─ live_practice_page_test.dart
│  │  └─ session_result_page_test.dart
│  └─ helpers/
│     ├─ fake_clock.dart
│     ├─ fake_capture.dart
│     └─ test_database.dart
├─ integration_test/
│  ├─ fake_capture_session_flow_test.dart
│  ├─ recording_recovery_test.dart
│  └─ real_device_smoke_test.dart                 [手动/设备 farm]
├─ test_assets/
│  ├─ README.md
│  ├─ generated/
│  │  └─ manifest.json
│  └─ external/
│     └─ README.md                                [不提交受限音频]
├─ tool/
│  ├─ phase0_cdp_capture.mjs                     [现有；Edge 麦克风 gate]
│  ├─ phase0_cdp_dsp.mjs                         [现有；通用 Edge report/heap gate]
│  ├─ phase0_coep_server.ps1                     [现有；headers test harness]
│  ├─ generate_test_audio.dart
│  ├─ benchmark_report.dart
│  ├─ verify_feature_blob.dart
│  ├─ license_audit.ps1
│  └─ reference_analysis/
│     ├─ README.md
│     ├─ requirements.txt
│     └─ compare_with_praat.py                    [仅开发工具]
├─ docs/
│  ├─ PROJECT_BLUEPRINT.md                        [现有]
│  ├─ FILE_MANIFEST.md                            [现有]
│  ├─ IMPLEMENTATION_PLAYBOOK.md                  [现有]
│  ├─ RESEARCH_NOTES.md                           [现有]
│  ├─ PHASE1_TASKS.md                             [现有]
│  ├─ PHASE1_CLOSURE_PLAN.md                      [现有]
│  ├─ specs/
│  │  ├─ FEATURE_BLOB_V1.md                       [现有]
│  │  ├─ AUDIO_CONTRACT.md                        [现有]
│  │  └─ OBSERVATION_RULE_FORMAT.md
│  ├─ adr/
│  │  └─ README.md
│  └─ test-matrices/
│     ├─ windows.md
│     ├─ android.md
│     ├─ web.md
│     ├─ apple.md
│     └─ linux.md
├─ android/                                       [flutter create 生成]
│  └─ app/src/main/AndroidManifest.xml            [麦克风权限]
├─ ios/                                           [flutter create 生成]
│  └─ Runner/Info.plist                           [麦克风说明]
├─ macos/                                         [flutter create 生成]
│  └─ Runner/
│     ├─ Info.plist
│     ├─ DebugProfile.entitlements
│     └─ Release.entitlements                     [audio-input]
├─ windows/                                       [flutter create 生成]
├─ linux/                                         [flutter create 生成]
├─ web/                                           [flutter create 生成]
│  ├─ index.html
│  ├─ manifest.json
│  ├─ sqlite3.wasm                               [Drift 2.34.3 同版资源]
│  ├─ drift_worker.js                            [Drift 2.34.3 同版资源]
│  ├─ pkg/                                       [FRB Web 生成并提交]
│  ├─ headers.dev.json                            [COOP/COEP 开发配置]
│  └─ drift_worker.dart                           [若 Drift 生成流程需要]
├─ packages/                                      [默认不创建]
│  └─ voice_audio_capture/                        [仅 record gate 失败时]
└─ .github/
   └─ workflows/
      ├─ dart_rust_checks.yml
      ├─ windows_build.yml
      ├─ web_build.yml
      ├─ android_build.yml
      └─ apple_linux_build.yml                    [Beta]
```

## 2. 根文件职责

| 文件 | 职责 |
|---|---|
| `AGENTS.md` | Codex 每次运行自动读取的不可违反约束；保持短小，不复制整份蓝图。 |
| `README.md` | 当前状态、阅读入口、下一步。 |
| `.gitignore` | 忽略构建/缓存、运行时录音与本地数据库，以及凭据；确定性小型测试 WAV 仅在明确许可、文档化后以 force-add 例外提交。 |
| `.gitattributes` | 文本使用 LF（batch/cmd 例外为 CRLF）；音频、数据库、BLOB、WASM 和图像按 binary 处理。 |
| `pubspec.yaml` | 只放已批准的直接依赖、asset 和 Flutter 配置。 |
| `pubspec.lock` | 应用仓库必须提交，固定后续低价模型的构建环境。 |
| `analysis_options.yaml` | 启用严格分析；禁止用大量 ignore 掩盖 generated 以外的问题。 |
| `build.yaml` | Drift/Riverpod/Freezed 生成范围，避免扫描无关文件。 |
| `flutter_rust_bridge.yaml` | FRB 输入/输出路径和 web 配置的唯一来源。 |
| `.gitattributes` | 统一文本换行；WAV/BLOB 声明为 binary。 |

## 3. Dart 文件边界

### 3.1 `core/domain`

这里只能出现不可变实体、枚举、值对象和抽象接口。它不得导入：

- `package:flutter/*`
- `package:record/*`
- `package:drift/*`
- FRB generated 文件
- `dart:io` 或 `dart:html`

这样可以用普通 Dart 单元测试验证核心流程，并允许 Web/native 实现互换。

### 3.2 `features`

页面不直接打开麦克风、调用 Rust 或写数据库。`practice_session_coordinator.dart` 是闭环的应用服务，负责：

1. 创建 session 草稿。
2. 打开 capture/recording/analyzer。
3. 处理生命周期和错误。
4. 结束后聚合、规则解释和原子保存。

`live_practice_controller.dart` 只管理 UI 状态与用户意图，避免变成包含所有业务的上帝类。

### 3.3 `infrastructure`

所有第三方包都应在这里被包裹。上层不能散布 `AudioRecorder`、Drift table 或 FRB DTO。第三方 API 变更时，只需修改 adapter 和 mapper。

### 3.4 生成文件

Drift 的 `*.g.dart` 可与源文件相邻；Freezed/Riverpod generated 文件遵循工具默认。FRB generated 文件集中到 `lib/generated/frb` 和 `rust/src/frb_generated.rs`。全部提交但不手改，并在文件头保留 generated 标记。`web/pkg/` 的 FRB JavaScript/WASM、`web/sqlite3.wasm` 和 `web/drift_worker.js` 也提交：它们来自锁定工具链/Drift 包，CI 会重新生成并以 diff 拒绝漂移。FRB 自己生成的 `web/pkg/.gitignore` 保持 `*`；这些已提交的 Web bridge 文件以 force-add 方式纳入版本控制，新增输出也必须同样显式加入。

## 4. Rust 文件边界

- `api/` 只定义桥可见 DTO 和生命周期函数，不写算法。
- `pipeline/` 组合 signal、pitch、spectrum 和 features。
- `signal/` 处理样本、窗口、环形缓冲与重采样。
- `pitch/` 的 trait 保证 MPM/YIN/未来神经实现可换。
- `features/` 每个指标独立，输入/有效条件/输出都明确。
- `model.rs` 是内部 DTO；不要为了 FRB 便利让桥类型污染所有算法。
- 实时 `push` 路径不得读文件、打日志、锁全局 mutex、重新规划 FFT 或分配大 Vec。

## 5. 平台文件

`flutter create` 生成的平台工程必须保留在同一仓库。只手改必要配置：

- Android `RECORD_AUDIO`、最低 SDK 与 release shrink 配置。
- iOS/macOS 麦克风用途说明、macOS audio-input entitlement。
- Web CSP/COOP/COEP、Drift worker、WASM asset MIME 和缓存策略。
- Windows 打包身份/麦克风能力仅在实际 MSIX/Store 打包路径需要时添加；开发版先用 `record` 实测。
- Linux 安装说明列出 `parecord`/`pactl`/`ffmpeg`，直到自研 adapter 取代。

不要为了“看起来跨平台”手工复制条件分支到页面。差异收敛在 capability、capture、database connection 和 BlobStore。

## 6. 测试资产

`tool/generate_test_audio.dart` 或 Rust test helper 生成确定性样本，`manifest.json` 保存生成参数和 sha256。优先运行时生成；只有小型、稳定 golden 才提交二进制 WAV。

`test_assets/external` 不存人声音频，只记录数据集主页、许可证、下载步骤、选用文件和 hash。未明确许可或同意的录音不得进入 Git、CI artifact 或问题附件。

## 7. 何时创建 `packages/voice_audio_capture`

默认不创建该目录。只有某个平台未达到 Phase 0 gate，并且已记录以下内容时才创建：

1. 失败的设备/平台和可复现数据。
2. `record` 无法通过配置或上游修复解决的原因。
3. 计划使用的底层 API。
4. 只替换该平台还是建立联邦 package 的决定。
5. 与 `AudioCapture` contract 的兼容测试。

避免先创建一套没有实现的六平台 plugin scaffold。
