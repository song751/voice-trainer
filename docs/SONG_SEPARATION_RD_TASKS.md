# 歌曲人声分离 R&D 固定任务卡

状态：独立研究分支；不属于 P4-03，不改变产品能力声明。

## SRD-01 — 许可、模型与可执行合同

**允许修改：** `docs/adr/0002-*`、本文、`docs/RESEARCH_NOTES.md`、`docs/FILE_MANIFEST.md`、`.gitignore`、`tool/song_separation/`。

**禁止修改：** `lib/`、Flutter 页面与 providers、P4 composition、数据库 schema、FRB generated、现有 Rust production DSP/阈值。

**必须交付：**

1. 固定 UMX-HQ vocals-only 模型来源/hash/许可边界，以及 tract/ORT 候选的部署、fallback 和移除成本。
2. Rust test-only CLI：确定性生成短 WAV；校验本地 mixture/vocals/accompaniment；JSON progress；协作式 cancel；typed failure；报告不含路径。
3. Python/PyTorch 开发 oracle：使用显式模型/输入/输出，不自动上传或提交资产；成功时记录真实耗时、peak RSS、长度和 SHA-256，失败时输出最小 typed failure。
4. 模型、音频、ONNX/ORT 和报告产物保持 Git ignored。

**验收命令：**

```powershell
cargo fmt --check --manifest-path tool/song_separation/Cargo.toml
cargo clippy --manifest-path tool/song_separation/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path tool/song_separation/Cargo.toml
cargo run --manifest-path tool/song_separation/Cargo.toml -- synthesize --output-dir <ignored-dir>
cargo run --manifest-path tool/song_separation/Cargo.toml -- validate --acknowledge-rights --mixture <wav> --vocals <wav> --accompaniment <wav>
python tool/song_separation/oracle_umxhq.py --help
```

**通过边界：** Rust contract 全绿只证明 harness/fallback 可运行。只有 oracle 实际加载官方 hash-matched 权重并产生长度匹配的 vocals/residual，才可另行记录“PyTorch oracle 通过”；这仍不证明 tract/ORT、Android、Web 或真实歌曲质量。

## SRD-02 — UMX-HQ core ONNX 与 runtime 数值 smoke（已完成，R&D evidence only）

**范围：** 开发期固定导出、PyTorch/ORT/tract core 数值对比；不实现 production waveform/STFT/Wiener pipeline，不改变产品 composition。

**已交付：**

1. `oracle_umxhq.py` 以显式官方 checkpoint 导出 opset 17、batch=1、动态 frame 维的 vocals magnitude core；重复导出 SHA-256 相同。
2. `verify_umxhq_onnx.py` 对 32/47/300 frame 确定性 tensor 做 PyTorch ↔ ORT 数值比较，raw tensor 只写用户指定的 Git 外目录。
3. `tract_smoke` 对同一 ONNX 与 PyTorch raw oracle 做 32/47/300 frame operator、shape、数值和 release-time smoke；进度、取消、rights、contract/backend/numerical failure 均 typed。
4. 记录 direct upstream forward 导出的动态 frame 失败和 export-friendly equivalent forward 的修复；不掩盖模型仅为 magnitude core。

**通过边界：** tract/ORT core smoke 通过不等于歌曲分离 production 通过。Rust/Flutter 仍没有 44.1 kHz stereo STFT/ISTFT、mask/residual、长音频分块、取消延迟、Android/Web 内存或许可歌曲质量 gate。

## SRD-03 — 许可质量清单与 reference-F0/DTW gate（非人工实现已完成）

**范围：** `tool/song_separation/` 的开发期质量 evaluator、schema、测试与证据文档；不修改 production Rust、Flutter/FRB、页面、provider 或 composition。

**已交付：**

