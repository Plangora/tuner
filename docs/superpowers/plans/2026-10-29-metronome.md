# Metronome Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` to implement this plan task by task when the human explicitly starts implementation. Use subagents only if separately requested. Steps use checkbox syntax for tracking.

**Goal:** Add a separate metronome screen to Plangora Tuner with reliable playback while the phone is locked or another app displays sheet music.

**Architecture:** Keep the tuner as the initial screen. An app-owned transport coordinates microphone capture, the metronome engine, and audio-session policy; widgets issue commands and observe state. Native audio playback owns beat spacing, while a separate background-audio handler owns system controls and lifecycle.

**Tech stack:** asdf Flutter `3.47.8-stable`; existing `record`/`audio_session`, selected `flutter_soloud 5.2.2` plus `audio_service 0.18.19`, and `shared_preferences 2.5.6`. Production integration is implemented after the physical iPhone/Samsung feasibility gate. See `docs/metronome-validation.md` for evidence and remaining release checks.

**Spec:** This reviewed plan and the conversation are the design brief. After both phone probes passed, the human explicitly authorized production feature implementation using the existing style and asdf Flutter `3.47.8-stable`. The later UI direction requires larger Start/Stop touch controls and prioritizes iOS/Android appearance; macOS is acceptable for initial functional verification. No app-owned native fallback, commit, push, publication, worktree or delegation is authorized.

## Agreed decisions

- Opening the app shows the tuner.
- A button opens a separate metronome screen.
- Metronome playback must continue when the phone locks and when another app is foregrounded, including sheet music apps.
- Use a package-first approach with native audio timing. Consider an app-owned native engine only after presenting package findings and receiving human approval.
- Start with Task 1 as an isolated throwaway feasibility probe; report package and device findings before production integration.
- Returning to tuner stops playback and clears system resumability. System Play is accepted only while in metronome mode, including when backgrounded. Pause/resume starts a fresh bar on beat one.

## Implementation defaults

- Stop and release microphone capture before entering metronome mode. Stop the metronome before returning to tuner, then restore capture. No simultaneous tuning and audible clicks in the first release. These defaults apply to the authorized implementation.
- Add a visible Metronome button to the tuner app bar, also available when microphone access is denied. Use an app-bar back action on the metronome screen.
- MVP: BPM display with minus/plus and slider or numeric input; tap tempo; beats per bar with first-beat accent; straight subdivisions; volume; start/stop; visual current beat; saved settings. The implemented controls use the existing theme; Start/Stop has a minimum 64-pixel height with larger text and icons.
- Implemented values: 40–240 BPM, default 120; 1–12 beats per bar, default 4; subdivisions 1/2/3/4 equal pulses per beat, default 1; volume 50%. Tap uses up to the latest five valid intervals and resets after a three-second gap.
- Label beats per bar plainly; this is not a complete musical time-signature editor. No swing, polyrhythms, setlists, tempo ramps, training modes, haptics or accounts in the proposed MVP.
- Tempo/pattern edits restart on beat one, matching the accepted spike behavior and the visible UI explanation. Volume-only edits do not restart the loop.
- Default interruptions/focus loss to pause, and require explicit resume after calls or headphone removal. Never emit a burst of missed clicks. Decide whether other music should mix with clicks; original proposed default was mixing, without ducking other music. The initial iPhone probe played in the background but exposed no system controls; Apple requires a non-mixable session for Now Playing eligibility. The human confirms non-mixing playback restores the controls. Recommend non-mixing iOS playback when system controls are required; it can pause other music. This is the selected iOS implementation policy after the successful device retest and implementation go-ahead; Android retains the tested transient-may-duck focus configuration.
- System controls expose start/resume and pause/stop with BPM metadata; no seek or track-skip controls. Returning to tuner stops and clears active playback state.
- Restore settings after relaunch, never automatically restore audible playback. OS process death, force-stop and device reboot do not imply automatic restart.

## Global constraints and existing architecture

