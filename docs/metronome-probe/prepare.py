"""Configure an existing, generated THROWAWAY metronome_probe project."""

import shutil
import sys
from pathlib import Path


source = Path(__file__).resolve().parent
target = Path(sys.argv[1]).resolve()
if source.is_relative_to(target) or target.is_relative_to(source):
    raise SystemExit("Choose a separate generated project outside this source directory.")
manifest = target / "pubspec.yaml"
if not manifest.exists() or "name: metronome_probe\n" not in manifest.read_text():
    raise SystemExit("Expected a generated project named metronome_probe.")
if (target / "lib/services/audio_service.dart").exists():
    raise SystemExit("Refusing to modify the production tuner.")

for relative in (
    "pubspec.yaml", "pubspec.lock", "lib/main.dart", "lib/rhythm.dart",
    "test/rhythm_test.dart",
    "android/app/src/main/res/raw/metronome_keep.xml",
):
    destination = target / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    snapshot = source / (relative + ".txt" if relative.endswith(".dart") else relative)
    shutil.copyfile(snapshot, destination)
(target / "test/widget_test.dart").unlink(missing_ok=True)

manifest = target / "android/app/src/main/AndroidManifest.xml"
text = manifest.read_text()
if "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" not in text:
    text = text.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>''',
    )
    text = text.replace(
        "    </application>",
        '''        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback" android:exported="true" tools:ignore="Instantiatable">
            <intent-filter><action android:name="android.media.browse.MediaBrowserService" /></intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver" android:exported="true" tools:ignore="Instantiatable">
            <intent-filter><action android:name="android.intent.action.MEDIA_BUTTON" /></intent-filter>
        </receiver>
    </application>''',
    )
    manifest.write_text(text)

for activity in (target / "android/app/src/main/kotlin").rglob("MainActivity.kt"):
    activity.write_text(activity.read_text().replace(
        "io.flutter.embedding.android.FlutterActivity",
        "com.ryanheise.audioservice.AudioServiceActivity",
    ).replace("MainActivity : FlutterActivity()", "MainActivity : AudioServiceActivity()"))

plist = target / "ios/Runner/Info.plist"
text = plist.read_text()
if "UIBackgroundModes" not in text:
    plist.write_text(text.replace(
        "<dict>",
        "<dict>\n\t<key>UIBackgroundModes</key><array><string>audio</string></array>",
        1,
    ))
print(f"Throwaway probe prepared at {target}")
