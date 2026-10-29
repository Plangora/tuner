# Metronome implementation and validation — 2026-10-29

Status: Production integration is implemented in the existing dark/neon style. Initial integrated functional checks use macOS, as approved by the human. Earlier physical iPhone/Samsung feasibility checks passed for background playback and system controls. Calibrated timing and the broader release matrix remain outstanding.

## Production integration

- Project and CI use asdf Flutter `3.47.8-stable`; the human's release workflow version update is preserved.
- Separate metronome screen; tuner remains the launch screen. Native PCM playback, tempo, tap tempo, beats per bar, subdivisions, volume and versioned settings persistence are implemented. Saved settings never start playback automatically.
- Start/Stop has a minimum 64 logical-pixel height, larger text and icon, and standard visual density on every platform. Layout checks include a 320-pixel display with double-size text.
- A serialized app-owned controller stops microphone capture before playback and stops playback before returning to the tuner. Generation guards reject stale starts and system Play commands in tuner mode. Focus loss, route changes and asynchronous engine failures update transport state.
- iOS uses the device-tested non-mixing playback session with background audio. Android includes the media-playback foreground service and retains the three dynamically resolved transport icons in release builds. Unsupported targets keep the tuner available and explain playback availability.
- Production dependencies and lockfile are updated. Bundled audio notices are included in Flutter's license registry.
- Verification: 60 tests pass and Flutter analysis reports no issues. Native macOS debug, Android release, unsigned iOS release and web builds pass. These checks establish compilation and tested behavior, not audible timing accuracy.
- Integrated macOS runtime through Marionette: tuner capture active; entering metronome releases capture; Start advances native playback position without error; returning to tuner removes the playback voice and restores capture. Settings survived restart at 80 BPM with playback stopped.
- Integrated signed Android release installed/launched on the Samsung for review. The iPhone was disconnected during production integration, so integrated iPhone runtime is not claimed. Physical lock-screen/control results below concern the earlier isolated probe.

Before release, verify the integrated app on physical phones for lock-screen and notification controls, interruptions, Bluetooth/wired routes, endurance, battery and calibrated onset timing. These remain release follow-ups rather than completed measurements.

The sections below preserve the historical package spike and its evidence. References to an unchanged production app describe the state during that spike.

## Environment

- Flutter 3.47.8 stable, Dart 3.13.7, local macOS 27.2 / arm64.
- Available: physical iPhone on iOS 27.2; macOS; Samsung SM-F9260 physical Android phone connected later for validation (Android 15 / API 35, security patch 2026-08-05). Initial Android builds were performed before it was connected.
- Probe project: `/private/tmp/tuner-metronome-probe-20261029`, separate bundle ID `com.plangora.spike.metronomeProbe`.
- Actual tuner pubspec/lockfile compatibility: resolved successfully in `/private/tmp/tuner-metronome-compat-20261029` with `record 7.1.1` and `audio_session 0.1.25` retained. Transitive `meta` changed from 1.18.3 to 1.19.0; production lockfile remains untouched.
- Pinned dependencies: `flutter_soloud 5.2.2`, `audio_service 0.18.19`, `audio_session 0.1.25`; later added `marionette_flutter 0.6.0` for debug-only runtime checks at the human’s suggestion. These resolved successfully in the probe.
- Production `pubspec.yaml` / lockfile, tuner code and native configuration remain unchanged.

## Released-source findings

Inspected the downloaded pub.dev release source, not only GitHub branch heads:

- `flutter_soloud-5.2.2/lib/src/soloud.dart`: `loadMem` accepts WAV bytes; `play(..., looping: true)` creates a native looping voice. Repeating one generated PCM bar requires no per-beat Dart scheduling.
- `src/soloud/src/backend/miniaudio/soloud_miniaudio.cpp`, `init_platform_context`: iOS context sets session category to none and disables automatic session activation/deactivation. The app must configure and activate the playback session.
- `SoLoud.audioDeviceStartFailures`: native output startup is asynchronous; a valid voice can exist while output is silent. Listen to this stream and use awaited `startAudioDevice()` when starting/recovering. Native device notifications have platform limitations; voice validity alone is not evidence of audible output.
- `hook/build.dart`: `hooks.user_defines.flutter_soloud.no_xiph_libs: true` excludes optional Opus/Ogg/Vorbis/FLAC codecs. PCM/WAV does not need these codecs. The initial test build included them; the macOS debug and unsigned iOS release builds below passed with them disabled. This reduces codec scope but does not replace the remaining bundled-component notice audit.
- `audio_service-0.18.19/pubspec.yaml` permits `audio_session >=0.1.25 <0.3.0`; no forced session upgrade is needed for this pair.
- Wrapper licenses are MIT; SoLoud core license is zlib/libpng. A full bundled-component notice inventory is still required before shipping.

