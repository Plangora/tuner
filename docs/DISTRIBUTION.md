# Tuner App: Multi-Platform Distribution Guide

This guide covers distributing the Tuner app across iOS, Android, macOS, and web platforms.

## Platform Status

| Platform | Status | Distribution | Setup Doc |
|----------|--------|--------------|-----------|
| **iOS** | ✅ Ready | App Store | `ios-signing-setup.md` |
| **Android** | ✅ Ready | Google Play Store | `android-signing-setup.md` |
| **macOS** | ✅ Ready | Direct download (DMG) | Built-in workflow |
| **Web** | ⚠️ Not optimized | GitHub Pages | (Future) |
| **Windows** | ⚠️ Not optimized | Direct download | (Future) |
| **Linux** | ⚠️ Not optimized | Package managers | (Future) |

## Quick Start

### iOS → App Store
1. Get your **Apple Developer Team ID**
2. Follow `docs/ios-signing-setup.md` (Steps 1-6)
3. Add GitHub Secrets (P12_FILE, P12_PASSWORD, PROVISIONING_PROFILE)
4. Push a version tag to trigger the **Release** workflow's `release-ios` job
5. Upload `.ipa` to App Store Connect (or let the workflow do it via TestFlight)

**Timeline:** 30 minutes setup + 15 minutes build + 1-3 days review

### Android → Google Play
1. Create **Android signing keystore**
2. Follow `docs/android-signing-setup.md` (Steps 1-5)
3. Add GitHub Secrets (ANDROID_KEYSTORE_B64, passwords, PLAY_SERVICE_ACCOUNT_JSON)
4. Push a version tag to trigger the **Release** workflow's `release-android` job
5. The job uploads the app bundle to the internal testing track as a draft; promote it to production in Google Play Console

**Timeline:** 20 minutes setup + 10 minutes build + 24 hours review

### macOS → Direct Distribution
1. Push a version tag (or run the **Release** workflow manually) to trigger the `release-macos` job
2. Download `.dmg` file from artifacts
3. Share with users or host on GitHub Releases
4. Users mount DMG and drag app to Applications

**Timeline:** 5 minutes to build, instant distribution

## Automated Workflows

CI lives in two workflows under `.github/workflows/`:

