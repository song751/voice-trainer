# Vendoring record

- Package: `audioplayers_android 5.3.0`
- Publisher: `blue-fire.xyz`
- Source: locked pub.dev archive
- Archive SHA-256: `f5ff5b15620fbab8cb0849e9636c48e2b96c3f0f71723bbbe2ad3c761b205f05`
- License: MIT; upstream `LICENSE`, `README.md` and `CHANGELOG.md` are retained.

The production Kotlin/Java source is unchanged. The local Android Gradle file
only removes the package's embedded AGP 7.3.1, Kotlin 1.7.10 and JUnit5
buildscript/repositories. It reuses this repository's pinned AGP 9.0.1 with
built-in Kotlin, matching the existing `file_selector_android` policy and
avoiding a second, network-resolved Android toolchain. Its analyzer include is
redirected from the upstream-only `flame_lint` dev dependency to the repository
rules; this does not change production source.

To update or remove the override, restore the hosted dependency, compare the
new archive and license, repeat Windows/Android/Web builds and the local A/B
playback gate, then delete this directory only after those gates pass.