Probe source and reproducible preparation instructions are preserved in [`metronome-probe/`](metronome-probe/README.md). Temporary build logs: `/private/tmp/tuner-metronome-{macos,ios,android}-build.log`.

## Probe behavior and limits

The probe precomputes a PCM16 mono 44,100 Hz four-beat bar, accents beat one, and loops it natively at 50% volume. Tempo choices are 40/120/137/240 BPM. Tempo edits stop the old voice and restart a fresh bar; this deliberately does not establish seamless musical-boundary updates. Pause/resume also restarts beat one. A button deliberately blocks Dart for five seconds to test independence from UI scheduling. The handler publishes play/pause/stop controls and BPM metadata; iOS background audio mode and Android foreground-service setup are included only in the probe.

The initial prototype used iOS mix-with-others; the human reported no lock-screen or iPhone Control Center controls while audio kept playing. The current trial switches iOS to playback with no mixing options. Android retains a transient-may-duck focus request. The human confirms the non-mixing correction restores iPhone system controls. Recommend this iOS policy for production; final production defaults still require confirmation. It contains no microphone, tuner-mode navigation, persistence, tap tempo or production controller. It cannot validate mic/session handoff or stale tuner-mode Play yet.

## Evidence

- `flutter test test/rhythm_test.dart`: 3/3 passed after the initial three expected failures against the stub. Tests check the four-beat PCM/WAV structure, accent, silent tail, absolute fractional-frame rounding and invalid tempos. This is generated-buffer evidence only.
- Final `flutter analyze --no-pub` after Marionette instrumentation: no issues found (4.8 seconds). An unnecessary-cast warning in the debug extension was removed first.
- `flutter build macos --debug`: passed. Existing upstream `audio_session` unused-expression warning and Flutter script-phase warning were emitted. SoLoud native framework reports macOS minimum 12.0, matching the current shipping target.
- `flutter build ios --release --no-codesign`: passed; generated iOS target is 15.0, `Runner.app` is 17.2 MB. Unsigned build only: no phone installation or playback claim.
- Android build: Flutter’s configured Java path points at removed Homebrew `openjdk@21/21.0.12.1`. A process-local `JAVA_HOME` does not override that Flutter selection. Retried directly via `JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew assembleDebug` in the probe’s `android/`; passed in 3m 32s (239 actionable tasks). Debug APK generated at `build/app/outputs/flutter-apk/app-debug.apk`. No global Java/Flutter settings changed. AGP 9 / Kotlin plugin deprecation warnings and Android SDK XML-version mismatch warnings appeared before compilation.
- macOS runtime smoke: computer use initially hit an automatic permission-review timeout; its one retry succeeded. Then, at the human’s suggestion, added a debug-only Marionette binding and read-only `probe.nativeStatus` extension. Connected through Marionette MCP and exercised the actual UI against the native engine:
  - Start at 120 BPM: `playing=true`, native device `started`, valid voice, no error.
  - Deliberately block Dart for five seconds: native device still `started`, valid voice afterward. This establishes native state survival, not the absence of audible gaps.
  - Change to 137 BPM: valid playing voice, no error; edit restarts the bar as disclosed.
  - Pause: `playing=false`, no voice, device `stopped`.
  - Resume: playing/valid voice/device started.
  - Stop: `processingState=idle`, `playing=false`, no voice, device stopped. Left playback stopped.
