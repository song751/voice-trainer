# Song separation R&D harness

This directory is development-only. It is not imported by Flutter, FRB, or the production Rust crate.

## Rust contract and fallback

Generate a deterministic one-second 44.1 kHz stereo fixture into an ignored directory:

```powershell
cargo run --manifest-path tool/song_separation/Cargo.toml -- synthesize --output-dir $env:TEMP\voice-trainer-song-fixture
```

Validate a user-owned or authorized manual stem set:

```powershell
cargo run --manifest-path tool/song_separation/Cargo.toml -- validate `
  --acknowledge-rights `
  --mixture $env:TEMP\voice-trainer-song-fixture\mixture.wav `
  --vocals $env:TEMP\voice-trainer-song-fixture\vocals.wav `
  --accompaniment $env:TEMP\voice-trainer-song-fixture\accompaniment.wav
```

The command emits JSON progress and a final report without absolute paths. Passing `--cancel-file FILE` makes creation of that file a cooperative cancellation request. A successful report is explicitly marked `manual_stem_fallback` and `generated_by_model=false`.

## Official UMX-HQ development oracle

Use an isolated Python environment outside the repository. Install platform-appropriate PyTorch/Torchaudio first, then `requirements-oracle.txt`. Download the official vocals checkpoint separately from Zenodo and verify the published MD5 before running:

```powershell
python tool/song_separation/oracle_umxhq.py `
  --acknowledge-rights `
  --input $env:TEMP\voice-trainer-song-fixture\mixture.wav `
  --model $env:TEMP\voice-trainer-song-models\vocals-b62c91ce.pth `
  --output-dir $env:TEMP\voice-trainer-song-oracle
```

The oracle never downloads a model or audio and never uploads anything. Its output is development evidence only. Do not add `.pth`, `.onnx`, output WAV, reports, virtual environments, or user audio to Git.

To reproduce the current ONNX-core export gate, add `--export-onnx` with an ignored destination. The exporter requires the development-only `onnx` package and returns a typed `export_dependency_missing` or `export_failed` result instead of creating placeholder output:

```powershell
python tool/song_separation/oracle_umxhq.py `
  --acknowledge-rights `
  --input $env:TEMP\voice-trainer-song-fixture\mixture.wav `
  --model $env:TEMP\voice-trainer-song-models\vocals-b62c91ce.pth `
  --output-dir $env:TEMP\voice-trainer-song-oracle `
  --export-onnx $env:TEMP\voice-trainer-song-models\umxhq-vocals-core.onnx
```

The exporter uses a development-only equivalent forward that replaces upstream `.data.shape` constants with symbolic `.size()` values. The unmodified direct trace appears dynamic in its ONNX signature but fails for a frame count different from the 32-frame example; this failure is retained in ADR 0002.

Compare the exported core with PyTorch through ORT and write deterministic raw tensors outside Git:

```powershell
python tool/song_separation/verify_umxhq_onnx.py `
  --acknowledge-rights `
  --model $env:TEMP\voice-trainer-song-models\vocals-b62c91ce.pth `
  --onnx $env:TEMP\voice-trainer-song-models\umxhq-vocals-core.onnx `
  --output-dir $env:TEMP\voice-trainer-song-onnx-golden `
  --frames 32 47 300
```

Run the tract-first Rust smoke against one generated case:

```powershell
cargo run --release --manifest-path tool/song_separation/Cargo.toml --bin tract_smoke -- `
  --acknowledge-rights `
  --onnx $env:TEMP\voice-trainer-song-models\umxhq-vocals-core.onnx `
  --input-raw $env:TEMP\voice-trainer-song-onnx-golden\input-300.f32 `
  --expected-raw $env:TEMP\voice-trainer-song-onnx-golden\pytorch-expected-300.f32 `
  --frames 300
```

These commands validate only the magnitude model core. They do not provide the production STFT/ISTFT, Wiener/mask composition, full-song chunking, mobile/Web runtime, or perceptual quality gate.
