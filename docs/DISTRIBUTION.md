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
2. Follow `docs/android-signing-setup.md` (Steps 1-4)
3. Add GitHub Secrets (ANDROID_KEYSTORE_B64, passwords)
4. Push a version tag to trigger the **Release** workflow's `release-android` job
5. Upload APK to Google Play Console

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
- **`release.yml`** — fires on a version tag push (`v1.2.0`, matching `pubspec.yaml`'s `version:`) or manual dispatch. Verifies the tag matches `pubspec.yaml`, re-runs analyze/test, then builds each platform in its own job.

### Build Triggers

The release workflow can be triggered:
- **Manually**: Actions tab → "Release" → "Run workflow"
- **Automatically**: Push a version tag matching `pubspec.yaml`'s `version:` exactly, build number included (e.g., `git tag v1.1.0+5 && git push --tags`)

### Workflow Details

| Job (in `release.yml`) | Output |
|----------|--------|
| `release-ios` | `.ipa` file (App Store / TestFlight) |
| `release-android` | `.apk` file (Google Play or direct) |
| `release-macos` | `.app` bundle + `.dmg` installer |
| `release-web` | Static site, deployed to GitHub Pages |

All outputs are available as **GitHub Actions artifacts** for 30 days.

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

1. **Update code** and test locally
2. **Bump version** in pubspec.yaml (e.g., 1.0.0+2 → 1.1.0+5)
3. **Commit and tag**: 
   ```bash
   git tag v1.1.0+5
   git push origin --tags
   ```
4. **Workflows trigger automatically** on tag push
5. **Review builds** in GitHub Actions artifacts
6. **Submit to stores**:
   - iOS: Use Xcode or App Store Connect
   - Android: Use Google Play Console
   - macOS: Release on GitHub Releases

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

### macOS Build Fails
- Check: Flutter SDK version matches in workflow
- Check: Xcode is up to date (`xcode-select --install`)

## Future Improvements

- [ ] Web build (responsive design for browser)
- [ ] Windows build (UWP or Win32)
- [ ] Linux build (Snap or AppImage)
- [ ] Automatic play store upload (App Store Connect API)
- [ ] Version auto-update mechanism
- [ ] Crash reporting & analytics
- [ ] Beta testing tracks (TestFlight, Google Play internal testing)

## Resources

- [Flutter Deployment Guide](https://flutter.dev/docs/deployment)
- [iOS App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Policies](https://play.google.com/about/developer-content-policy/)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
