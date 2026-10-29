# Throwaway metronome feasibility probe

This is Task 1 experiment source, not production app code. Findings and untested requirements are in [the validation record](../metronome-validation.md). The working project is `/private/tmp/tuner-metronome-probe-20261029`.

## Reproduce

Use Flutter 3.47.8 / Dart 3.13.7. Dart source snapshots use `.dart.txt` so the production tuner analyzer does not treat this isolated experiment as application code; `prepare.py` restores their `.dart` filenames. From the repository root:

```sh
flutter create --platforms=ios,android,macos --org com.plangora.spike --project-name metronome_probe /private/tmp/tuner-metronome-probe-recheck
python3 docs/metronome-probe/prepare.py /private/tmp/tuner-metronome-probe-recheck
cd /private/tmp/tuner-metronome-probe-recheck
flutter pub get
flutter test
flutter analyze
flutter run -d macos
```

`prepare.py` copies the pinned manifest/lockfile and probe source into the generated project, removes the template test and applies the documented audio-service platform setup. It never patches production tuner files. For iOS, select your own signing team in the generated Xcode project if required; no credentials are stored here.

## Manual checks

1. Start at 120 BPM: four pulses per bar, accent on beat one.
2. Select 137 BPM: expect an immediate stop/restart of the bar. This is disclosed prototype behavior, not seamless editing.
3. Block Dart for five seconds while playing. Listen/record for gaps; the UI freezing is intentional. A native valid-voice log alone is not a timing measurement.
4. Lock the physical phone and switch to a sheet-music app. Record uninterrupted output and pause from the lock screen / Control Center / Android notification.
5. Resume from system controls; expect a fresh bar. Stop must clear active media state. Do not infer tuner-mode stale-command protection: this standalone probe has no tuner.
6. Verify headphone removal/calls pause without automatic resume; test speaker, wired/USB and Bluetooth routes.

Measure onset spacing externally, including loop seams, with calibrated recording-clock error. Run the full device/endurance matrix from the plan before accepting the package. No Android device was connected during initial preparation.

## Deliberate limits

No mic, tuner navigation, saved settings, tap tempo, subdivisions, visual beat or production abstraction. The initial iOS mixing configuration failed to show lock-screen / Control Center controls. The current trial uses non-mixing iOS playback to meet Now Playing eligibility; this can interrupt other music. The human confirms the iOS correction restores system controls. Android focus policy still needs device verification. Only the PCM math is unit-tested; actual engine and background behavior require native execution and audible measurements. Xiph codecs are disabled in the current manifest because this probe needs only PCM/WAV.

The debug probe enables `marionette_flutter 0.6.0`. Connect Marionette MCP to the VM service URI printed by `flutter run`. The read-only custom extension `probe.nativeStatus` reports actual voice/device status, and `get_logs` collects probe events. Release builds do not initialize Marionette.

If Flutter reports the stale Homebrew JDK path noted in the validation record, the initial local Android check used this command from the generated project’s `android/` directory, without changing global settings:

```sh
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew assembleDebug
```

The preparation step retains the three dynamically resolved `audio_service` play/pause/stop drawable resources. The first Samsung release run failed because resource shrinking removed these icons even though debug controls worked. Validate actual release APK resources and on-device system controls; a successful build alone does not catch this failure.

The human confirmed corrected Samsung release background playback and notification pause/resume work. This closes the basic Android functional smoke check, not calibrated timing or the broader endurance/device matrix.
