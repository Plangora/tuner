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
3. Add these five secrets:

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

### Secret 5: PLAY_SERVICE_ACCOUNT_JSON
- **Name**: `PLAY_SERVICE_ACCOUNT_JSON`
- **Value**: The full JSON key file of the Google Play service account (see Step 5)

## Step 5: Give CI Access to Google Play

The `release-android` job uploads the app bundle to Google Play through a service account. Tuner reuses the service account already set up for Love21:

`github-actions-play-publish@love21-play-publish.iam.gserviceaccount.com`

It lives in the `love21-play-publish` Google Cloud project and its JSON key is the value of `PLAY_SERVICE_ACCOUNT_JSON`. The same key is used by the Love21 repository, so rotating it means updating the secret in both.

The service account needs access to Tuner in the Play Console (already granted):

1. Go to [Google Play Console](https://play.google.com/console) → the **Plangora** developer account → **Users and permissions**
2. Open the service account → **App permissions** → **Add app** → Tuner
3. Tick **View app information** and **Release apps to testing tracks**
4. **Apply**, then **Save changes**

It deliberately has no production permission: CI can only upload to testing tracks, and a person promotes a build to production.

## Step 6: Store Keystore Safely

**DO NOT commit the keystore to Git!** It's already in `.gitignore`, but as a backup:

1. Save the keystore in a **secure location** (encrypted drive or password manager)
2. **Never** commit it to the repository
3. For local release builds, point `android/key.properties` (gitignored) at it with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. Without that file, release builds fall back to the debug key.

This keystore is the **upload key**. Google Play holds the actual app signing key (Play App Signing), so a lost upload key can be reset through Play Console support rather than costing you the app.

## Step 7: Run the Release Workflow

Bump `version:` in `pubspec.yaml`, then push a tag matching it exactly, build number included (e.g. `git tag v1.1.0+5 && git push origin v1.1.0+5`). Play rejects a build number that has already been uploaded, so every release needs a new one.

The `release-android` job then:

1. Builds a signed app bundle (`flutter build appbundle --release`)
2. Uploads `app-release.aab` as the `android-release` artifact (kept 30 days)
3. Uploads the bundle to the **internal testing** track on Google Play as a **draft**

## Step 8: Release on Google Play

The upload lands as a draft, so nothing reaches users until you act in the Play Console:

1. **Test and release → Testing → Internal testing**: open the draft release and roll it out to testers
2. **Promote release → Production** (or to closed/open testing first)
3. **Publishing overview → Send changes for review**

Managed publishing is off, so an approved production release goes live automatically.

App bundles can only be distributed through Google Play — they cannot be installed directly on a device.

## Troubleshooting

### Build fails: "Keystore not found"
- Verify `ANDROID_KEYSTORE_B64` secret contains the full base64 content
- Check that the secret was added to the Actions environment

### Build fails: "Invalid keystore password"
- Verify `ANDROID_KEYSTORE_PASSWORD` is exactly what you set (case-sensitive)
- Re-encode the keystore if unsure: `base64 ~/android-keystore.jks > ~/android-keystore.jks.b64`

### Play upload fails: "Version code N has already been used"
- That build number is already on Google Play. Bump the build number in `pubspec.yaml` and push a new tag.

### Play upload fails: "The caller does not have permission"
- Check the service account still has Tuner under **Users and permissions** (Step 5)
- Check `PLAY_SERVICE_ACCOUNT_JSON` holds the whole JSON key file
- Permission changes in the Play Console can take a few hours to reach the API

### Want to update the app on Google Play but can't find the keystore
- The keystore is only the upload key, so the app is not lost
- Ask Play Console support for an upload key reset, then update the four keystore secrets
- **Lesson**: Store the keystore file in a secure backup location!

## Keystore Security Best Practices

1. **Backup**: Keep a copy of `android-keystore.jks` in encrypted cloud storage (Google Drive, Dropbox)
2. **Access Control**: Only share the keystore password with authorized team members
3. **Rotation**: Don't replace the keystore between releases — Google Play rejects uploads signed with a different upload key
4. **Expiration**: The key in this guide has 10000 days validity (~27 years) — no renewal needed during that time

## References

- [Google Play Console - Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Flutter - Android App Signing](https://flutter.dev/docs/deployment/android#signing-the-app)
- [Keytool Documentation](https://docs.oracle.com/javase/10/tools/keytool.htm)
