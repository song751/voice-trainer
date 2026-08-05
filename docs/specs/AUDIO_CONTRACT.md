# Audio Contract v1

状态：Phase 0 accepted baseline；Phase 2 端到端延迟复验后可通过 ADR 调整。

## Capture request

- signed little-endian PCM16；mono；48,000 Hz。
- AGC、echo cancellation、noise suppression 默认请求 false。
- 每次开始必须记录 requested 与 effective config；平台未触发 config-changed callback 时记录 `requested-accepted-no-change-callback`，不能伪造未报告的设备能力。
- Web `streamBufferSize` 首选 512 samples，1024 为负载 fallback，2048 仅在实测需要时使用。
- Windows `record_windows` 的实测 stream chunk 约 2,400 samples；该插件不承诺用 `streamBufferSize` 控制 Windows chunk。

## Time and flow control

- `sampleIndex` 是分析时间的唯一权威；wall clock 只用于诊断 start/arrival/stop latency。
- PCM chunk 必须是完整 i16 sample；奇数字节视为 capture contract violation。
- Capture callback 只复制/入 bounded queue，不等待 DSP、UI、SQLite、录音落盘或网络。
- queue 以音频 samples/duration 计量；溢出必须累计 dropped samples 和 discontinuity，不允许静默覆盖。
- 暂停不生成虚假音频；恢复后的首个 arrival gap 不计为 dropped proxy，但 sample index 仍保持单调。

## Analysis batching

- capture chunk 与 bridge batch 解耦。初始 Rust bridge batch 为 1024 samples。
- Rust analyzer 持有重叠窗口、FFT plan 与预分配 scratch；Dart 不来回传内部 DSP state。
- 任意 chunk/batch 切分必须生成相同 frame start indices 和数值容差内相同特征。
- Native 通过 FRB worker pool；Web 生产路径使用 dedicated worker，并保留经过 Gate 0D 的单线程 fallback。Dart Web isolate/`compute` 不算后台线程。

## Persistence

- 原始录音进入独立 BlobStore/WAV sink，不进入 SQLite。
- feature series 按 `FEATURE_BLOB_V1.md` 列式保存；不允许一帧一 SQL row。
