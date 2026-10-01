# Forge — private iPhone + Apple Watch strength trainer

Forge plans strength workouts around how recovered each muscle is and the equipment you actually have, logs every set on your iPhone or Apple Watch, saves workouts to Apple Health, backs everything up to iCloud Drive, and controls Spotify while you train.

## What's in it

**iPhone**
- **Workout** – one tap generates today's session from muscle recovery + your active equipment setup. Swap any exercise for a similar one, choose your own, hide exercises you never want again. Log weight × reps per set, rest timer with a buzz when it's up.
- **Equipment setups** – save setups like *Gym*, *Home*, *Hotel*; switch with one tap. Only exercises you can do with that gear are planned (78 exercises in the library).
- **Plan my week** – plans 2–6 upcoming sessions with the active equipment, simulating recovery between them. Weights refresh when you start each one.
- **Recovery** – front/back body map coloured from fatigued (red) to fresh (green), plus % per muscle.
- **History** – volume chart, every workout, estimated 1-rep max per exercise.
- **Progressive overload** – next weights come from your last best set; complete every set and it nudges the weight up.
- **Apple Health** – saves each workout (strength training) with calories.
- **iCloud Drive backup** – automatic copy of all your data in a folder you choose.
- **Spotify** – now playing, play/pause/skip, and your playlists right on the workout screen.

**Apple Watch**
- Today's workout appears automatically from the iPhone.
- Log sets with the **Digital Crown** (tap weight or reps to choose which one the crown changes), rest countdown with haptics.
- **Start Tracking** runs a real watch workout: live heart rate and calories, saved to Apple Health.
- Swipe up for **music controls** (controls Spotify playing on your iPhone).

## Installing it (no Mac needed)

You'll need: a free GitHub account, a Windows PC, a USB cable for your iPhone, and your Apple ID.

### 1. Put the code on GitHub (private)
1. Sign in at github.com → **New repository** → name it `forge` → choose **Private** → Create.
2. On the new repo page click **uploading an existing file**, then drag in everything from this folder (`iOS`, `Watch`, `Shared`, `Support`, `project.yml`, `README.md`, and `.github`) → **Commit changes**.
   - `.github` is hidden on some computers. If it didn't upload: **Add file → Create new file**, type the name `.github/workflows/build.yml`, paste in the contents of that file, and commit.

### 2. Build the app in the cloud
1. In your repo open the **Actions** tab → **Build Forge** → **Run workflow**.
2. Wait about 5–10 minutes for the green tick. Every successful build is published under **Releases** (right side of the repo page) — open the newest one and download `Forge.ipa`. It's also attached to the run on the Actions page as **Forge-ipa**.
   - If it fails, download **build-log** from the same page and send me the errors — I'll fix them.
   - GitHub gives private repos a monthly allowance of free build minutes; macOS minutes count extra against it, but a handful of builds a month fits comfortably.

### 3. Install on your iPhone (Windows)
1. Install **iTunes** and **iCloud** from apple.com (the downloads from Apple's website, not the Microsoft Store versions).
2. Install **Sideloadly** from sideloadly.io.
3. On your iPhone: **Settings → Privacy & Security → Developer Mode → On** (it restarts).
4. Plug in the iPhone, tap **Trust** on it. Open Sideloadly, drag in `Forge.ipa`, enter your Apple ID, press **Start**. Leave Sideloadly's advanced options alone (don't change the bundle ID).
5. On the iPhone: **Settings → General → VPN & Device Management →** your Apple ID → **Trust**.

### 4. Install on your Apple Watch
1. On the watch: **Settings → Privacy & Security → Developer Mode → On**.
2. On the iPhone open the **Watch** app → **My Watch** → scroll to **Available Apps** → **Install** next to Forge.

> Sideloading Watch apps with a free Apple ID doesn't work on every setup. If Forge never appears under *Available Apps*, the iPhone app still works fully on its own. The reliable fix is renting a cloud Mac for an hour (e.g. MacinCloud) and installing from Xcode — I can walk you through that.

### 5. Every 7 days
Free Apple ID installs expire after 7 days. Plug in, open Sideloadly, drag in the same `Forge.ipa`, press Start. Your data stays (and it's backed up to iCloud Drive anyway).

## First-time setup in the app

**Equipment** – Settings → *My Equipment*. Edit *Gym* and *Home* or add your own setups, tick what you have. Switch the active setup on the Workout tab.

**iCloud Drive backup** – Settings → *iCloud Drive* → **Choose iCloud Drive folder** → in iCloud Drive create a folder called `Forge` → open it → **Open**. From then on `Forge-data.json` is updated automatically after every change. On a new install, pick the same folder and tap **Restore it**.

**Apple Health** – Settings → turn on *Save workouts to Apple Health* and allow access.

**Spotify** – two levels:
- *Quick*: paste a playlist link (Spotify → playlist → Share → Copy link) into Settings → Spotify. The Workout tab gets a **Play workout playlist** button that opens it in Spotify.
- *Full controls* (see what's playing, play/pause/skip, browse playlists in Forge):
  1. Go to developer.spotify.com/dashboard, log in, **Create app**.
  2. Any name/description. Redirect URI: `forge-spotify://callback`. Tick **Web API**. Save.
  3. Copy the **Client ID** into Forge → Settings → Spotify → **Connect Spotify account**.
  Playback control requires Spotify Premium, and Spotify needs to be open on one of your devices.

## Notes and limits
- **iCloud**: live CloudKit sync isn't allowed for apps installed with a free Apple ID, so Forge backs up to an iCloud Drive folder instead. With a paid Apple Developer account ($99/yr) this can be upgraded to automatic sync.
- **Units**: switching lb/kg changes labels and rounding; it doesn't convert past numbers.
- **App ID**: set in `project.yml` (`FORGE_BUNDLE_PREFIX`). It's already unique to you; only change it if Sideloadly reports an ID conflict.
- Forge is your own app with its own name and design. It's inspired by Fitbod's approach but doesn't copy its branding.

## Project layout
```
project.yml          Xcode project definition (XcodeGen)
.github/workflows/   Cloud build → Forge.ipa
Shared/              Models, 78-exercise library, recovery engine, workout generator
iOS/                 iPhone app (SwiftUI): store, Health, Watch sync, iCloud backup, Spotify, screens
Watch/               Apple Watch app: set logging, workout session, sync, music controls
Support/             Info.plists and entitlements are generated here at build time
```
