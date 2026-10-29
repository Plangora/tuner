# Changelog

Every version of the app, newest first. A version is named after the
`version:` in `pubspec.yaml` (`<version>+<build>`), and its release tag is
`v<version>+<build>` (see [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md)).
Add features and bug fixes to the top section as they land, under Added,
Changed or Fixed. It is marked **Unreleased** until it is tagged; replace
that marker with the release date, and start a new section when the next
version/build is chosen. Use that version's entries as its release notes.

Historical sections were reconstructed from the existing git tags and
commit history. Their dates are the tagged commits' dates, rather than
verified store publication dates. The original `v1.0.0` tag points to
`1.0.0+2`; later tags include the build number. Versions below follow
release chronology, including the return from `1.0.1+3` to `1.0.0+4`.

## [1.1.0+5] - 2026-10-29

### Added

- A separate metronome screen in the app's dark/neon style, with tempo
  adjustment, tap tempo, beats per bar, subdivisions, a first-beat accent
  and volume control.
- Native metronome playback and system play/pause/stop controls on iOS,
  Android and macOS, including background playback on phones. On iOS,
  starting the metronome can pause other music.
- Saved metronome settings. Opening the app restores the settings without
  starting playback.
- A version-by-version changelog to maintain release notes as features and
  fixes land.

### Changed

- The tuner remains the launch screen, with a metronome shortcut in its
  app bar. Opening the metronome releases the microphone; returning to the
  tuner stops the clicks before restoring microphone capture.
- Metronome Start/Stop controls have larger labels and icons and a minimum
  height of 64 logical pixels.
- Android release builds use the release signing key and produce an app
  bundle for Google Play internal testing.
- Development and CI use Flutter `3.47.8-stable`.

## [1.0.0+4] - 2026-10-09

Tag `v1.0.0+4`, commit `c9d5064`.

### Changed

- The tuner gauge is larger and the tuning-status label is smaller.
- The public version returns to `1.0.0`, with build number 4.
- iOS builds declare that the app uses no non-exempt encryption, avoiding
  the manual export-compliance prompt on TestFlight uploads.

## [1.0.1+3] - 2026-09-18

Tag `v1.0.1+3`, commit `227b1a0`.

### Changed

- Release tags include the full version and build number, so each build
  has its own tag.

### Fixed

- The web release build.

## [1.0.0+2] - 2026-09-17

Original tag `v1.0.0`, commit `d3f376a`.

### Added

- Microphone-based tuning, with detected note, octave, frequency and a
  gauge showing whether the note is sharp, flat or in tune.
- Automatic tuning on launch.
- The dark/neon theme and app icons for iOS, Android and macOS.
- Build and distribution workflows for iOS, Android, macOS and web,
  including TestFlight uploads and web hosting.

### Fixed

- Pitch conversion and recognition of low guitar strings and notes above
  D6, which could previously be reported an octave low.
- Gauge needle alignment and the arc overlapping the note display in
  wide, short layouts.
- Microphone access in the sandboxed macOS app.
- Audio stream cleanup and error handling.
