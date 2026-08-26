# Voice Trainer third-party notices

This notice accompanies release artifacts. It is not a substitute for the
license text distributed by each upstream project. The application source and
the two retained Android plugin archives remain available in the repository at
the revision from which the artifact was built.

## Rust production components

| Component | Locked version | License | Upstream source |
|---|---:|---|---|
| `flutter_rust_bridge` | 2.12.0 | MIT | <https://github.com/fzyzcjy/flutter_rust_bridge> |
| `rustfft` | 6.4.1 | MIT OR Apache-2.0 | <https://github.com/ejmahler/RustFFT> |
| `serde` | 1.0.228 | MIT OR Apache-2.0 | <https://github.com/serde-rs/serde> |
| `sha2` | 0.10.9 | MIT OR Apache-2.0 | <https://github.com/RustCrypto/hashes> |
| `symphonia` and codec/format crates | 0.5.5 | MPL-2.0 | <https://github.com/pdeljanov/Symphonia/tree/v0.5.5> |
| `tract-onnx` and tract crates | 0.23.5 | MIT OR Apache-2.0 | <https://github.com/sonos/tract/tree/0.23.5> |
| `serde-wasm-bindgen` | 0.6.5 | MIT | <https://github.com/RReverser/serde-wasm-bindgen> |
| `wasm-bindgen` | 0.2.114 | MIT OR Apache-2.0 | <https://github.com/wasm-bindgen/wasm-bindgen> |

The complete resolved Rust dependency set and its declared license metadata is
audited from the committed Cargo lockfiles by
`dart run tool/p4_13_release_audit.dart`.

### Symphonia MPL source availability

Voice Trainer uses unmodified Symphonia 0.5.5. The exact Source Code Form is
available from the upstream tag above and from the crates.io package archive:
<https://crates.io/api/v1/crates/symphonia/0.5.5/download>. The committed
`rust/Cargo.lock` records archive SHA-256
`5773a4c030a19d9bfaa090f49746ff35c75dfddfa700df7a5939d5e076a57039`.
Symphonia is licensed under MPL-2.0; its license text is available at
<https://www.mozilla.org/MPL/2.0/>. No Symphonia source modifications are
shipped by this repository.

## Vendored Flutter Android implementations

- `audioplayers_android 5.3.0`, MIT. The retained upstream license and
  provenance are in `third_party/audioplayers_android/LICENSE` and
  `third_party/audioplayers_android/UPSTREAM.md`.
- `file_selector_android 0.5.2+9`, BSD-3-Clause. The retained upstream license,
  authors and provenance are in `third_party/file_selector_android/LICENSE`,
  `third_party/file_selector_android/AUTHORS`, and
  `third_party/file_selector_android/UPSTREAM.md`.

The local changes in both plugin directories are build-only Gradle integration
patches; production Dart/Kotlin/Java source remains upstream. Release artifacts
carry this notice and the retained license/provenance files alongside the
binary (or inside the Web deployment directory).