- macOS audible listening confirmation was requested; no response recorded yet. No external recording or onset timing measurement was taken.
- Physical iPhone: release-mode signing/deployment started with a separate probe bundle ID using the already configured development team; signed release build passed in 73.1s, installation/launch completed in 7.5s. The probe is installed and launched on the connected physical iPhone (iOS 27.2). Marionette is debug-only, so physical release lock testing must be observed directly.
- Physical iPhone background playback: **passed by human listening observation**. The human reports that locking the screen and switching apps do not stop the sound. This is audible continuity evidence for this device/session; it is not an external onset-timing measurement or a 30-minute endurance result. Audio route was not specified.
- iPhone system controls: **failed in the initial mixing configuration** by human observation. No lock-screen or iPhone Control Center controls were visible, so system pause/resume could not be tested. The human clarified this concerns iPhone Control Center, not macOS Mission Control.
- Production tuner analysis: `flutter analyze --no-pub` passed with no issues (3.5 seconds); production Dart/dependency/native files remain unchanged.
- Corrected iPhone lock-screen / Control Center controls: **passed by human observation** after removing iOS mixing. The human confirmed they work in response to the requested pause/resume check.
- Measured audible timing, Bluetooth, interruptions and endurance: untested. Release Android background playback and notification pause/resume are now human-confirmed. Android system media-command results are recorded below. Do not infer these from dependency resolution, builds or unit tests.

## Samsung Android device validation

Device: Samsung SM-F9260, Android 15 / API 35, security patch 2026-08-05. Native arm64 physical device. Audio route/listening result not yet recorded. No product code or global Java/Flutter settings changed.

Current-source debug APK rebuilt through the command-local JDK workaround: `./gradlew assembleDebug` passed in 6 seconds. Launched with `flutter run --debug --no-pub --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk`. Flutter did not report the VM URI, but the probe-only Android logcat contained it; forwarded that local service port and connected through Marionette MCP. No product code change was needed.

Verified through actual UI actions, native status and Android system service APIs:

- Initial state: stopped/idle; engine uninitialized; no automatically audible playback.
- UI Start at 120 BPM: valid voice, native device started, playing/ready state, no error.
- Android `cmd media_session list-sessions` lists the probe. `dumpsys media_session` reports an active PLAYING session with 120 BPM metadata; System UI is registered as a controller. `dumpsys activity services` reports the media-playback foreground service, ID 1124, with a public transport notification. This is service-state evidence, not visual inspection of the notification.
- `cmd media_session dispatch pause`: native voice removed, device stopped, playing=false/ready; no error.
- `cmd media_session dispatch play`: native voice valid, device started, playing=true/ready; no error. Resume works after a system pause in this debug/foreground case.
- UI tempo edit to 137 BPM: valid playing voice; no error. As disclosed, edits restart the bar.
- UI blocks Dart for five seconds: afterward native device is still started, voice valid, no error. No external audio recording was made, so this does not prove absence of audible gaps.
- `cmd media_session dispatch stop`: stopped/idle with no native voice; Android session becomes inactive/NONE and the service is no longer foreground (`startRequested=false`).

Prepared a release APK using `./gradlew assembleRelease`: passed in 2m 39s (306 actionable tasks). This throwaway APK uses the generated project's debug signing key, not a store release. Release installation/launch passed (17.9s install). The first release run then failed media-session publication with `IllegalArgumentException: You must specify an icon resource id to build a CustomAction`. That initial release failed the background/notification gate; the correction and successful retest are recorded below. The release build has no Marionette binding, so audible screen-lock continuity and notification visibility require direct device observation; Android service state can still be inspected via ADB.

Logs: `/private/tmp/tuner-metronome-android-device-{debug,release}-build.log`, `/private/tmp/tuner-metronome-android-{debug,release}-run.log`.

Release-only regression: native SoLoud audio can start while Android media state remains inactive/NONE because `audio_service` fails constructing the Android 13+ custom Stop action. Released native source resolves its icon dynamically with `getIdentifier`. The release shrinker report marks `audio_service_stop`, `audio_service_pause` and `audio_service_play_arrow` unreachable, and an `aapt2 dump resources` assertion confirms all three are absent from the release APK. Debug mode retained them, explaining the earlier passing media-command tests.

