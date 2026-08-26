# ADR 0002：歌曲人声分离 R&D 基线

- 状态：Provisional / R&D only
- 日期：2026-08-26
- 范围：`tool/song_separation/` 与独立验证文档；不改变 Phase 4 product composition

## 背景

产品希望支持“导入本地歌曲 → 分离歌手人声/伴奏 → 与用户练唱录音对比”。这比现有 48 kHz mono 实时采集合同多出一个独立的 44.1 kHz stereo、长任务、模型驱动离线路径。它不能借用模拟器或合成信号冒充真实歌曲质量，也不能把 Python/PyTorch sidecar 带入产品。

当前仓库已封存 P4-02；本 ADR 只建立可独立合并的 R&D 证据，不解锁 P4-03、不关闭 Phase 3/4 的真实设备 gate，也不授权修改现有 UI、capture/persistence composition、DSP 阈值或观察规则。

## 决策

### 初始模型

首个可部署候选固定为 Open-Unmix `UMX-HQ` 的 **vocals-only** 模型：

- 上游代码：`sigsep/open-unmix-pytorch`，MIT；release `1.3.0`（2024-04-16）。
- 权重：Zenodo record `3370489` 的 `vocals-b62c91ce.pth`，35.6 MB。
- 上游发布的 MD5：`d918985fad0fedf6d9ce89e279aa7218`。
- 获取 URL：`https://zenodo.org/records/3370489/files/vocals-b62c91ce.pth`。
- 输入合同：44,100 Hz stereo；STFT 4096、hop 1024；core 输入/输出为 stereo magnitude spectrogram。
- 只运行 vocals target；伴奏为 residual。不得误用默认 `UMXL`：上游明确将其权重标为 `CC BY-NC-SA 4.0`，不适合作为可能商业分发的默认模型。

代码许可证不替代歌曲权利。模型、导出的 ONNX/ORT、用户歌曲、分离 stem 与 benchmark 输出全部留在 Git 外；发布前还要把权重记录自身的许可元数据和 NOTICE 做一次人工法律/许可证复核。

### 运行时候选

| 候选 | 平台与用途 | 许可 | 采用条件 | fallback / 移除成本 |
|---|---|---|---|---|
| `tract` | 纯 Rust；Windows/ARM CPU/WASM；优先验证 UMX-HQ core ONNX | MIT OR Apache-2.0 | 官方权重的自有导出可加载；与 PyTorch oracle 数值和音频回归通过；目标设备内存/耗时达门槛 | 隔离在未来 `SourceSeparator` adapter；移除不影响现有实时 DSP |
| ONNX Runtime | Windows/Android 原生 C API；Web 可由 worker 内的 `onnxruntime-web` 提供 WebGPU/wasm runtime | MIT | mobile usability checker、operator partition、单线程 fallback、真机/Web benchmark 均通过 | runtime 包和平台 glue 较重；保留同一模型/张量合同可换回 tract |

本卡不把任一候选加到 production `rust/Cargo.toml`。只有导出与 operator smoke 成功后，才能在下一张明确任务卡记录实际 binary/model size、transitive license、平台包方式与 removal plan，再添加依赖。

SRD-02 已在独立 tool package 固定 `tract-onnx 0.23.5` 做 Windows CPU smoke，并固定 Python `onnx 1.22.0` / `onnxruntime 1.29.0` 做开发验证。它们仍不是 production dependency：ONNX 为 Apache-2.0，ORT 为 MIT，tract 原始代码可选 MIT/Apache-2.0。tract 上游当前推荐 production 采用稳定 facade/NNEF 路线，而不是长期依赖内部 crate；下一次采用决策必须比较 NNEF/OPL 转换、WASM feature 集和 stripped binary，当前未 strip 的 Windows harness `tract_smoke.exe` 约 25.4 MB 不能当作最终包增量。

### 开发 oracle 与产品边界

`tool/song_separation/oracle_umxhq.py` 可以使用 Python、PyTorch、Torchaudio 和 Open-Unmix 做开发期 oracle/导出尝试。它必须：

