# Metronome implementation and validation — 2026-10-29

## Android mixing correction and iOS regression — 2026-10-30

Android release testing on a Samsung SM-F9260, Android 15/API 35, found a
separate audio-focus issue. The recorder requested permanent focus, while
metronome playback requested transient ducking focus. Existing music was
lowered to 20% volume, and starting music could interrupt the metronome.
Android capture now disables the recorder's interruption/focus management;
metronome activation/deactivation does not request or abandon audio focus.
Its media-playback foreground service and system controls are retained.

- On the physical Samsung, release-mode startup, repeated Start/Stop, tuner
  microphone restoration and background/resume passed. An independent local
  music fixture and the native metronome remained started in both playback
  orderings, without the earlier focus conflict. The human subsequently
  confirmed both remained audible with the Samsung locked.
- A recorder-boundary regression test inspects the actual `RecordConfig`
  passed to `startStream`: Android uses `none`, while iOS retains `pause`.
  All 70 tests and the analyzer pass.
- The same working tree was retested in release/AOT mode on iPhone 17 Pro Max,
  iOS 27.2, using existing local development signing. Startup, three Stop/Start
  cycles, microphone restoration, playback after tuner and background/resume
  passed. Music-first mixing passed. The reverse-order check initially met a
  Bluetooth route change and the existing explicit route-change pause;
  SoLoud stayed initialized. After the human disconnected Bluetooth, the
  built-in-speaker reverse-order check passed: both independent players
  advanced concurrently from 05:38:50 through 05:39:25 UTC, including app
  background/resume. Locked iPhone listening was not repeated; the earlier
  human confirmation below remains separate evidence.
- An initial temporary diagnostic asserted capture before queued resume work
  completed. Awaiting that lifecycle work corrected the diagnostic; no
  production change was needed for this assertion.
- Normal main-entry apps were restored on both phones, temporary audio was
  stopped, and existing app data was retained. These device checks used build
  number 6 with the then-uncommitted Android correction; build 7 packages that
  source with updated release metadata. No calibrated timing, endurance or
  comprehensive Bluetooth/interruption result is established.

## Current iPhone mixing policy — 2026-10-30

The human subsequently prioritised playing a song and the metronome together.
Metronome media controls on the iPhone lock screen/Control Center are intentionally
absent; their absence is no longer a failure or release blocker.

- Playback uses `playback` with `mixWithOthers` (native option mask 1), without
  `duckOthers`. Tuner capture also mixes: `playAndRecord` with `mixWithOthers`
  and `defaultToSpeaker` (mask 9). This preserves an existing song during the
  default tuner launch and return from the metronome, without routing built-in
  playback to the receiver. The native startup-order correction is retained.
- The iPhone runtime does not initialize `audio_service` or publish a media
  handler/Now Playing metadata. The pinned plugin only activates its command
  center when its handler publishes a playing state; skipping that handler
  avoids competing with the song's metadata/commands. iOS background ticking
  uses its existing native loop and `UIBackgroundModes: audio`. Android's
  required foreground media service and macOS controls remain unchanged.
- Both new regression tests failed against the earlier policy. All 68 tests
  now pass, analysis is clean, and the iOS release build passes (18.5 MB).
- Physical release/AOT check on the same iPhone 17 Pro Max/iOS 27.2 uses the
  actual `PracticeRuntime`, including its lack of an iPhone media handler.
  Initial/repeated playback and tuner microphone restoration pass; native
  category/option masks match the configuration above.
- A temporary independent native app plays a locally generated melody under
  a normal non-mixing playback session and publishes its own music metadata.
  No account/purchase was required and no device-volume setting was changed.
  Its initial test-fixture failure was an iOS scene-lifecycle adoption trap;
  the fixture was corrected without any additional Tuner change.
- **Metronome then melody:** from 04:29:27 UTC, both independent playback
  positions advance and both apps report `isOtherAudioPlaying: true`, with
  the metronome backgrounded and no transport error.
- **Melody then Tuner:** cold launch at 04:30:05 UTC preserves the melody
  through tuner capture, first metronome Start, repeated Start/Stop, microphone
  restoration and metronome reentry. Other-audio flags stay true in capture and
  playback; the independent player records no interruption and stays playing.
  These are native concurrency observations, not yet a listening confirmation
  with the user's chosen music app.

At 04:36:02 UTC the human replied "confirm" to the explicit request to lock the
phone and confirm that both the temporary melody and metronome remain audible.
**Simultaneous audible playback while locked: passed by human observation.**
This is distinct from the independent native-position/other-audio evidence.
The source is a controlled local melody, not a test of a named third-party music
app or a calibrated audio/endurance measurement.

After that confirmation, both identified diagnostic processes were terminated.
The normal release build from `lib/main.dart`, `com.plangora.tuner` version
`1.1.0+6`, was installed and launched without uninstalling or clearing data.
Its installed app URL and running executable identify the normal production
artifact. The AOT artifact has no diagnostic log markers. The temporary media
fixture, `com.plangora.tuner.mixingMediaTest`, remains installed but stopped;
it was not deleted. Project signing configuration remains unchanged.
Raw logs: `/tmp/tuner-phone-mixing-results.jsonl` and
`/tmp/tuner-mixing-media-results.jsonl`. No push or publication occurred.

## iPhone startup investigation — 2026-10-30

The supplied TestFlight screenshot shows `SoLoudBackendNotInitedException:
The player is not initialized (on the C++ side)` after Start, with Retry at
94 BPM. The screenshot was downloaded from the supplied Library reference and
visually inspected. The human reports that development debug mode did not show
the failure.