Minimal correction: add `android/app/src/main/res/raw/metronome_keep.xml` with a `tools:keep` rule for exactly those three dynamic drawable resources. The source snapshot and `prepare.py` include it; the production app is untouched. Rebuild release, recheck the actual APK resources, and retest media session/foreground notification on the physical Samsung. Release regression verification: rebuilt in 8 seconds. The same `aapt2 dump resources` assertion that failed before the keep rule now passes for all three icons. Installed/launched the corrected release APK (17.9s install). On-device release logs show a successful playing transition and then a paused transition; Android media state now reports an active PAUSED session and a custom Stop action with nonzero icon ID, with no recurrence of the missing-icon exception in the checked process log. ADB media-controller monitoring also reports the paused state/metadata. The human was then asked to confirm clicks continue while locked and notification pause/resume works, and replied “works!”. **Corrected Android release background playback and notification pause/resume: passed by human observation.** This is short-session functional evidence, not calibrated onset timing or endurance proof.

One Samsung device does not satisfy the later two-vendor/long-endurance release matrix. No Bluetooth, call interruption, calibrated onset timing, or battery measurement is established by this smoke test.

## iPhone missing-controls investigation

Using systematic debugging and the surgical-patch workflow, compared the probe with released `audio_service` native code. `AudioServicePlugin.m` registers remote play/pause/stop handlers and publishes Now Playing metadata from the handler’s media item/state. The probe was correctly publishing those values, but explicitly requested `AVAudioSessionCategoryOptions.mixWithOthers`.

Apple’s [WWDC22 media metadata guidance](https://developer.apple.com/videos/play/wwdc2022/110338/?time=274) says eligibility for Now Playing requires a registered remote-command handler and a non-mixable audio session category/options. This identifies the mixing flag as the leading cause of the reported iPhone failure.

Minimal trial: keep the native PCM loop and background handler unchanged; replace only iOS `mixWithOthers` with `none` under the playback category. The human’s observed missing controls are the failing device reproduction; assertions about a Dart configuration constant cannot prove OS UI behavior. Updated-probe checks: `flutter analyze --no-pub` passed with no issues (4.0s), and all three rhythm tests passed. Signed release redeployment passed: Xcode build 19.3s, installation/launch 3.0s. The updated probe is on the connected iPhone; log: `/private/tmp/tuner-metronome-iphone-controls-run.log`. The human was asked to check lock-screen / Control Center controls, including pause and resume, and replied that they are working now. **Corrected iPhone system controls: passed by human observation.** Earlier lock/app-switch playback was also human-confirmed; no calibrated timing or endurance measurement has been performed.

Tradeoff: the current non-mixing trial can interrupt other music. The proposed default of mixing cannot be promised alongside iOS Now Playing controls under this configuration. Native-engine fallback would not resolve this audio-session policy conflict.

## Timing method for device gate

Record audible output externally or via calibrated loopback. Analyze all onset intervals, including loop seams; report requested-vs-measured tempo bias separately from interval residuals around the fitted period. Remove startup latency only. The proposed 10 ms / ten-minute drift gate is about 16.7 ppm and is inconclusive unless independent recording-clock error is calibrated. Unit tests establish PCM construction only, not actual output accuracy.

## Historical feasibility decision

Recommend `flutter_soloud 5.2.2` plus `audio_service 0.18.19`: the basic background-playback/system-control feasibility checks now pass on the tested iPhone and Samsung. iOS requires the verified non-mixing playback policy to expose controls; Android shrunk release builds need the three media icon resources retained. All three native builds pass, and macOS transport-state checks pass. The human subsequently approved the proposed defaults and implementation. External onset measurement and the broader device/endurance matrix remain outstanding.

## Historical feasibility recommendation after device checks

Proceed with `flutter_soloud 5.2.2` plus `audio_service 0.18.19` for the planned integration, using the subsequently approved production defaults. Keep the iOS non-mixing playback policy when system controls are required, and retain the three Android dynamically resolved media icons in shrunk release builds. No app-owned native fallback is indicated by these device findings. Production integration is now implemented as recorded above. Mic handoff and unsupported-platform behavior have automated coverage, with mic handoff also checked on macOS. Measured onset timing, longer endurance, physical audio routes/interruptions and the broader device matrix remain outstanding.
