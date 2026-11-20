# AutoAssist - AI-enabled roadside assistance (prototype)

Two folders:

| Folder | What it is |
|---|---|
| `aa2026_server` | The backend: Python + FastAPI + SQLite. Also talks to the Groq AI. Runs on your laptop. |
| `aa2026_mobile` | The Android app: Flutter. Uses OpenStreetMap (no map key needed). |

The app has three account types: **Driver**, **Mechanic** and **Parts supplier**. Each sees its own screens.

> **Honest note:** this code was written and syntax-checked, but it could not be compiled or run in the
> environment where it was created (no Flutter SDK / internet there). The first `flutter analyze` /
> build on your laptop may show a few small errors. That is normal - copy the message and send it back
> and it will be fixed quickly.

---------------------------------------------------------------------------------------------------

## Part A - Start the server (do this first)

You need **Python 3.10 or newer** (python.org - tick "Add Python to PATH" when installing).

1. Open the `aa2026_server` folder.
2. **Windows:** double-click `run_server.bat`.
   **Mac/Linux:** run `./run_server.sh` in a terminal.
3. The first run creates a file called `.env`. Open it in Notepad, paste your Groq key after
   `GROQ_API_KEY=` and save. (Get a free key at console.groq.com > API Keys.) Run the file again.
4. When you see `Uvicorn running on http://0.0.0.0:8000`, open <http://localhost:8000/health> in your
   browser. You should see `"status":"ok"`. Keep the window open while you use the app.

Manual way (if you prefer commands):

    cd aa2026_server
    python -m venv venv
    venv\Scripts\activate          (Mac/Linux: source venv/bin/activate)
    pip install -r requirements.txt
    copy .env.example .env         (Mac/Linux: cp .env.example .env)   then edit .env
    uvicorn app.main:app --host 0.0.0.0 --port 8000

Good to know
- The database is one file, `autoassist.db`, created automatically with demo data on first start.
  To reset everything, stop the server, delete that file and start again.
- The Groq key stays in `.env` on your laptop. It is never inside the APK.
- Windows may ask to allow Python through the firewall - choose **Private networks** and Allow.
  (Without this the phone cannot reach the server.)
- Handy: <http://localhost:8000/docs> shows every API endpoint and lets you test them.

### Find your laptop's IP address
- Windows: open Command Prompt, type `ipconfig`, look for **IPv4 Address** under your Wi-Fi (e.g. `192.168.1.23`).
- Mac: System Settings > Wi-Fi > Details.

Your phone and laptop must be on the **same Wi-Fi** (or the laptop on your phone's hotspot).
The phone also needs internet for the map tiles, and the laptop needs internet for the AI.

---------------------------------------------------------------------------------------------------

## Part B - Build the app

One-time setup: install **Flutter** (docs.flutter.dev/get-started/install) and **Android Studio**
(it brings the Android SDK). Then run `flutter doctor` and fix anything marked with a red X, and accept
Android licences with `flutter doctor --android-licenses`.

Open a terminal **inside `aa2026_mobile`** and run these one by one:

    flutter create . --project-name aa2026_mobile --org com.autoassist --platforms=android
    python patch_android.py
    flutter pub get
    flutter analyze

- Step 1 adds the Android project files around the code.
  Afterwards check that `lib/main.dart` still mentions `RootGate`. If it was replaced by Flutter's default
  counter app, copy `lib/main.dart` again from the zip.
- Step 2 adds the permissions (internet, location) and allows the plain-http connection to your laptop.
  (On Mac/Linux use `python3`.)
- `flutter analyze` should finish with no errors. Warnings and "info" lines can be ignored.

Add your photos (see `IMAGES.md`), then either:

**Try it on your phone with a cable** (fastest for testing)
1. On the phone: Settings > About phone > tap *Build number* 7 times, then Settings > Developer options >
   turn on **USB debugging**. Plug in the cable and accept the prompt on the phone.
2. `flutter devices` should list your phone. Then run `flutter run`.

**Make an APK to install**

    flutter build apk --release

The file appears at `build/app/outputs/flutter-apk/app-release.apk`. Send it to your phone
(USB / WhatsApp to yourself / Google Drive), open it and allow "install unknown apps" if asked.

---------------------------------------------------------------------------------------------------

## Part C - Use the app

1. Open the app. On the Welcome screen tap the **gear** (top right) and type your server address, e.g.
   `http://192.168.1.23:8000`. Tap **Test** - it should say *Connected* - then **Save**.
   (Change it there any time the laptop's IP changes - no rebuild needed.)
2. Log in with a demo account (password for all: `demo1234`) or sign up:

| Role | Email | What you can do |
|---|---|---|
| Driver | `driver@demo.com` | Find mechanics, request help, chat, AI assistant, spare parts, vehicles |
| Mechanic | `mechanic@demo.com` | See jobs, accept, "on my way", complete, chat, set workshop location |
| Supplier | `supplier@demo.com` | List and manage spare parts |

Try the full flow with two devices, or phone + browser-free trick: log in as the driver on the phone, send a
request, then log out and log in as the mechanic to accept it.

Demo mechanics are placed around Kampala. If you test somewhere else, either use the driver's *Nearby* map and
zoom to Kampala, or edit `SEED_CENTER_LAT` / `SEED_CENTER_LNG` in `.env`, delete `autoassist.db` and restart the server.

**Real mechanics:** register as *Mechanic*, then on the Jobs tab tap **Use my current location** so drivers can find you.

---------------------------------------------------------------------------------------------------

## What maps to your proposal

| Proposal feature | Where |
|---|---|
| Registration / login (JWT) | Welcome > Login / Sign Up |
| Vehicle registration | Profile > My vehicles |
| Driver dashboard | Home tab |
| Emergency assistance requests | Home > "Broken down?" |
| GPS / location | Request form, Nearby map |
| Nearby mechanics + profiles + ratings | Home grid, Nearby tab, mechanic page |
| Driver-mechanic communication | Request > chat icon (WebSocket) |
| Spare-parts search | Home > Spare parts |
| AI vehicle assistant | Home > Ask AI (Groq `openai/gpt-oss-20b`) |
| Dark / light mode | Profile > Dark mode |

Privacy: a mechanic only sees an approximate area of a driver until they accept the request.
AI answers are labelled as preliminary guidance, not a professional diagnosis.

---------------------------------------------------------------------------------------------------

## If something goes wrong

| Problem | Fix |
|---|---|
| "Cannot reach the server" | Server window still open? Same Wi-Fi? Address has `http://` and `:8000`? Firewall allowed Python on Private networks? Test `http://YOUR-IP:8000/health` in the phone's browser. |
| Map is grey / blank | Phone needs internet (tiles come from openstreetmap.org). |
| "Location permission blocked" | Phone Settings > Apps > AutoAssist > Permissions > Location > Allow. |
| AI says "not set up" | Put your key in `.env` (no quotes needed) and restart the server. |
| AI says key rejected / busy | Check the key at console.groq.com; the free tier has rate limits - wait a moment. |
| No mechanics in the list | The demo data is around Kampala (see Part C), or the mechanic hasn't set a location yet. |
| `flutter pub get` / build errors | Copy the full message and send it back. Also try `flutter upgrade` first. |
| Signed in as wrong user / stuck | Profile > Log out. To wipe demo data: delete `autoassist.db` and restart the server. |

Note for the report: SQLite is used for this prototype. Because the database code uses SQLAlchemy, moving to
PostgreSQL later is a one-line change of `DATABASE_URL`. ok