Confirmed code defect: `PracticeController.start()` initialized SoLoud before
configuring and activating playback. After tuner capture, the iOS session was
left in `AVAudioSessionCategory.record`, then deactivated by `enterMetronome()`.
The pinned `flutter_soloud 5.2.2` native backend explicitly disables automatic
audio-session category changes and activation. Its `Player::init()` opens the
output device immediately and maps backend initialization failure to the exact
exception shown. The correction configures and activates playback first, with
cancellation cleanup after native initialization. A failed initialization still
releases the session, and explicit Retry repeats session preparation.

This was initially a hypothesis; the physical release-mode comparison below
now reproduces the exact exception with the original order and passes with the
corrected order. The unchanged app successfully started native playback
on an iPhone 18 Pro / iOS 27.0 simulator after real tuner capture. That simulator
result cannot validate physical-device audio-session restrictions. There is no
debug/release branch in this controller or its audio-session policy; the debug
binding adds Marionette diagnostics. Clicks are generated PCM in memory, rather
than a release-prunable bundled sound asset. Prior integrated runtime validation
was on macOS; the earlier physical iPhone release probe had no recording/tuner
handoff. Those tests did not cover the failing production transition. The exact
reason the human's development run differed remains unverified.

Regression coverage checks session readiness at native initialization, denied
activation, native initialization failure followed by Retry, leaving during
initialization, repeated Start, interruption, tuner navigation, and
background/resume transport behavior. These use fakes and establish controller
ownership/order, not actual iPhone output. A local unsigned iOS release build
passes with the correction; compilation is not a device playback result.

At the initial investigation no physical iPhone was connected. The later USB
validation below closes the startup-reproduction and release-device transport
gates. Specific lock-screen audio, tempo
edits in release, and a same-device debug comparison remain unrecorded for this
run. No store upload, release tag or persistent signing change is part of this
correction. Build 6 is local Unreleased metadata only.

Final local verification: all 66 Flutter tests pass, analysis reports no issues,
and `flutter build ios --release --no-codesign --no-pub` passes (19.0 MB app).
The final iPhone 18 Pro / iOS 27.0 debug simulator run passed three Start/Stop
cycles at 94 BPM with advancing native positions, tuner microphone restoration,
reentry and playback, switching to Settings while playing, foreground resume,
and Stop after resume. Initial smoke-driver runs raced asynchronous button and
navigation rendering; waiting for enabled controls, microphone readiness and
the destination screen resolved those driver failures. These are transport and
native-position observations, not audible or physical release validation.

The separately requested Tap tempo refinement fills the control width, with a
72-logical-pixel minimum height, 32-pixel icon and larger label. Widget checks
cover a 320×568 screen at normal and double-size text and a tap near the button
edge. The existing small-screen overflow check also passes. An actual rendered
screen was captured through the app's Marionette screenshot API on that debug
simulator and visually checked; the simulator's system screenshot surface was
blank/stale, so it was not used as the deliverable. Screenshot Library ID:
`libfile_ebf96e13c0888191ac40d9d6a526638a`.

### Physical release comparison after USB connection

Device: iPhone 17 Pro Max, iOS 27.2 (24B119). Tuner `1.1.0+5` was initially
installed. Both diagnostic variants were compiled in release/AOT mode as local
build `1.1.0+6`, using the same production controller, capture, session, engine,
and background handler. A temporary entry point automated controller commands
and logged the native category/initialization result. It read saved settings
but suppressed all settings writes. No uninstall or app-data clearing occurred.

- Original order, 04:03:47 UTC: actual tuner capture was active with category
  `record`. Native initialization ran under `record` and returned
  `SoLoudBackendNotInitedException`; Start and Retry both failed. The stack
  reaches `SoLoud._initialize`, `SoloudMetronomeEngine.initialize`, then
  `PracticeController.start`. The wrapper exposes `backendNotInited`; the
  underlying miniaudio/AudioUnit OSStatus is not exposed by this log.
- Corrected order, first launch 04:04:48 UTC: native initialization ran under
  `playback`, succeeded, and generated advancing native playback positions at
  94 BPM. Three Start/Stop cycles and tuner microphone restoration/reentry
  passed. Four additional cold launches, including a three-launch batch, passed
  the same sequence. This is five successful corrected release launches.
- The human's 04:04:17 UTC report of the same error preceded the corrected
  variant's launch; the phone was still running the deliberately original-order
  baseline. The 04:05:04 and 04:09:14 UTC reports that it was working align with
  corrected release runs. These observations support playback but do not
  independently establish lock-screen/system-control coverage.
- App switching: launching Settings produced `hidden`/`paused` at 04:09:54 UTC.
  The engine stayed initialized, native positions advanced and transport stayed
  playing. Returning at 04:10:16 UTC produced `resumed`; playback stayed healthy.
- A separate first-run pause at 04:05:17 UTC reported `Audio route changed. Tap
  Start to resume.`, with the engine still initialized. The actual route change
  was not captured, so its cause is not inferred. It differs from the startup
  exception; subsequent cold-launch and background/resume runs passed without
  that error. No extra production fix was added for this event.

An existing Apple Development certificate and already-installed wildcard profile
covering this phone signed temporary app copies. Xcode initially rejected that
Xcode-managed profile under manual App Store build settings; those temporary
settings were restored. Subsequent unsigned builds were signed locally without
creating credentials/profiles or changing project signing configuration.

After testing, the normal `lib/main.dart` release app was installed and launched
as `com.plangora.tuner`, build 6. The diagnostic entry point is no longer
installed. Saved data was preserved. All 66 automated tests pass after restoring
the production sources. The compact device evidence is retained in
[`metronome-startup-device-evidence.json`](metronome-startup-device-evidence.json).
Raw local logs are `/tmp/tuner-phone-{original,fixed}-results.jsonl`; the
temporary harness is `/tmp/tuner_device_probe.dart`.

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
