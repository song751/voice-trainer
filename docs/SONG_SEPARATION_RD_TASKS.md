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

## 后续锁定卡

- `SRD-02`：官方权重 → deterministic core ONNX export；tract/ORT operator 与数值 smoke。
- `SRD-03`：许可音频质量集、参考 F0/DTW、confidence/quality flags。
- `SRD-04`：经过授权的 Flutter/Rust product contract 与分平台 composition。

`SRD-02+` 未经仓库所有者在干净卡边界接受，不得开始；本分支的 SRD-01 不自动解锁任何 Phase 4 卡。
