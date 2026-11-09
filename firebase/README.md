# Hakikisha Firebase backend

The backend for the mobile app. It uses only what's free on Firebase's **Spark plan**: **Authentication** and **Cloud Firestore**. There's no server code. The app talks to Firestore directly, and the security rules in `firestore.rules` are the access control and input validation.

Locally, everything runs in the **Firebase Emulator Suite** under the project ID `demo-hakikisha`. A `demo-` project never touches the cloud, so there's nothing to create, pay for or sign in to.

## Why only Auth and Firestore

Cloud Functions and Cloud Storage both require the pay-as-you-go **Blaze** plan; Storage has since February 2026. Blaze has budget alerts but no spending cap. Staying on Spark means there's no billing account and no way to be charged. If the free quota runs out (50k reads, 20k writes a day, 1 GiB stored), requests are refused until the next day instead.

That shapes three parts of the app:

| Need | How it's done on Spark |
|---|---|
| Medicine reference photos | Bundled in the app (`mobile/assets/medicines/`); a medicine stores the file name. New photos need an app update. |
| Report evidence photos | Stored in Firestore as base64 in `reportPhotos/{reportId}`, downscaled to fit a document (max ~650 KB per image) |
| Telling the regulator about a report | An admin opens the report and taps **Email regulator**, which opens their mail app pre-filled. The report then records `regulatorNotifiedAt`. |

## Prerequisites

- Node.js 22+ and the Firebase CLI (`npm install -g firebase-tools`)
- Java 21+ for the Firestore emulator. Android Studio ships one; point `JAVA_HOME` at it:

  ```powershell
  $env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
  $env:Path = "$env:JAVA_HOME\bin;$env:Path"
  ```

## Run it

```
npm install
npm run emulators          # terminal 1: Auth + Firestore, with the Emulator UI at http://localhost:4000
npm run seed               # terminal 2, first time only: medicines, pharmacies, regulators
```

Then start the app from `../mobile` with `flutter run`; it uses these emulators by default.

Emulator data (accounts, scans, reports) is saved to `emulator-data/` when you stop the emulators with Ctrl+C, and loaded back next time. Delete that folder to start clean, then seed again.

To make an account an admin (it must already exist; sign out and back in afterwards):

```
npm run set-admin -- someone@example.com
```

## What's where

| Path | What it is |
|---|---|
| `firestore.rules` | Security rules: who can read and write what, and what valid data looks like |
| `firestore.indexes.json` | Composite indexes for the app's queries (report queue by status, history by user) |
| `scripts/seed.ts`, `scripts/seedData.ts` | Seed data, ported from the old Express server's seed |
| `scripts/set-admin.ts` | Grants or revokes the `admin` custom claim |
| `scripts/smoke.ts` | End-to-end check run by `npm run test:e2e` |
| `scripts/firebase.mjs` | Wrapper around the Firebase CLI that keeps emulator data between runs |
| `tests/` | Security rules tests |

## Data model

| Collection | Contents | Who can read / write |
|---|---|---|
| `medicines/{barcode}` | Registry entry: name, manufacturer, approval status, photo file names, package checklist | Anyone reads; only the seed/admin scripts write |
| `pharmacies/{id}` | Name, address, `location` (GeoPoint), phone, hours, `stockedMedicineIds` | Anyone reads; only the scripts write |
| `healthAuthorities/{country}` | Regulator name and email | Admins read; only the scripts write |
| `users/{uid}` | Name, email, country, role (display only); for admins, `reportsLastViewedAt` | The user and admins. Users can't give themselves the admin role |
| `scans/{id}` | Barcode, result, who scanned (or null if signed out), time | Anyone creates; the scanner and admins read. The result must match the registry. Never edited |
| `reports/{id}` | Counterfeit report: product, description, country, `hasPhoto`, status, notes, `regulatorNotifiedAt` | Signed-in users create (always `pending`); the reporter and admins read; only admins change status and notes |
| `reportPhotos/{reportId}` | The report's photo (base64) | Written only in the same batch as its report, by the reporter; the reporter and admins read; never edited |

Admin access is the `admin` custom claim on the user's token, set with `npm run set-admin`. It can't be granted from the app.

## Tests

```
npm run typecheck
npm run test:rules    # security rules, against the Firestore emulator
npm run test:e2e      # seed + smoke test: data, bundled photos, stock query
```

CI runs all of these (the `firebase` job in `.github/workflows/ci.yml`).

## Going live (later, still free)

1. Create a Firebase project in the console and leave it on the Spark plan. Enable Authentication (Email/Password) and Firestore.
2. Point the CLI at it with `firebase use --add`. From `../mobile`, run `flutterfire configure` to generate `lib/firebase_options.dart`.
3. Deploy the rules and indexes with `firebase deploy --only firestore`.
4. Seed it: `GCLOUD_PROJECT=<id> npm run seed -- --production`, using Application Default Credentials (`gcloud auth application-default login`).
5. Build the app with `--dart-define=USE_FIREBASE_EMULATORS=false`.