- Repository: `/Users/allen/Documents/clients/suey/tuner`; Android ID `com.plangora.tuner`. Do not confuse with CauseBeacon.
- Preserve existing platforms: distribution docs prioritize iOS, Android and macOS; web/Windows/Linux exist but are marked not optimized. Do not silently remove targets or introduce an unconditional unsupported-plugin startup crash.
- Before this feature, `TunerScreen` owned `AudioService`. The app-owned `PracticeController` now owns capture/playback/session policy; tuner widgets retain local pitch presentation state.
- `lib/services/audio_service.dart` captures mono PCM16 at requested 44,100 Hz with `record`; `lib/services/pitch_detector.dart` synchronously analyzes it in Dart. Preserve pitch behavior; do not rewrite the detector for this feature.
- App config declares iOS recording mode, but locked `record_ios` manages the shared session and may replace it with play-and-record. Coordinate ownership explicitly when changing modes.
- Use the implemented small `ChangeNotifier` controller and settings repository; no state-management framework was added.
- Do not make `Timer.periodic`, widget rebuilds, tick callbacks, animation frames, or Dart isolate wakeups authoritative for audio onset. A native loop must continue even if UI callbacks cease.
- Playback must not be disposed merely because its screen loses focus or the app becomes inactive. Flutter inactive/paused lifecycle states are distinct from an audio interruption.
- Implementation toolchain: `.tool-versions` pins Flutter `3.47.8-stable` (Dart 3.13.7). Test CI uses 3.47.8; the human’s release workflow already uses 3.47.8 and was preserved. iOS deployment target remains 15.0 and macOS 12.0. Android SDK values inherit Flutter defaults.
- Existing unrelated deletion `.claude/scheduled_tasks.lock` and modification `.github/workflows/release.yml` must be preserved and excluded from feature changes.
- User preference: GPT-6.1 Sol for planning/review; Luna only for later explicitly approved implementation. Do not switch models or delegate automatically.

## Package decision gate

Research snapshot: 2026-10-29. Read the actual resolved release source before implementation; repository branches and published releases can differ. The isolated spike has resolved dependencies, passed three native builds and macOS transport-state smoke checks, and launched a signed release probe on the physical iPhone. The human confirms audible playback continues through iPhone screen lock and app switching; the non-mixing correction restored iPhone system controls by human confirmation. Samsung Android debug transport and system media commands pass; release testing exposed stripped control icons; a narrow resource-keep correction passes actual APK checks and restores accepted media-session state. The human confirms corrected Android release background playback and notification pause/resume work. Basic iPhone/Samsung feasibility checks pass; measured timing and the broader release matrix remain open. See `docs/metronome-validation.md`; do not infer timing or background reliability from build success.

| Candidate | Verified basis | Decision risk |
| --- | --- | --- |
| `flutter_soloud` 5.2.2 + `audio_service` 0.18.19 | Native SoLoud/miniaudio; iOS/Android/macOS; engine-time scheduling and gapless looping. Wrapper MIT; core zlib/libpng. Recent scheduling and lifecycle fixes. | Preferred first evaluation. A native repeating PCM rhythm avoids indefinite Dart replenishment. Its metronome example still submits ticks from Dart timers and must not be copied as the final scheduler. Verify loop boundaries, latency, power and background integration. |
| `metronome` 2.0.13 + `audio_service` | BSD-3-Clause; iOS/Android/macOS. Apple source loops a generated PCM bar through AVAudioPlayerNode; Android writes generated bars to AudioTrack on a native thread. | Smaller feature fit. Reviewed Apple source restarts for tempo/signature edits and uses a separate timer for visual tick events. Verify Android buffering and rapid transport changes. Background service/media controls remain separate. |
| `just_audio` 0.10.6 + `audio_service` | Apache-2.0/MIT; iOS/Android/macOS; native media playback, loops and gapless playlists. | Consider a generated PCM rhythm file only. General gapless playlist support does not prove precise short-loop seams or seamless tempo edits. Do not call play once per beat. |

`audio_service` is the lifecycle/media-controls layer, not the beat engine. Its current matrix supports Android, iOS and macOS background playback and media controls; macOS lock-screen controls are not listed. Do not layer a second competing background-control package on top.

