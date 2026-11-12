"""Run once, from inside aa2026_mobile, AFTER `flutter create` (see README).
Adds the Android permissions AutoAssist needs and names the app."""
import pathlib
import re
import sys

path = pathlib.Path("android/app/src/main/AndroidManifest.xml")
if not path.exists():
    print("Cannot find", path)
    print("Run the 'flutter create' command from the README first, from inside this folder.")
    sys.exit(1)

text = path.read_text(encoding="utf-8")
if "ACCESS_FINE_LOCATION" in text:
    print("Manifest already patched - nothing to do.")
    sys.exit(0)

permissions = (
    '    <uses-permission android:name="android.permission.INTERNET"/>\n'
    '    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\n'
    '    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>\n'
)
intents = (
    '        <intent>\n'
    '            <action android:name="android.intent.action.VIEW"/>\n'
    '            <data android:scheme="tel"/>\n'
    '        </intent>\n'
    '        <intent>\n'
    '            <action android:name="android.intent.action.VIEW"/>\n'
    '            <data android:scheme="https"/>\n'
    '        </intent>\n'
)

if "<queries>" in text:
    text = text.replace("<queries>", "<queries>\n" + intents, 1)
    text = text.replace("<application", permissions + "    <application", 1)
else:
    text = text.replace("<application", permissions + "    <queries>\n" + intents + "    </queries>\n    <application", 1)

text = re.sub(r'android:label="[^"]*"', 'android:label="AutoAssist"', text, count=1)
text = text.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
path.write_text(text, encoding="utf-8")
print("AndroidManifest.xml patched. You can now run: flutter run  (or)  flutter build apk --release")
