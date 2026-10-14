# Setup guide

This guide covers a full local setup, connecting a phone or emulator to your computer's API, and the problems people usually hit.

## Prerequisites

| Tool | Version | Check |
|---|---|---|
| Node.js | 20 or newer | `node -v` |
| Flutter SDK | 3.47+ (Dart 3.13+) | `flutter --version`, `flutter doctor` |
| Android Studio (emulator) or Xcode (iOS simulator, macOS only) | recent | `flutter devices` |
| MongoDB | Docker **or** an Atlas cluster **or** none (in-memory mode) | `docker --version` |

## 1. Database

Choose one of these options.

### Option A: Docker (recommended)

```bash
docker compose up -d                 # from the repository root
docker compose ps                    # mongo should be "healthy"
```

Connection string: `mongodb://localhost:27017/ironrank`. The data persists in the `ironrank-mongo-data` volume. To reset it, run `docker compose down -v`.

### Option B: MongoDB Atlas

1. Create a free cluster and a database user.
2. Under *Network Access*, allow your current IP address.
3. Copy the connection string (`mongodb+srv://user:pass@cluster.../ironrank?retryWrites=true&w=majority`).

### Option C: no database (quick try-out)

`npm run dev:memory` downloads a MongoDB binary the first time (about 800 MB), starts it in memory, seeds it and runs the API. Everything is lost when you stop it.

## 2. Backend

```bash
cd backend
npm install
```

`backend/.env` was created with random JWT secrets. Open it and set `MONGO_URI`:

```dotenv
MONGO_URI=mongodb://localhost:27017/ironrank
JWT_SECRET=...           # already generated
JWT_REFRESH_SECRET=...   # already generated
PORT=4000
```

`.env.example` lists every supported variable. These are optional:
- `CORS_ORIGIN`
- `ACCESS_TOKEN_TTL` (default `15m`)
- `REFRESH_TOKEN_TTL_DAYS` (default `30`)

### Seed data

```bash
npm run seed              # exercises (downloaded from GitHub) + program templates
npm run seed:exercises    # only the exercise library
npm run seed:programs     # only the 4 templates (needs exercises first)
```

- **Re-running is safe.** Seeding updates existing exercises and templates in place and never touches users' data.
- **Offline seeding.** Download `https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json` once, then run:
  ```bash
  node src/seed/index.js exercises --file ./exercises.json
  npm run seed:programs
  ```

### Run

```bash
npm run dev      # restarts on file changes
npm start        # production-style
curl http://localhost:4000/health   # {"status":"ok","db":"up"}
```

### Tests

`npm test` runs Jest against an in-memory MongoDB and needs no database setup.

## 3. Mobile app

```bash
cd mobile
flutter pub get
flutter run              # pick the emulator/simulator/device when asked
```

### Pointing the app at your API

The app reads `mobile/assets/config/app_config.json`:

```json
{ "apiBaseUrl": "http://10.0.2.2:4000/api/v1", "connectTimeoutSeconds": 10, "receiveTimeoutSeconds": 20 }
```

| Device | URL to use |
|---|---|
| Android emulator | `http://10.0.2.2:4000/api/v1` (10.0.2.2 is the emulator's alias for your computer) |
| iOS simulator | `http://localhost:4000/api/v1` |
| Physical device | `http://<LAN IP of your computer>:4000/api/v1` |

To find your LAN IP, run `ipconfig` on Windows (the "IPv4 Address" line), `ipconfig getifaddr en0` on macOS, or `hostname -I` on Linux.

Instead of editing the file, you can pass the URL at build time:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:4000/api/v1
```

### Builds

```bash
flutter build apk --release        # Android (signed with debug keys; add your own signing config to publish)
flutter build ios --release        # iOS (on macOS, with signing set up in Xcode)
```

### Tests

```bash
flutter analyze
flutter test                                                  # unit + widget tests
flutter test --dart-define=GOLDENS=true --update-goldens      # also regenerate the screenshots
```

## Troubleshooting

### Connections

- **"Can't reach the server" in the app.**
  - Check `curl http://localhost:4000/health` on your computer.
  - On a phone, use your computer's LAN IP, not `localhost`.
  - Make sure both devices are on the same Wi-Fi.
  - On Windows, allow Node.js through the firewall for private networks.
- **Plain HTTP.** The app allows plain HTTP for local development: `usesCleartextTraffic` on Android and `NSAllowsLocalNetworking` on iOS. Use HTTPS for any deployed API.
- **`MONGO_URI is empty` when starting the API.** Set it in `backend/.env`, or use `npm run dev:memory`.
- **Atlas connection timeouts.** Your IP address isn't in the cluster's Network Access list.

### Notifications

- **The rest-timer notification doesn't fire.**
  - Allow notifications for IronRank. The app asks when you start your first workout.
  - On Android 12+, exact alarms make the alarm fire to the second. The app asks once. If you denied it, the alarm is "inexact" and may be a few seconds late.
  - Battery savers can delay notifications too.
- **No sound when the rest timer ends.** Check *Profile → Rest timer sound* and the phone's notification volume.

### Building and testing

- **Android build fails with a desugaring error.** Run `flutter clean && flutter pub get`. Core library desugaring is already enabled in `android/app/build.gradle.kts`.
- **The first `npm test` or `dev:memory` run is slow.** `mongodb-memory-server` is downloading the MongoDB binary. Later runs reuse it.

### Data

- **Ranks show "Set your sex in your profile".** Strength standards differ by sex, so male standards are used until you set it in *Profile → Edit*.
- **Resetting everything.**
  - Database: `docker compose down -v`.
  - App: uninstall it, or *Profile → Sign out*. Signing out clears cached data and queued workouts on the device.
