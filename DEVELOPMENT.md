# HabloTengo — Development Guide

## Prerequisites

- Flutter SDK ≥ 3.11 (`flutter --version`)
- Firebase CLI (`firebase --version`)
- Node.js (required by Firebase CLI)
- Python 3 (for the dev web server)

## Repository layout

```
hablotengo/          — this Flutter project
  bin/
    start_emulator.sh   — start hablotengo Firebase emulator
    stop_emulator.sh    — stop both emulators
    serve_web.sh         — build + serve locally
  firebase.json          — hablotengo emulator config (Firestore 8082, Functions 5003, UI 4402)
  oneofus.firebase.json  — oneofus emulator config (Firestore 8081, Functions 5002, UI 4001)
  .firebaserc            — project alias: demo-hablotengo
  firestore.rules        — open read/write (integrity via signatures)
  lib/
    dev/
      simpsons_demo.dart     — populates emulators with Simpsons trust network
      test_runner_screen.dart — in-app integration tests (uses fake_cloud_firestore)
```

## Quick start (emulator + demo data)

Each project manages its own emulator. HabloTengo needs two running:

```bash
# 1. Start the oneofus emulator (from oneofusv22/)
cd oneofusv22
./bin/start_emulator.sh

# 2. Start the hablotengo emulator (from hablotengo/)
cd hablotengo
./bin/start_emulator.sh

# Wait ~5 seconds for emulators to come up, then:

# 3. Build and serve the web app
./bin/serve_web.sh
# Serves at http://localhost:8770

# 4. Open the app with emulator + Simpsons demo data pre-loaded
# http://localhost:8770/?fire=emulator&demo=simpsons
```

The `?demo=simpsons` flag calls `simpsonsDemo()` at startup, which:
- Creates 6 identity keys (Lisa, Homer, Marge, Bart, Milhouse, Maggie)
- Writes trust statements to the oneofus emulator
- Creates hablotengo delegate keys and writes delegate statements
- Writes contact cards + privacy settings to the hablotengo emulator
- Signs in as Lisa automatically

## URL parameters

| Parameter | Values | Effect |
|-----------|--------|--------|
| `fire` | `emulator` | Use local Firebase emulators |
| `fire` | (absent) | Use production Firebase |
| `demo` | `simpsons` | Load Simpsons demo (requires `fire=emulator`) |
| `tests` | `true` | Show the integration test runner screen |

## Integration tests (in-app)

Open `http://localhost:8770/?tests=true`

Tests run automatically on load using `fake_cloud_firestore` (no emulators needed).
The screen shows pass/fail per test with error details on failure. Hit the refresh
icon to re-run.

Tests cover:
- Simpsons trust graph setup and key creation
- Contact card write → read back (round-trip)
- Privacy statement defaults
- Milhouse reachable via Bart (distance ≤ 3)
- Card update: newer timestamp wins

## Testing QR sign-in

QR sign-in requires a real phone running the ONE-OF-US.NET identity app (oneofusv22) connected
to the same machine as the emulators. The phone uses `http://10.0.2.2:5003/...` to reach the
Hablo Cloud Function from an Android emulator, or the machine's LAN IP from a physical device.

```bash
# 1. Start emulators (from hablotengo/)
./bin/start_emulator.sh

# 2. Serve the web app
./bin/serve_web.sh

# 3. Open the app with emulator mode
# http://localhost:8770/?fire=emulator
```

Then in the web app:
- Click **Scan QR Code** on the sign-in screen — a QR dialog appears.
- Open the ONE-OF-US.NET phone app and scan the QR (or use the scanner in the app).
- The phone POSTs to `http://10.0.2.2:5003/demo-hablotengo/us-central1/signIn`.
- The web app listens on Firestore `sessions/doc/<session>` and picks up the response.
- The sign-in screen should update to show the signed-in identity.

**Troubleshooting:**
- Hablo Firestore emulator UI: http://localhost:4402 — check `sessions/doc/<session>` to confirm the phone posted.
- Cloud Function logs: `tail -f hablotengo_emulators.log`
- The sign-in CF verifies a session signature (Ed25519). If it rejects, check that the phone app
  is sending `sessionTime` and `sessionSignature` fields (added in oneofusv22/lib/core/sign_in_service.dart).

## Development workflow

```bash
# Rebuild after code changes:
flutter build web

# Or use Flutter's dev server (hot reload — note: emulator URLs may differ):
flutter run -d chrome --web-port=8770

# Analyze:
flutter analyze

# Stop emulators:
./bin/stop_emulator.sh
```

## Emulator UIs

| Emulator | UI |
|----------|----|
| hablotengo Firestore | http://localhost:4402 |
| oneofus Firestore | http://localhost:4001 |

## Firebase project

- Production project ID: `hablotengo`
- Emulator project ID: `demo-hablotengo` (demo- prefix = no auth required)
- Firestore rules: open write — integrity enforced by Ed25519 signatures at read time

## Architecture notes

- No Firebase Auth. Authentication is via a delegate key signed by the user's identity key.
- Two independent statement streams per user: `hablotengo_contact` and `hablotengo_privacy`.
  Update contact info without touching visibility, and vice versa.
- Trust graph BFS runs client-side against the oneofus Firestore.
- Reverse trust (canSeeYou) runs a parallel BFS from each contact's PoV using `Future.wait`.