- **`ci.yml`** — runs `flutter analyze` and `flutter test` on every push to `master`/`main` and on pull requests. No builds.
- **`release.yml`** — fires on a version tag push (`v1.1.0+5`, matching `pubspec.yaml`'s full `version:`) or manual dispatch. Verifies the tag matches `pubspec.yaml`, re-runs analyze/test, then builds each platform in its own job.

### Build Triggers

The release workflow can be triggered:
- **Manually**: Actions tab → "Release" → "Run workflow"
- **Automatically**: Push a version tag matching `pubspec.yaml`'s `version:` exactly, build number included (e.g., `git tag v1.1.0+5 && git push --tags`)

### Workflow Details

| Job (in `release.yml`) | Output |
|----------|--------|
| `release-ios` | `.ipa` file (App Store / TestFlight) |
| `release-android` | `.aab` app bundle, uploaded to Google Play internal testing as a draft |
| `release-macos` | `.app` bundle + `.dmg` installer |
| `release-web` | Static site, deployed to GitHub Pages |

All outputs are available as **GitHub Actions artifacts** for 30 days.

To restrict a release to particular platforms, add a file named with the full
version/build under `.github/release-targets/`, containing a comma-separated
selection of `ios`, `android`, `macos` and/or `web`. Without a file, all four
platforms run as before. Build `1.1.0+6` selects only `ios` for TestFlight;
Android upload, macOS distribution and public web deployment are skipped.
Build `1.1.0+7` selects `ios,android`: TestFlight upload and a Google Play
internal-testing draft. It does not select public App Store/Play production
rollout, macOS distribution or public web deployment.
Build `1.1.0+8` selects the same platforms for this beta update; after the
internal draft is uploaded, promote it to the existing closed Alpha track and
the `tuner-alpha` tester list. Do not promote it to open testing or production.

## Version Management

Update version in **one place**:

Edit `pubspec.yaml`:
```yaml
version: 1.1.0+5
```

- `1.1.0` = public version (shown to users)
- `5` = build number (internal, increments each build)

The release tag must include both, e.g. `v1.1.0+5` — TestFlight and Play Console both reject a re-upload of a build number that's already been used, so a tag without the build number would collide the next time only the build bumps.

### iOS & Android App Store Requirements

- **Public version** must match across platforms
- **Build number** can differ (iOS uses CFBundleVersion, Android uses versionCode)
- Both platforms increment on each release

## Recommended Release Workflow

1. **Update code** and test locally. Add each feature, bug fix and user-visible change to the top Unreleased section in [CHANGELOG.md](../CHANGELOG.md) as it lands.
2. **Set the version** in pubspec.yaml (e.g., 1.1.0+5) and make sure the changelog section matches it. Review the entries against changes since the previous tag and replace Unreleased with the release date before tagging.
3. **Commit and tag**: 
   ```bash
   git tag v1.1.0+5
   git push origin --tags
   ```
4. **Workflows trigger automatically** on tag push
5. **Review builds** in GitHub Actions artifacts
6. **Submit to stores**:
   - iOS: Use Xcode or App Store Connect
   - Android: Promote the uploaded draft to production in Google Play Console
   - macOS: Release on GitHub Releases

Use the matching version's changelog entries for GitHub release notes,
TestFlight notes and store release notes, adjusting length or wording for
each destination. The changelog is the source of truth; the current workflow
does not publish release notes automatically. Start a new Unreleased section
when choosing the next version/build, preserving previous release entries.

## Store Listings & Metadata

### iOS App Store

Required:
- App name: "Tuner"
- Screenshots (at least 2 per device size)
- Description (max 170 chars)
- Keywords (relevant search terms)
- Support URL
- Privacy Policy URL

Set in **App Store Connect** → App Information → Localization

### Android Google Play

Required:
- App title
- Short description (80 chars max)
- Full description (4000 chars max)
- Screenshots (at least 2)
- Feature graphic (1024×500)
- Category
- Content rating
- Privacy policy

Set in **Google Play Console** → App content

### macOS (Direct Distribution)

No official storefront setup needed. If hosting on GitHub:
1. Create Release in GitHub
2. Upload `.dmg` file
3. Add release notes
4. Users download and run

## Monitoring & Updates

### Analytics

- **iOS**: App Store Connect → Analytics
- **Android**: Google Play Console → Analytics
- **macOS**: No official analytics (add custom tracking if needed)

### User Feedback

- **iOS**: App Store reviews and ratings
- **Android**: Google Play reviews and ratings
- **Direct**: Collect via GitHub issues or email

## Troubleshooting Build Failures

### iOS Build Fails
- Check: Certificate hasn't expired (valid for 1 year)
- Check: Provisioning profile matches bundle ID

### Android Build Fails
- Check: Keystore file is base64 encoded correctly
- Check: Passwords stored in GitHub Secrets exactly as set
- Check: No spaces or extra characters in secrets
- Check: Build number in `pubspec.yaml` is higher than the last one uploaded to Google Play
- Check: The Play service account still has access to Tuner (see `android-signing-setup.md`, Step 5)

### macOS Build Fails
- Check: Flutter SDK version matches in workflow
- Check: Xcode is up to date (`xcode-select --install`)

## Future Improvements

- [ ] Web build (responsive design for browser)
- [ ] Windows build (UWP or Win32)
- [ ] Linux build (Snap or AppImage)
- [ ] Version auto-update mechanism
- [ ] Crash reporting & analytics

## Resources

- [Flutter Deployment Guide](https://flutter.dev/docs/deployment)
- [iOS App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Policies](https://play.google.com/about/developer-content-policy/)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

## Metronome development and validation

Use the project-local asdf pin, Flutter `3.47.8-stable` (`asdf exec flutter --version`). Test CI matches 3.47.8; keep release workflow changes coordinated with that toolchain.

The tuner remains the launch screen. Its app-bar timer action opens the separate metronome. Returning stops clicks before restoring the microphone. Settings persist; audible playback never restores automatically. Tempo/pattern changes restart the bar, while volume changes apply without restarting.

Native metronome playback is enabled on iOS, Android and macOS. iOS uses mixing
sessions for both tuner capture and metronome playback, with native background
audio and in-app transport controls. It does not initialize a system media
handler, leaving Now Playing metadata and commands to the user's music app.
Android retains system transport controls and its required media-playback
foreground service/media receiver, plus the dynamically resolved play/pause/stop
drawables in `res/raw/metronome_keep.xml`; verify those resources in shrunk
release APKs. macOS retains its system controls. No battery-optimization exemption
is requested. Web/Windows/Linux retain tuner access and show explicit metronome
unavailability; Windows/Linux native builds still require their own checks.

The audio buffer is generated locally and repeats natively, with no per-beat Dart calls. Optional external Xiph libraries are disabled through the SoLoud build hook. Native component notices are bundled in `assets/licenses/metronome-audio.txt` and registered with Flutter's license registry.

See [metronome-validation.md](metronome-validation.md) for exact checks, device findings, the local JDK workaround and remaining calibrated-timing, phone-route/interruption and endurance checks. Passing development checks is not a claim that the full release device matrix has been completed.
