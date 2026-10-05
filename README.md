# Forge — private iPhone + Apple Watch strength trainer

Forge plans strength workouts around how recovered each muscle is and the equipment you actually have, logs every set on your iPhone or Apple Watch, saves workouts to Apple Health, backs everything up to iCloud Drive, and controls Spotify while you train.

## What's in it

**iPhone**
- **Setup** – first launch asks your height, weight, experience (beginner / intermediate / advanced), goal, target weight and date, days per week, session length, equipment, and optional strength targets. Change it any time: Settings → *Profile, goals & targets*.
- **Workout** – shows the next day of your program ("Day 2 of 4 · Pull") with one tap to start (Start Day on the Program tab also jumps here). During a workout, **Focus** shows one exercise and the set you're on, with big +/− controls and a Done button that starts the rest timer and moves you on; **Overview** shows every exercise and set. Each exercise has a looping animation; tap it for the full form guide. Log weight × reps per set, rest timer with a buzz.
- **Program** – pick a split (Full Body, Upper/Lower, Push/Pull/Legs, Upper/Lower + PPL, or a body-part split) and days per week; Forge recommends one and lays out Day 1 → Day N with the exercises, sets and weights, plus suggested weekdays.
- **Smart weights** – starting weights come from your level, body weight and sex. After that, each suggestion follows what you actually log: hit every rep and it goes up; fall well short and it comes down. If you consistently lift less (or more) than suggested, starting weights for new exercises are rescaled to match you.
- **Your machines** – type the machines at your gym ("pec deck, hack squat, smith machine, cable crossover"). Forge recognises common names, lets you match anything it doesn't know, and only plans exercises you can do.
- **Form animations** – all 93 exercises animated in 3D. Switch Side / Front / Back / Turn, or drag to rotate. Form cues for each.
- **3D body form guide (beta)** – the Dumbbell Curl form guide has *See it on a 3D body*: a realistic male body holding the dumbbells, with live elbow and shoulder angles, the range each rep should travel, and the primary and secondary muscles highlighted. Works offline.
- **Progress** – body weight trend against your target, weekly consistency, strength-target progress bars, volume, and full workout history.
- **Weigh-ins** – prompt on the Workout tab when it's been a week, optional Sunday reminder, saved to Apple Health if enabled.
- **Cardio** – treadmill (incline walk, run, intervals) and elliptical (steady, intervals). Add cardio to your program as a warm-up or finisher, or start a cardio-only session. Log minutes, speed or resistance, and incline; the next suggestion builds on what you did. Calories and distance are estimated and saved to Apple Health as walking, running or elliptical workouts.
- **Abhi mode** – Settings → Look. Turns the whole app purple: light purple backgrounds, deep purple text and figures instead of black, purple buttons, charts and recovery map, a purple Watch background, and a purple home-screen icon (iOS asks you to confirm the icon change).
- **Recovery** – body map coloured from fatigued to fresh.
- **Apple Health** – Forge asks to connect on first launch; Settings → Apple Health shows whether it's connected and the exact reason if it isn't, with a Reconnect button. Calories for a workout logged on the iPhone come from your Apple Watch's own sensor readings in Health when it recorded them, otherwise from your heart rate (age and sex from Health), otherwise an estimate; History shows which, plus average and peak heart rate.
- **iCloud Drive backup** and **Spotify** as before.

**Apple Watch**
- Today's workout appears automatically from the iPhone.
- Log sets with the **Digital Crown**, rest countdown with haptics.
- Tap the figure icon on an exercise to see its **form animation** (tap the figure to switch side / front / back).
- **Sensors** – tracking starts by itself when you open an exercise: live, average and peak heart rate, active and resting calories from the Watch's calorie model, and the motion sensors count your reps (tap *Watch counted N* to use the count). Saved to Apple Health. **Start Tracking** is still there if you want to start before your first exercise.
- Swipe up for **music controls**.

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
3. Plug in the iPhone, tap **Trust** on it. Open Sideloadly, drag in `Forge.ipa`, enter your Apple ID, press **Start**. Leave Sideloadly's advanced options alone (don't change the bundle ID).
4. On your iPhone: **Settings → Privacy & Security →** scroll to the bottom → **Developer Mode → On** (it restarts). This switch only appears after step 3.
5. On the iPhone: **Settings → General → VPN & Device Management →** your Apple ID → **Trust**.

### 4. Install on your Apple Watch
1. On the iPhone open the **Watch** app → **My Watch** → scroll to **Available Apps** → **Install** next to Forge.
2. If the watch asks for it: **Settings → Privacy & Security → Developer Mode → On** (like the iPhone, this switch only shows up once a sideloaded app is on the watch).

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
Shared/              Models, 93-exercise library, strength standards, recovery engine, workout generator,
                     machine-name recognition, form animation renderer + forms.json
tools/forms/         Pose data that generates the animations (forms.py) and the browser preview
iOS/                 iPhone app (SwiftUI): store, Health, Watch sync, iCloud backup, Spotify, screens
Watch/               Apple Watch app: set logging, workout session, sync, music controls
Support/             Info.plists and entitlements are generated here at build time
```