Current Dart/Flutter and Apple target floors appear compatible. Current `audio_service` and `just_audio` ranges permit locked `audio_session` 0.1.25, so upgrading it is not automatically necessary. The isolated SoLoud/audio_service spike now verifies dependency compatibility and native builds on all three shipping targets; full tuner integration, CI toolchain reproduction and older-OS runtime behavior remain unverified. Android built through a command-local JDK workaround documented in the validation record. Retain license notices, and audit bundled native codecs in the selected release; use simple local PCM/WAV clicks rather than unnecessary codec features.

### Task 1: Approve scope and evaluate one package path

**Files:** Read `pubspec.yaml`, `pubspec.lock`, `lib/main.dart`, `lib/screens/tuner_screen.dart`, `lib/services/audio_service.dart`, native platform configuration and this plan. After authorization, create `docs/metronome-validation.md` for findings; temporary feasibility code should stay isolated and not become production by accident.

- [x] Scope/defaults accepted by the production implementation go-ahead after the findings were presented; use the tested restart and iOS non-mixing behavior.
- [x] Obtain explicit authorization for the feasibility spike/dependency changes. Pin evaluated versions; inspect release source, package constraints and licenses. Begin with SoLoud/native looping plus audio_service.
- [x] Build the smallest approved probe: one accented native loop, start/stop, live BPM change, audio_service handler and background configuration. No full UI or persistence yet.
- [x] Verify lock/app switching and system pause on real iOS and Android. Check macOS engine/service registration and document platform differences. Human-confirmed iPhone and Samsung release background/system-control checks pass; macOS transport-state checks pass. See `docs/metronome-validation.md` for limits and required release follow-up.
- [ ] Record exact devices, OS/package versions, audio routes, measurement method, failures and restart semantics in `docs/metronome-validation.md`. Preliminary source/build/macOS-state evidence is recorded; physical playback measurements remain outstanding.
- [x] Present findings and package recommendation before committing to production integration. If a package fails, explain whether another listed package can address the failure. Stop for human approval before writing an app-owned native engine.

**Acceptance:** Selected path demonstrably keeps audible rhythm running without per-beat Dart calls, and system controls stop it while UI is absent. Evidence is explicit about failures and untested cases. No claim of sample accuracy rests only on marketing or UI timestamps.

## Planned file boundaries and contracts

These are proposed production files after the gate. Keep package-specific types inside the adapter; adjust paths only when a concrete repository constraint warrants it.

| File | Responsibility |
| --- | --- |
| `lib/models/metronome_settings.dart` | Immutable BPM, beats-per-bar, subdivision and volume; validated serialization and defaults. |
| `lib/models/metronome_state.dart` | Transport status, settings, optional visual phase and user-facing failure. |
| `lib/services/metronome_engine.dart` | Small package-neutral timing contract and engine capabilities. |
| `lib/services/soloud_metronome_engine.dart` | Selected engine adapter; replace name if another package wins. Native rhythm loop construction/loading, playback and resource ownership. |
| `lib/services/practice_controller.dart` | App-level mode transitions, transport commands and observable state. |
| `lib/services/practice_audio_handler.dart` | audio_service adapter; system commands invoke the same controller operations as UI. |
| `lib/services/audio_session_coordinator.dart` | Capture/playback session configuration, focus/interruption and route-event policy. |
| `lib/services/metronome_settings_repository.dart` | Load/save settings; never persist playing state. |
| `lib/screens/metronome_screen.dart` | Accessible controls and presentation; no direct engine ownership. |

Suggested engine contract to stabilize in Task 2:

```dart
abstract interface class MetronomeEngine {
  Stream<MetronomeEngineStatus> get status; // Includes asynchronous failures.
  Future<void> initialize();
  Future<void> start(MetronomeSettings settings);
  Future<void> updateSettings(MetronomeSettings settings);
  Future<void> stop();
  Future<void> dispose();
}
```

