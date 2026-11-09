# Hakikisha

Hakikisha ("assurance" / "make certain" in Swahili) is a mobile app for checking that a medicine is genuine. You scan its barcode (camera, photo, or by typing the number) and the app walks you through a guided check:

1. The medicine is identified against the registry.
2. You compare it with genuine reference photos.
3. You tick off a genuine-package checklist.
4. You're pointed to nearby pharmacies that stock it and are open.

Suspicious products can be reported, and admins forward each report to the national medicines regulator. Admins also get a dashboard of platform stats and a queue for working through reports.

## What's here

| Folder | What it is |
|---|---|
| [`mobile/`](mobile/README.md) | The Flutter app (Android, iOS, and Chrome for development) |
| [`firebase/`](firebase/README.md) | Its backend: Firebase Auth and Firestore, with security rules, seed data and admin scripts |
| `.github/workflows/ci.yml` | CI: `flutter analyze` + `flutter test`, plus the Firebase typecheck, security-rules tests and emulator smoke test, on every push |

The backend uses only Firebase's free **Spark** plan: no server code, no billing account, no way to be charged. The [Firebase README](firebase/README.md) explains what that means for photos and regulator emails.

## Run it locally

Everything runs on your machine in the Firebase Emulator Suite; no Firebase project is needed.

You'll need:
- Flutter
- Node.js and the Firebase CLI (`npm install -g firebase-tools`)
- Java 21+ for the Firestore emulator (Android Studio's bundled one works)

**Terminal 1: Firebase emulators** (keep running)
```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
cd firebase
npm install          # first time only
npm run emulators
```

**Terminal 2: sample data** (first time only)
```powershell
cd firebase
npm run seed
```

**Terminal 3: the app**
```powershell
cd mobile
flutter pub get
flutter emulators --launch Pixel_7   # or: flutter run -d chrome
flutter run
```

To try a scan, tap **Type number** and enter `8433042001438` (Gamalate B6).

[mobile/README.md](mobile/README.md) covers verification emails, making an admin, testing location, and running on a physical phone.

## Data

The registry holds 31 medicines and 46 pharmacies: 39 real pharmacies in Kigali, Rwanda, plus 7 demo entries in Nigeria, Kenya and South Africa. There are also 5 national regulators. Pharmacy coordinates are neighbourhood-level approximations and the opening hours are placeholders, so check both before relying on them. Seed data lives in `firebase/scripts/seedData.ts`; reference photos ship with the app in `mobile/assets/medicines/`.
