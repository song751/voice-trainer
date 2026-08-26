# file_selector_android vendoring record

- Upstream package: `file_selector_android 0.5.2+9`
- Source: `https://pub.dev/packages/file_selector_android/versions/0.5.2+9`
- Pub archive SHA-256: `1d45e9910f68c16eb0c74f0b10097ad81aed516ea28054c027137e8f7d75e840`
- Upstream repository: `https://github.com/flutter/packages/tree/main/packages/file_selector/file_selector_android`
- License: BSD-3-Clause; the unmodified upstream `LICENSE`, `AUTHORS`, changelog and README are retained here.

## Local build-only patch

`android/build.gradle.kts` omits the upstream package's private `buildscript`
and `allprojects.repositories` blocks. The plugin instead resolves
`com.android.library` from the application's pinned AGP `9.0.1` plugin
classpath in `android/settings.gradle.kts`. Production Dart, Java, Kotlin, Pigeon-generated
code, manifest and public APIs are otherwise the exact published package.

This removes the otherwise independent online resolution of AGP `8.13.1`
(`com.android.databinding:baseLibrary:8.13.1`) while keeping the patched
post-GHSA release. Do not replace this with `file_selector_android <=0.5.1+11`,
which is affected by GHSA-r465-vhm9-7r5h.

## Update and removal

To update, download the official pub archive, verify the archive hash shown by
`pubspec.lock`/pub.dev, replace the retained upstream files, reapply only the
buildscript removal, and run Windows/Web/Android file-picking plus all platform
build gates. Remove this override once upstream no longer resolves a private
AGP classpath that conflicts with the repository's pinned toolchain.

## Verification baseline

- `flutter test test/tool/file_selector_android_vendor_test.dart`
- `android/gradlew :file_selector_android:assembleRelease --offline --rerun-tasks`
- `flutter build apk --release`

The first two checks make the source/version/license/buildscript patch
auditable and prove the plugin itself compiles without resolving its former
private AGP. The final command remains the canonical application build gate.
