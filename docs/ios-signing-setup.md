# iOS App Store Signing Setup

This guide explains how to set up code signing certificates and provisioning profiles for submitting the Flutter Tuner app to the App Store.

## Prerequisites

- Apple Developer Program membership ($99/year) - sign up at [developer.apple.com](https://developer.apple.com)
- Xcode installed on your Mac
- GitHub account with push access to Plangora/tuner

## Step 1: Create a Certificate Signing Request (CSR)

1. Open **Keychain Access** on your Mac (`Applications` → `Utilities` → `Keychain Access`)
2. Go to **Keychain Access** → **Certificate Assistant** → **Request a Certificate from a Certificate Authority**
3. Fill in:
   - **User Email Address**: Your Apple Developer account email
   - **Common Name**: Your name or company name
   - **Request is**: Saved to file
4. Save the file as `CertificateSigningRequest.certSigningRequest`

## Step 2: Create an App ID

1. Go to [Apple Developer - Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Click the **+** button
3. Select **App IDs** and click **Continue**
4. Select **App** and click **Continue**
5. Fill in:
   - **Description**: "Tuner App"
   - **Bundle ID**: `com.plangora.tuner` (exact match required)
6. Under **Capabilities**, select **Microphone** (required for this app)
7. Click **Continue** → **Register**

## Step 3: Create an Apple Distribution Certificate

1. Go to [Apple Developer - Certificates](https://developer.apple.com/account/resources/certificates/list)
2. Click the **+** button
3. Select **Apple Distribution** and click **Continue**
4. Upload your CSR file from Step 1 and click **Continue**
5. Click **Download** to save `aps_distribution.cer`
6. Double-click `aps_distribution.cer` to install it in Keychain
   - The certificate will appear under "Certificates" in Keychain Access
   - It will show as "Apple Distribution: [Your Name]"

## Step 4: Create a Provisioning Profile

1. Go to [Apple Developer - Provisioning Profiles](https://developer.apple.com/account/resources/profiles/list)
2. Click the **+** button
3. Select **App Store** and click **Continue**
4. Select the App ID `com.plangora.tuner` and click **Continue**
5. Select your Apple Distribution certificate and click **Continue**
6. Name it: `Tuner_AppStore` and click **Continue**
7. Click **Download** to save `Tuner_AppStore.mobileprovision`

## Step 5: Export Certificate for GitHub Actions

These steps create base64-encoded versions of your certificates to store in GitHub Secrets.

### Export the .p12 Certificate File

1. Open **Keychain Access**
2. Find your "Apple Distribution" certificate (created in Step 3)
3. Right-click on it → **Export** → Save as `distribution.p12`
4. Set a strong password (you'll need this for GitHub Secrets)
5. Click **Save**

Now encode it to base64:

```bash
# In Terminal, navigate to where you saved distribution.p12
base64 distribution.p12 > distribution.p12.b64

# Print the contents (you'll copy this to GitHub)
cat distribution.p12.b64
```

Save the output text - you'll paste this into GitHub Secrets as `P12_FILE`.

### Encode the Provisioning Profile

```bash
# In Terminal, navigate to where you saved Tuner_AppStore.mobileprovision
base64 Tuner_AppStore.mobileprovision > profile.mobileprovision.b64

# Print the contents (you'll copy this to GitHub)
cat profile.mobileprovision.b64
```

Save the output text - you'll paste this into GitHub Secrets as `PROVISIONING_PROFILE`.

## Step 6: Add GitHub Secrets

1. Go to [GitHub Repo Settings](https://github.com/Plangora/tuner/settings/secrets/actions)
2. Click **New repository secret**
3. Add these three secrets:

### Secret 1: P12_FILE
- **Name**: `P12_FILE`
- **Value**: Paste the entire contents of `distribution.p12.b64` (from Step 5)

### Secret 2: P12_PASSWORD
- **Name**: `P12_PASSWORD`
- **Value**: The password you set when exporting the .p12 certificate in Step 5

### Secret 3: PROVISIONING_PROFILE
- **Name**: `PROVISIONING_PROFILE`
- **Value**: Paste the entire contents of `profile.mobileprovision.b64` (from Step 5)

## Step 7: Update ExportOptions.plist

Edit `ios/ExportOptions.plist` and update:

```xml
<key>teamID</key>
<string>YOUR_TEAM_ID</string>
```

Replace `YOUR_TEAM_ID` with your Apple Developer Team ID:
1. Go to [Apple Developer - Membership](https://developer.apple.com/account/#!/membership)
2. Look for "Team ID" (9-character code like "ABC123DEFG")

## Step 8: Run the Build Workflow

1. Go to [GitHub Actions](https://github.com/Plangora/tuner/actions)
2. Select **Build iOS App** workflow
3. Click **Run workflow** → select build type (testflight or appstore)
4. The build will run and produce a signed `.ipa` file

The `.ipa` file will be available in the workflow artifacts (downloadable after the build completes).

## Step 9: Submit to App Store Connect

### Option A: Manual Submission (Recommended for first build)

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app "Tuner"
3. Go to **TestFlight** (for testing) or **App Store** (for review)
4. Click **+** to add a new build
5. Select the `.ipa` file you downloaded from GitHub Actions
6. Wait for processing (usually 5-10 minutes)
7. Add test notes or release notes
8. Click **Submit for Review** (or **Start Testing** for TestFlight)

### Option B: Automated Submission (Advanced)

Edit `.github/workflows/build-ios.yml` and uncomment the "Upload to TestFlight" section to automatically submit builds to TestFlight.

This requires additional GitHub Secrets:
- `APPLE_ID`: Your Apple ID email
- `APPLE_ID_PASSWORD`: Your App-Specific Password (created in Apple ID settings)

## Troubleshooting

### Build fails: "Certificate not found in Keychain"
- Verify the certificate was imported correctly in Keychain Access
- Check that P12_FILE and P12_PASSWORD secrets are set correctly
- Ensure the .p12 file was base64 encoded properly

### Build fails: "Provisioning profile not found"
- Verify PROVISIONING_PROFILE secret contains the full base64 content
- Check that the profile name in ExportOptions.plist matches the downloaded profile

### Build succeeds but can't download .ipa
- The artifact may have expired (retention is 30 days)
- Re-run the workflow to generate a fresh build

### App Store submission rejected
- Check minimum iOS version requirement (currently 12.0)
- Verify all required screenshots and app description are provided
- Ensure privacy policy URL is valid and accessible

## Certificate Renewal

Apple certificates expire every year. Before expiration:
1. Create a new CSR and certificate following Steps 1-3
2. Create a new provisioning profile following Step 4
3. Export and update GitHub Secrets following Steps 5-6
4. Update ExportOptions.plist if the certificate thumbprint changed

## References

- [Apple Developer - Certificates Documentation](https://developer.apple.com/support/certificates/)
- [Flutter - iOS App Store Deployment](https://flutter.dev/docs/deployment/ios)
- [GitHub Actions - Secrets Management](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