1. 接受显式本地输入、显式本地模型和权利确认；
2. 不下载歌曲、不上传音频；
3. 输出 typed JSON progress/failure；
4. 只写用户指定的、Git 忽略的目录；
5. 记录版本、模型 hash、输入/输出长度/hash、wall time 和 peak RSS；
6. 永不被 Flutter、FRB、Android 或 production Rust 调用。

生产 fallback 是用户提供等长、同格式的 `mixture/vocals/accompaniment` WAV。Rust harness 对其做合同校验与哈希，不声称由模型生成，也不声称分离质量通过。

## 隐私、版权与失败语义

- 运行前必须显式 `--acknowledge-rights`；它只是防误用提示，不授予任何权利。
- 报告不得包含绝对路径、PCM 或歌曲标题，只包含角色、格式、长度、hash、耗时和 typed 状态。
- 支持 progress 与协作式取消；取消不报告 completed，未完成输出应删除或保留为明确 `.partial`。
- typed failure 至少区分：rights 未确认、输入不存在、格式不支持、模型不存在、backend 不可用、取消、输出合同不符和 backend failure。
- 默认离线；未来云端不得成为静默 fallback。

## 替代方案

- HTDemucs 仅作高质量开发对照：官方仓库已归档，Python/PyTorch 部署重，`two-stems` 仍运行完整四源模型，不作为当前跨平台默认。
- Spleeter 不进入生产：TensorFlow/Python 路径与现有 Rust/Web 架构不合。
- UVR/BS-RoFormer/Mel-RoFormer/SCNet 社区 checkpoint 不进入默认包：权重许可、再分发和稳定下载缺少足够明确的一手证据，常见模型也显著更大。
- 不抓取或解密 Spotify、Apple Music、YouTube 等流媒体内容。

## 下一决策 gate

在任何产品实现前必须提交一份可复核报告，至少包含：

- 官方 vocals 权重的已发布 MD5 与本地 SHA-256；
- 30 秒、3 分钟与 5 分钟输入的 wall time、peak RSS、取消响应和输出长度；
- PyTorch oracle 对 ONNX + tract、ONNX Runtime 的 magnitude/output 误差；
- Windows、Android 真机、Web 单线程和 WebGPU 分列结果；
- 许可音频的听感/残留与 reference-F0 confidence 评估。

任一导出/runtime 失败时保留最小失败复现，继续提供手工双 stem fallback；不得生成假的 vocals 文件或把 contract test 写成模型成功。

## SRD-02 结果补记（2026-08-26）

- 直接 trace 上游 `OpenUnmix.forward` 时，`.data.shape` 把 32-frame reshape 固化；虽然 ONNX input 声明动态 frame，ORT 运行 47 frame 会在 `Reshape_1` 请求 `{32,1,512}` 失败，tract 对 47-frame fixed input 在 prepare 阶段返回 typed `backend_incompatible`。
- 导出脚本因此包含一份仅开发期、语义等价的 MIT upstream forward wrapper，以 `.size()` 保留符号 frame。opset 17 ONNX 重复两次导出的 SHA-256 均为 `1dd15a2be2f15ba035205f866a035df38d85b27824ad67fe53566e80ec1f4258`，大小 `35,626,526` bytes；不提交该文件。
- operator 集：`Add, BatchNormalization, Concat, Constant, ConstantOfShape, Gather, LSTM, MatMul, Mul, Relu, Reshape, Shape, Slice, Squeeze, Tanh, Transpose, Unsqueeze`。
- ORT CPU 对 32/47/300 frames 全部通过；相对 PyTorch 最大绝对误差分别约 `8.27e-7 / 8.53e-7 / 1.53e-6`，300-frame 单次 core inference `0.0568 s`，session build `0.0551 s`，报告时 process RSS 约 `804.6 MB`。
- tract CPU 对 32/47/300 frames 全部通过；最大绝对误差约 `1.05e-6 / 1.04e-6 / 1.13e-6`。300-frame release core inference `0.2679 s`，load/prepare `0.1155 s`；其他平台尚未验证。
- 这只验证 44.1 kHz stereo magnitude core。production 仍缺 STFT/ISTFT、mask/Wiener/residual、长音频分块和端到端音频数值/质量 gate，因此不把本结果写成“歌曲分离已接入”。
