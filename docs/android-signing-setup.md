# Android App Signing Setup

This guide explains how to create signing keys for Android app distribution via Google Play Store.

## Overview

Android requires all apps to be digitally signed before distribution. The signature proves the authenticity of the app and ties it to your developer account. Unlike iOS certificates, Android uses a self-signed keystore that you create and manage locally.

## Prerequisites

- Java Development Kit (JDK) 11 or higher
- Android SDK (included with Flutter)
- GitHub account with push access to Plangora/tuner

## Step 1: Create a Keystore

A keystore is a file containing your signing key. This key must be **kept secret and secure** — losing it means you can't update your app on Google Play.

### Generate the Keystore

Run this command to create a new signing keystore:

```bash
keytool -genkey -v \
  -keystore ~/android-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias tuner-key

# Follow the prompts:
# Enter keystore password: [create a strong password - write it down!]
# Re-enter password: [repeat]
# What is your first and last name? Plangora
# What is your organizational unit? Tuner Development
# What is your organization? Plangora
# What is your city or locality? [your city]
# What is your state or province? [your state]
# What is your country code? [2-letter code like US]
# Is this correct? yes
# Enter key password for <tuner-key>: [same or different password]
```

**IMPORTANT**: Save the passwords you enter. You'll need them for GitHub Secrets.

## Step 2: Encode Keystore for GitHub

Convert the keystore to base64 so it can be stored in GitHub Secrets:

```bash
base64 ~/android-keystore.jks > ~/android-keystore.jks.b64

# Display the contents (you'll copy this to GitHub)
cat ~/android-keystore.jks.b64
```

Copy the entire output — you'll paste this into GitHub Secrets as `ANDROID_KEYSTORE_B64`.

## Step 3: Extract Key Alias

The `key alias` is the name of the signing key inside the keystore. To list it:

```bash
keytool -list -v -keystore ~/android-keystore.jks

# When prompted, enter the keystore password
# Look for the line: "Alias name: tuner-key"
```

The alias is `tuner-key` (or whatever you set in Step 1).

## Step 4: Add GitHub Secrets

1. Go to [GitHub Repo Settings](https://github.com/Plangora/tuner/settings/secrets/actions)
2. Click **New repository secret**
3. Add these four secrets:

### Secret 1: ANDROID_KEYSTORE_B64
- **Name**: `ANDROID_KEYSTORE_B64`
- **Value**: Paste the entire contents of `android-keystore.jks.b64` from Step 2

### Secret 2: ANDROID_KEYSTORE_PASSWORD
- **Name**: `ANDROID_KEYSTORE_PASSWORD`
- **Value**: The keystore password from Step 1

### Secret 3: ANDROID_KEY_ALIAS
- **Name**: `ANDROID_KEY_ALIAS`
- **Value**: `tuner-key` (or whatever you set in Step 1)

### Secret 4: ANDROID_KEY_PASSWORD
- **Name**: `ANDROID_KEY_PASSWORD`
- **Value**: The key password from Step 1 (might be same as keystore password)

## Step 5: Store Keystore Safely

**DO NOT commit the keystore to Git!** It's already in `.gitignore`, but as a backup:

1. Save `~/android-keystore.jks` in a **secure location** (encrypted drive or password manager)
2. **Never** commit it to the repository
3. If you lose it, you **cannot update your app on Google Play** — you'll need a new package ID

## Step 6: Run the Release Workflow

Push a version tag matching `pubspec.yaml`'s `version:` (e.g. `git tag v1.1.0 && git push origin v1.1.0`), or:

1. Go to [GitHub Actions](https://github.com/Plangora/tuner/actions)
2. Select the **Release** workflow
3. Click **Run workflow**

The `release-android` job will build the signed APK and upload it as an artifact.

The APK file can be downloaded after the build completes.

## Step 7: Distribute the APK

### Option A: Direct Distribution

Share the APK directly with testers:
1. Download the APK from GitHub Actions artifacts
2. Email or share the file with testers
3. Testers install via:
   ```bash
   adb install tuner-release.apk
   # OR
   # On Android device: Settings → Install from Unknown Sources → navigate to APK
   ```

### Option B: Google Play Store Distribution (Recommended)

1. Create a **Google Play Developer Account** ($25 one-time fee)
   - Go to [Google Play Console](https://play.google.com/console)
   - Create a new app ("Tuner")
   - Fill in app information

2. **Create Internal Testing Track**
   - Go to Testing → Internal Testing
   - Create a release
   - Upload the APK
   - Invite testers via email
   - Testers install via Google Play app

3. **Release to Production**
   - Fill in store listing (screenshots, description, etc.)
   - Set pricing and distribution countries
   - Submit for review (takes ~24 hours)
   - Once approved, the app is live on Google Play Store

## Optional: Create App Bundle Instead of APK

Google Play prefers App Bundles (`.aab`) over APKs because they reduce download size.

Edit the `Build release APK` step in the `release-android` job of `.github/workflows/release.yml` to run `flutter build appbundle --release` instead of `flutter build apk --release`.

App Bundles can only be distributed via Google Play — they cannot be installed directly on devices.

## Troubleshooting

### Build fails: "Keystore not found"
- Verify `ANDROID_KEYSTORE_B64` secret contains the full base64 content
- Check that the secret was added to the Actions environment

### Build fails: "Invalid keystore password"
- Verify `ANDROID_KEYSTORE_PASSWORD` is exactly what you set (case-sensitive)
- Re-encode the keystore if unsure: `base64 ~/android-keystore.jks > ~/android-keystore.jks.b64`

### Can't install APK on device: "App not installed"
- APK may not be compatible with device architecture (arm64, arm, x86)
- Try building with a different architecture or installing via adb:
  ```bash
  adb install -r tuner-release.apk
  ```

### Want to update the app on Google Play but can't find the keystore
- If you lost the keystore, you **cannot** update the existing app
- You'll need to create a new app with a different package ID
- **Lesson**: Store the keystore file in a secure backup location!

## Keystore Security Best Practices

1. **Backup**: Keep a copy of `android-keystore.jks` in encrypted cloud storage (Google Drive, Dropbox)
2. **Access Control**: Only share the keystore password with authorized team members
3. **Rotation**: Create a new keystore for major version updates (don't need to rotate for minor updates)
4. **Expiration**: The key in this guide has 10000 days validity (~27 years) — no renewal needed during that time

## References

- [Google Play Console - Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Flutter - Android App Signing](https://flutter.dev/docs/deployment/android#signing-the-app)
- [Keytool Documentation](https://docs.oracle.com/javase/10/tools/keytool.htm)