1. v1 strict manifest 强制逐 case license/source/verifier/date、模型/合成 provenance、Git 外相对路径和四个 SHA-256；拒绝路径越界、未知字段、hash/format/长度不符。
2. 44.1 kHz stereo PCM16 waveform evidence：whole-excerpt SI-SDR、mixture baseline/improvement、residual error、RMS/clipping；与 museval/BSS Eval v4 明确区分。
3. 仅对人工核对为 `monophonic_lead` 的 reference 运行版本化 autocorrelation F0 + bounded DTW；和声、叠唱、多人声或未核对 case 必须 `not_eligible` 并 suppress pitch interpretation。
4. waveform/pitch 分列 confidence、quality flags、interpretation suppression、JSON progress、细粒度协作式 cancel；报告不含路径、曲名或 PCM。
5. 6 项确定性测试覆盖 identity 数值/F0、错误音高+residual、rights/hash、取消、path traversal，以及 pitch-ineligible 时保留 waveform confidence；加上既有 4 项 contract 共 10 项通过。
6. Windows 上对一个官方 MUSDB18 7 秒 restricted research sample 完成真实 UMX-HQ oracle→quality evaluator smoke；完整 hash/数值和证据限制记录于 `SONG_SEPARATION_QUALITY_PROTOCOL.md`。

**人工/权利接受项：** 仓库所有者仍须提供或确认可用的逐曲授权集，并人工听觉核对可标为 `monophonic_lead` 的 case。当前单个短 AAC sample 只接受为工具 smoke，不能作为多曲听感或产品质量 gate。非人工实现无需为此停住 SRD-04 的代码设计，但不得把 SRD-03 写成最终质量通过。

**验收命令：**

```powershell
cargo fmt --check --manifest-path tool/song_separation/Cargo.toml
cargo clippy --manifest-path tool/song_separation/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path tool/song_separation/Cargo.toml
cargo run --release --manifest-path tool/song_separation/Cargo.toml --bin song_separation_rd -- evaluate --acknowledge-rights --manifest <git-outside>/quality-manifest.json --dataset-dir <git-outside>/quality-audio
```

## SRD-04 — production waveform pipeline 与分平台 composition（实现完成，平台接受证据受限）

已交付 production Symphonia decode、有界 windowed-sinc 44.1 kHz 重采样、center-reflection periodic-Hann 4096/hop-1024 STFT、reviewed-hash tract UMX-HQ magnitude core、mixture-phase ISTFT、complex residual accompaniment、300-frame chunk/64-frame overlap weighted crossfade、长度/边界、平台帧上限、progress/cancel/partial cleanup 和原子 PCM16 stem 输出。算法明确使用 Open-Unmix `niter=0` 路径：预测 vocals magnitude 配 mixture phase，并以 complex mixture-minus-vocals 生成 accompaniment；没有把它误称为多通道 Wiener。

Flutter `SongSeparator` 已接 FRB stream，返回 model/algorithm/source/output/chunk 与 stem locator/hash/byte-length；模型由用户本地导入且强制固定 SHA-256，权重不进 Git。Windows 与 Android 使用 native runtime；Web 明确 composition 到 typed unavailable/manual fallback，不编译 tract。Windows debug build 与 30 秒/3 分钟/5 分钟确定性 waveform smoke 通过；Android debug APK 与 MuMu x86_64 模拟器上的真实模型 probe、7 秒文件全链路通过。模拟器不是 Android 真机，Web 没有已审核模型 runtime，因此这两项不能写成真机/Web 性能通过。

Android canonical release 包体已量得 universal `118.7 MB`，split armv7/arm64/x86_64 分别 `30.4/41.2/48.0 MB`，且不包含外置模型权重；因此 native capability 只作为 **probe-gated candidate** 启用，不作无条件可用声明。

**未关闭的接受风险：** Android 真机 30 秒与 60 秒内存/RSS、取消延迟和包体产品接受；Windows peak RSS；多曲许可集与人工听感仍待 owner。当前安全上限是 Windows 5 分钟、Android 1 分钟，超过时 typed `resource_limit_exceeded`，不是假成功。SRD-04 实现完成不关闭 Phase 3/4 或人工/真机 gate。

SRD-01/02/03 均不自动解锁任何 Phase 4 卡，也不允许把 Python oracle、tool crate 或 synthetic identity 接入产品。
