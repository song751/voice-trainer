# Repository instructions

## Read first

Before changing files, read these documents in order:

1. `docs/PROJECT_BLUEPRINT.md`
2. `docs/IMPLEMENTATION_PLAYBOOK.md`
3. `docs/FILE_MANIFEST.md`
4. `docs/RESEARCH_NOTES.md`

The desktop source guide is historical input. Repository documents are authoritative when they differ.

## Current phase

Phase 0 and the Phase 1 task cards are complete. The repository is now in
**Phase 1 Closure** and must follow `docs/PHASE1_CLOSURE_PLAN.md` one card at a
time. C1–C3 are complete; the next permitted card is C4. Do not start Phase 2 DSP
until C1–C4 are complete and C4 records hosted CI as green.

## Non-negotiable architecture

- Flutter owns presentation, application flow, Riverpod state, rule orchestration, and persistence access.
- Rust owns DSP. Keep a platform-neutral Rust core with a small batched bridge API.
- Start audio capture behind the `AudioCapture` contract using `record`. Replace it only if measured gates fail.
- Canonical capture request: mono, signed little-endian PCM16, 48 kHz. Record the effective device format; never assume the request was honored.
- Use monotonically increasing sample indices as analysis time. Wall-clock timestamps are metadata only.
- Keep full-band spectrum analysis at the effective capture rate. Downsample only the pitch branch with an anti-aliasing resampler.
- Capture must never wait for UI, database, disk analysis, or network work. Use a bounded queue and report dropped samples.
- The UI consumes a decimated `UiAnalysisFrame`; it never watches raw 100 Hz feature streams or PCM.
- Do not store one SQL row per analysis frame. Store versioned packed typed-array BLOBs plus segment/session summaries.
- Web Dart isolates are not background threads. Web DSP must use Rust WASM/worker execution and have a single-thread fallback.
- No production Python/Praat sidecar. Praat may be a development-only reference oracle; its code is GPL.

## Product and safety language

- Domain output is `Observation`, not `Diagnosis`.
- Do not infer medical conditions or vocal-fold state from consumer microphone data.
- Do not claim “提喉、挤压、漏气、闭合不足、疲劳风险” from a fixed threshold rule. Before validation, use descriptive measurements such as pitch deviation, level drift, periodicity, clipping, or low confidence.
- Every recommendation must include evidence, confidence, signal-quality flags, scope, and an exercise/content ID.
- When signal quality is poor, suppress interpretation and explain how to improve the recording.
- Training content must carry a review status. Unreviewed content cannot be presented as expert-approved.

## Implementation discipline

- Work one playbook phase or one explicitly bounded issue at a time.
- Do not add a new production dependency without recording its purpose, platforms, license, fallback, and removal cost in `docs/RESEARCH_NOTES.md`.
- Pin Flutter/Rust toolchains and commit lockfiles. Prefer stable packages; prereleases require a written ADR and an exit plan.
- Generated files are committed for reproducibility but never hand-edited. Regenerate Drift, Riverpod/Freezed, and FRB output using documented commands.
- Keep domain code independent of Flutter plugins, Drift, FFI, and platform APIs.
- Preserve user changes. Do not rewrite platform scaffolds unless a task requires it.
- If a Phase 0 spike disproves a decision, update the blueprint and research notes before implementing the replacement.

## Verification

For every applicable change, run the narrowest tests first, then the full gates documented in the playbook. A feature is not complete merely because it renders.

At phase boundaries, required checks include:

- `dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool`
- `flutter analyze`
- `flutter test`
- `cargo fmt --check --manifest-path rust/Cargo.toml`
- `cargo clippy --manifest-path rust/Cargo.toml --all-targets -- -D warnings`
- `cargo test --manifest-path rust/Cargo.toml`

Only run commands for files/toolchains that exist in the current phase. Record skipped platform tests and why; never report them as passed.

## Generated and large artifacts

- Do not commit build outputs, user recordings, external datasets, secrets, `.dart_tool`, `target`, or benchmark captures.
- Synthetic test WAV files may be committed only when deterministically generated, small, and documented.
- External/consented voice samples live outside Git; store only checksums and acquisition instructions when licensing and consent permit.