Controller commands: `Future<void> enterMetronome()`, `enterTuner()`, `start()`, `stop()`, and `updateSettings(MetronomeSettings settings)`. Expose `MetronomeState get state` through `ChangeNotifier`; inject engine, capture, session and persistence dependencies for tests. System controls and UI share this instance. Define `MetronomeEngineStatus` during the spike with stopped/playing/error reporting, including asynchronous playback failure. Engine adapters must surface detectable failures and reconcile playback state on foreground/route changes; document native failures they cannot observe. Clock/phase events remain capability-dependent; do not invent an authoritative timestamp from a Dart callback.

### Task 2: Implement transport, native rhythm and session ownership

**Files:** Create engine/settings/state/controller/session files above. Modify `lib/services/audio_service.dart` only to support controlled, reusable start/stop/disposal and observable capture errors. Update `pubspec.yaml`/`pubspec.lock` for approved packages. Tests: `test/services/practice_controller_test.dart`, `test/services/metronome_engine_test.dart`.

- [x] First add failing controller tests with fake engine/capture/session implementations: entering metronome waits for capture stop; returning waits for playback stop; double start is serialized; opening metronome during pending mic permission/initialization/start invalidates late capture completion; capture-stop failure prevents playback; stale system Play while in tuner is ignored; failed engine start reports stopped/error; interrupted playback does not silently appear playing.
- [x] Run `flutter test test/services/practice_controller_test.dart` and confirm the intended failure; implement the minimum controller behavior and rerun.
- [x] Implement the selected adapter with short preloaded local clicks and rhythm spacing in sample frames. Include accent/subdivision behavior approved in Task 1. Use fractional frame accumulation where needed to avoid systematic tempo bias; confirm loop padding is silent and clicks do not truncate or overlap unexpectedly.
- [x] Define tempo/pattern edit behavior from the evaluated engine: cancel old future events or replace loop at the approved boundary without duplicate clicks. Stop must cancel queued playback and prevent later callbacks from restarting it.
- [x] Configure playback-only policy in metronome mode and restore the recorder policy before tuning. Await capture shutdown; handle rapid navigation and disposal safely. Preserve pitch-detection behavior.
- [x] Test settings-to-rhythm math with known frame positions, accent placement, rounding over long patterns, and rejected invalid input. Use rendered audio/device measurements for actual engine timing rather than mocking it into correctness.

**Acceptance:** Capture and clicks do not compete; rapid commands have deterministic final state; no stale callbacks restart audio; playback timing survives delayed UI work. Initialization/route errors produce a recoverable state. No new state framework or pitch-detector rewrite.

### Task 3: Add background service, interruptions and system controls

