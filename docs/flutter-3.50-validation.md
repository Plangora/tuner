# Flutter 3.50 upgrade validation — 2026-11-13

Development, test CI and release CI now use Flutter 3.50.0 stable, with Dart
3.14.0. The pubspec requires these SDK versions. App and widget-test Material
imports use `material_ui` 1.11.0 because Flutter 3.50 deprecates the bundled
Material library. Existing audio plugin versions are retained. Android Gradle
Plugin moves from 9.1.0 to 9.1.1, the minimum accepted by this Flutter SDK.
Android minimum/target SDK values remain 24/36.

## Automated checks

- Release candidate `1.1.0+9` was rechecked before tagging on 2026-11-13:
  dependency resolution, analysis and all 85 tests passed; unsigned iOS release
  compilation and Android `bundleRelease` passed. The iOS artifact declares
  `com.plangora.tuner`, version `1.1.0`, build `9`. Store signing and uploads are
  performed separately by the mobile-only release workflow.
- Baseline on Flutter 3.47.8: analyzer clean and all 85 tests passed, including
  the existing uncommitted landscape tests.
- Flutter 3.50.0: `flutter pub get`, `flutter analyze --no-pub` and
  `flutter test --no-pub --reporter expanded` passed; all 85 tests passed.
- `flutter build web --release --no-pub` passed, including the Wasm dry run.
- `flutter build ios --release --no-codesign --no-pub` passed (18.5 MB).
- `flutter build macos --release --no-pub` passed (47.8 MB universal app).
- Android `assembleRelease` passed after the AGP patch and command-local JDK
  override below (383 tasks, 3m 59s). The shrunk APK retains
  `audio_service_pause`, `audio_service_play_arrow` and `audio_service_stop`,
  checked with `aapt2 dump resources`.

## macOS runtime check and remaining accessibility issue

The normal debug entry point starts with microphone capture active. Opening
the metronome, Start, Stop and return to tuner worked through visible controls.
After return, the existing `practice.status` diagnostic reported `mode: tuner`,
`transport: stopped`, `captureActive: true` and `error: null`. No saved settings
were changed. This establishes transport/UI behavior, not audible output or
calibrated timing.

The run emitted repeated Flutter engine errors from `accessibility_bridge.cc`:
`Failed to update ui::AXTree` and `Nodes left pending by the update`. Native
accessibility inspection exposed the window/container but no Flutter controls,
although the rendered UI responded to clicks and scrolling. The Marionette
inspection connection also stalled after navigation and responded again after
the app was raised through computer use. The connection stall's cause is not
established. This is **not an issue-free macOS accessibility result**; neither
the engine errors' root cause nor whether they predate this upgrade has been
established. VoiceOver and release-mode accessibility need separate investigation.

## Environment and limits

The connected iPhone runs iOS 27.2.1. Debug deployment failed because the local
Xcode project has no usable development provisioning profile. No iPhone runtime
or audible playback result is established by this upgrade's unsigned build.

Flutter's saved JDK path points to a removed Homebrew version. Android checks
use the existing command-local workaround from `metronome-validation.md`:

```sh
cd android
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew assembleRelease
```

No global JDK settings, app data, signing configuration or store releases were
changed. Builds retain upstream CocoaPods/Swift Package migration suggestions,
the existing `audio_session` macOS compiler warning, and Android Gradle/Kotlin
deprecation/version warnings. These are separate from app analyzer results.

## Rollback

Keep the existing Flutter 3.47.8 SDK installed. To roll back this migration,
restore the previous `.tool-versions`, CI pins, SDK constraints, Material imports,
dependency lockfile and Android Gradle Plugin pin together, then run dependency
resolution and the analyzer/tests on 3.47.8. Preserve the pre-existing landscape
and version/changelog edits when reverting; this upgrade did not introduce them.
