# Hakikisha mobile

Flutter app (Android + iOS) for Hakikisha. Its backend is Firebase Auth + Firestore on the free Spark plan (no server code, no billing), defined in `../firebase`.

## Run it locally

1. **Start the Firebase emulators and seed them** (see `../firebase/README.md`):

   ```
   cd ../firebase
   npm run emulators     # keep running
   npm run seed          # in another terminal, first time only
   ```

2. **Start an emulator and the app** (from `mobile/`):

   ```
   flutter emulators --launch Pixel_7
   flutter pub get
   flutter run
   ```

By default the app connects to the local emulators (`USE_FIREBASE_EMULATORS` defaults to true). On the Android emulator, `localhost` is mapped to your computer automatically. On a physical phone on the same Wi-Fi, pass your computer's LAN IP:

```
flutter run --dart-define=FIREBASE_EMULATOR_HOST=192.168.1.20
```

For that to work, the emulators must listen on all interfaces: add `"host": "0.0.0.0"` to the `auth` and `firestore` entries in `../firebase/firebase.json`.

The emulator connection is plain HTTP, so debug builds allow cleartext: Android through `android/app/src/debug/AndroidManifest.xml`, and iOS for local-network hosts (`NSAllowsLocalNetworking`).

**Verification emails:** the Auth emulator doesn't send real emails. The verification link appears in the emulator's log and in the Emulator UI at http://localhost:4000/auth. Open it, then tap "I've verified" in the Me tab.

**Admins:** run `npm run set-admin -- you@example.com` in `../firebase`, then log out and back in. The Admin tab appears, with a badge for reports filed since you last opened the queue.

The camera, photo-library scanning and location need a real device or an emulator with a camera. `analyzeImage` (scanning a barcode from a photo) isn't supported on the iOS Simulator. To test location on the Android emulator, set a location under *Extended controls → Location*; the seeded pharmacies are mostly in Kigali, around -1.95, 30.09.

## Checks

```
flutter analyze
flutter test
```

CI runs both (the `mobile` job in `.github/workflows/ci.yml`).

## Launcher icon

Generated from `assets/images/hakikisha-logo.png` (config at the bottom of `pubspec.yaml`). After changing the logo:

```
dart run flutter_launcher_icons
```

## Structure

```
lib/
├── main.dart, app.dart      Firebase init, then ProviderScope + MaterialApp.router
├── firebase_options.dart     Options for the local demo project; `flutterfire configure` replaces it for a real one
├── router.dart               go_router: tab shell (Scan / Search / Pharmacies / Me / Admin) + full-screen routes
├── core/
│   ├── firebase_setup.dart    Firebase.initializeApp + emulator connection
│   ├── providers.dart         FirebaseAuth / Firestore providers
│   ├── errors.dart            AppException; Firebase error codes → plain-language messages
│   ├── opening_hours.dart     "Mon-Sat 08:00-20:00" → open now? (Kigali time)
│   ├── geo.dart               Haversine distance
│   ├── location.dart          Permission + current position, with user-facing failure reasons
│   ├── password_policy.dart   Password rules for the live checklist
│   ├── countries.dart         Registration countries; report countries (those with a regulator on file)
│   └── theme.dart             Brand colours and Material 3 theme
├── models/                   Medicine + searchMedicines, ScanResult + evaluateScan, NearbyPharmacy + rankNearbyPharmacies, Report + workflow, User
└── features/
    ├── startup/               BrandLogo
    ├── shell/                 Bottom-nav shell (with the admin unread badge), ActiveTab
    ├── scan/                  Camera scanner, scan-from-photo, manual entry
    ├── verify/                Verification flow + MedicineRepository (barcode lookup, scan log, pharmacies)
    ├── medicine/              Search tab, medicine detail screen, reference photos, approval chip
    ├── pharmacies/            Pharmacies tab (medicine filter, open now, radius) + shared map, card and nearby finder
    ├── admin/                 Admin tab: overview stats + 7-day chart, report queue, report detail (actions, notes, email regulator)
    ├── report/                Counterfeit report form + ReportRepository (report and photo written together)
    ├── auth/                  Login, registration, AuthController, AuthRepository (Firebase Auth + users profile)
    └── me/                    Account tab (email verification, report, log out)
```

## How the app uses Firebase

- **Accounts:** Firebase Auth (email/password) keeps the session on the device. Sign-up creates a `users/{uid}` profile (name, country, role) and sends a verification email. Admin access is the `admin` custom claim on the token.
- **Scanning:** the app reads `medicines/{barcode}`, decides the result in `evaluateScan`, and logs a `scans` entry in the background. The security rules reject a logged result that disagrees with the registry.
- **Pharmacies:** the app fetches pharmacies that stock the medicine (`stockedMedicineIds` array-contains), then filters by distance and opening hours on the device. There are only a few dozen pharmacies, so a geohash index isn't needed yet.
- **Reports:** the report and its photo (base64, downscaled) are written to `reports` and `reportPhotos` in one batch. Admins see new reports in the Admin tab and email the regulator from there.
- **Medicine photos** ship in `assets/medicines/`; a medicine document names the file.
- **Search** loads the registry once per session and filters on the device (a few dozen medicines).
- **Admin stats** use Firestore count queries (one billed read per 1,000 documents counted).

## Not built yet

- Scan and report history in the Me tab