**Files:** Create `lib/services/practice_audio_handler.dart`; update `lib/main.dart`, `lib/services/audio_session_coordinator.dart`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/plangora/tuner/MainActivity.kt`, `ios/Runner/Info.plist`. Change `macos/Runner` configuration only if the selected release requires it. Tests: `test/services/practice_audio_handler_test.dart`.

- [x] First test that handler play/pause/stop invokes the same transport used by UI, and that error/interruption state updates system playback state and UI consistently.
- [x] Initialize one app-owned handler/controller before use. Prevent duplicate engine ownership and dispose only at the appropriate app/service boundary.
- [x] Follow the resolved audio_service Android setup: foreground media-playback service, media-button receiver, wake-lock/foreground-service permissions and SDK-appropriate media-playback permission; integrate MainActivity with the shared engine. Publish a clear Metronome notification and BPM metadata while active. The Samsung release probe demonstrated that shrinking can strip dynamically looked-up default control icons; preserve `audio_service_stop`, `audio_service_pause` and `audio_service_play_arrow` with a narrow `tools:keep` resource rule and verify the built release APK. Test pause/resume against foreground-service restrictions; do not request battery-optimization exemption as an automatic workaround.
- [x] Enable iOS audio background mode and the approved playback session. Audio must continue as actual native playback during normal inter-beat silence, without idle Dart timers keeping the process alive.
- [x] Implement approved call/focus/headphone-removal behavior. On routing changes, refresh/recover format and timing state or stop with a clear recoverable error. Honor OS resume permission and explicit user intent; never catch up missed beats.
- [x] Verify macOS continued playback while another app is active. Document that full computer sleep is outside the phone-lock requirement; do not promise playback during system sleep or add sleep-prevention behavior silently.
- [ ] Exercise controls from notification, iOS Control Center/lock screen and headset with UI backgrounded. Check that returning to tuner clears active playback and does not leave a foreground service or notification falsely playing.

**Acceptance:** Locking or switching apps does not stop active clicks. System controls work without the metronome widget active. Audio focus and route failures cannot leave a false playing state. No restart after process death/force-stop is promised.

### Task 4: Add navigation and the metronome screen

**Files:** Modify `lib/main.dart`, `lib/screens/tuner_screen.dart`; create `lib/screens/metronome_screen.dart`. Reuse `lib/theme/app_theme.dart`. Tests: `test/screens/metronome_screen_test.dart`, `test/screens/practice_navigation_test.dart`.

- [x] First test launch remains tuner, the Metronome action exists in normal and microphone-denied states, and back/system navigation performs the stop-before-capture transition.
- [x] Move audio ownership out of TunerScreen into the controller; keep the UI using local presentation state where useful. Wire the action even if tuner initialization failed. Handle permission denial without requiring permission for metronome playback; do not re-request microphone merely because the metronome opens.
- [x] Implement the approved BPM/tap/pattern/volume/start-stop controls and visible beat using existing dark theme. Visual phase follows engine position where available and resynchronizes on foregrounding. Drop stale visual events instead of replaying them.
- [x] Add labels, large touch targets, keyboard/desktop controls where appropriate, scalable text and reduced-motion-friendly indicators. Do not communicate beat/accent or playback errors by color alone.
- [x] On unsupported platforms, avoid plugin initialization crashes and provide an explicit capability state. Preserve existing tuner access; document any approved feature limitation.

**Acceptance:** Users can reach a working metronome after denying mic access; initial app screen stays tuner; controls reflect service state after lock/unlock and navigation; repeated navigation does not leak recorders or engines.

### Task 5: Persist settings and complete verification

**Files:** Create `lib/services/metronome_settings_repository.dart`; update `pubspec.yaml`/`pubspec.lock` for an approved small preferences package if needed. Tests: `test/models/metronome_settings_test.dart`, `test/services/metronome_settings_repository_test.dart`. Update `docs/metronome-validation.md` and `docs/DISTRIBUTION.md` with verified setup/platform differences.

- [x] First test settings round-trip, absent/corrupt/out-of-range saved data falling back safely, and persisted settings never causing auto-play. Implement versioned serialization and nonblocking writes after user edits, not per beat.
- [x] Test tap tempo with injected timestamps: consistent intervals, isolated accidental taps, gap reset and range limits using the values approved in Task 1.
- [x] Run focused tests while implementing, then `flutter analyze` and `flutter test`. Resolve failures related to this change; report unrelated existing failures without hiding them.
- [ ] Build each shipping target with the project's supported toolchain and run the device matrix below. Simulator/emulator results supplement rather than replace physical phone testing.
- [x] Record evidence, outstanding defects and supported behavior. Re-review mic/session transitions and service ownership after the final dependency versions are resolved. Obtain human approval for any deviation, native fallback, commit or release not already authorized.

## Proposed device validation and timing targets

These are initial acceptance targets for human review, not guarantees or measured results. Fix the test method and thresholds before using them as release gates. Measure audible output/onsets with an external recorder or loopback and analyze sample positions; callback timestamps alone do not measure speaker/Bluetooth output.

- Proposed baseline: speaker/wired steady-state inter-onset error no more than 2 ms for 99% of measured pulses, no missed/double pulse, and cumulative phase error under 10 ms across ten minutes after initial output latency is removed. Report tempo bias against requested BPM separately from interval jitter against the fitted pulse period. Ten minutes / 10 ms is about 16.7 ppm: calibrate external recording-clock error or mark absolute drift inconclusive. Removing initial latency must not also remove tempo bias. Include loop seams in the onset analysis. Reassess thresholds with device evidence rather than silently loosening them.
- Test slow/default/fast approved tempos, awkward fractional-frame tempos, every approved subdivision/accent pattern, 100 rapid start/stop cycles and repeated BPM/pattern changes. Include a 30-minute screen-off/other-app endurance run and heavy UI work.
- Physical matrix: at least one recent iPhone, one older supported iPhone if available, and two Android vendors including one with aggressive background management. Record exact OS/model/build versions. Add macOS supported-target smoke testing and existing web/desktop startup checks.
- Routes: built-in speaker, wired/USB where available, Bluetooth headphones; connect/disconnect mid-playback. Verify no unexpected microphone/Bluetooth hands-free route activation in metronome mode. Bluetooth may have substantial variable output latency; assess spacing and audiovisual offset separately and do not apply a universal fixed correction.
- Interruptions: incoming/answered calls, alarms/navigation speech, other media gaining focus, headphone removal, lock/unlock, switching to sheet music, screen rotation and app return. Validate the approved pause/resume/mixing policy and coherent service/UI state.
- Permissions/errors: deny microphone on first launch and still enter metronome; grant it later for tuner; simulate engine start failure and settings corruption. Stop from system controls while the screen is absent; return to tuner and verify exclusive capture.
- Battery: compare a representative background session at low/default/high approved BPM with the tuner closed and no unnecessary UI polling; record heat, wakeups and underruns where tooling permits. No battery-life promise without measurement.

## Sources and local evidence

- Local entry/UI: `lib/main.dart`, `lib/screens/tuner_screen.dart`, `lib/theme/app_theme.dart`.
- Local capture/pitch: `lib/services/audio_service.dart`, `lib/services/pitch_detector.dart`, `lib/models/note.dart`; tests in `test/widget_test.dart`, `test/pitch_detector_test.dart`, `test/note_test.dart`.
- Local platforms: `docs/DISTRIBUTION.md`, `.github/workflows/ci.yml`, native manifests/project files. Existing tests cover pitch/model/widgets, not real audio timing or background services.
- [SoLoud package and platform/API overview](https://pub.dev/packages/flutter_soloud); [maintenance history](https://pub.dev/packages/flutter_soloud/changelog); [manifest](https://raw.githubusercontent.com/alnitak/flutter_soloud/main/pubspec.yaml); [timer-based example to avoid copying blindly](https://raw.githubusercontent.com/alnitak/flutter_soloud/main/example/lib/metronome/metronome.dart); [core license](https://raw.githubusercontent.com/alnitak/flutter_soloud/main/src/soloud/LICENSE).
- [Dedicated metronome package](https://pub.dev/packages/metronome); [changes](https://pub.dev/packages/metronome/changelog); [Apple engine](https://raw.githubusercontent.com/biner88/metronome/main/darwin/metronome/Sources/metronome/Metronome.swift); [Android engine](https://raw.githubusercontent.com/biner88/metronome/main/android/src/main/java/com/sumsg/metronome/Metronome.java).
- [audio_service background setup and platform matrix](https://pub.dev/packages/audio_service); [manifest/dependency constraints](https://raw.githubusercontent.com/ryanheise/audio_service/minor/audio_service/pubspec.yaml).
- [just_audio playback/platform/license docs](https://pub.dev/packages/just_audio); [manifest/dependency constraints](https://raw.githubusercontent.com/ryanheise/just_audio/minor/just_audio/pubspec.yaml).
- [Apple buffer scheduling](https://developer.apple.com/documentation/avfaudio/avaudioplayernode/schedulebuffer(_:at:options:completionhandler:)); [Android low-latency audio guidance](https://developer.android.com/games/sdk/oboe/low-latency-audio).

## Suggested prompt for later Codex work

> The feature is implemented; do not restart the package spike or rewrite it. Use asdf Flutter `3.47.8-stable`, preserve current styling and 64-pixel Start/Stop controls, and review `docs/metronome-validation.md` for remaining release/device verification. The tuner remains the launch screen and metronome is separate. Complete the integrated physical-phone, route, interruption, endurance and calibrated timing checks without treating builds or unit tests as audible timing proof. Preserve unrelated changes. Do not commit, push, release, create worktrees, switch models or delegate unless authorized.
