import { initializeApp } from "firebase-admin/app";

/**
 * Initialises the Admin SDK for the scripts. They target the local emulators
 * unless run with `--production`, so a stray `npm run seed` can't touch a
 * real project.
 */
export function initAdmin() {
  const production = process.argv.includes("--production");
  if (!production) {
    process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8080";
    process.env.FIREBASE_AUTH_EMULATOR_HOST ??= "127.0.0.1:9099";
    // Off-cloud, there's no GCP metadata server to probe for credentials;
    // skipping the probe avoids a timeout warning on every run.
    process.env.METADATA_SERVER_DETECTION ??= "none";
  }

  const projectId = process.env.GCLOUD_PROJECT ?? (production ? undefined : "demo-hakikisha");
  if (!projectId) {
    throw new Error("Set GCLOUD_PROJECT to your Firebase project ID when using --production.");
  }

  initializeApp({ projectId });
  console.log(`Using ${production ? "PRODUCTION project" : "emulators for"} ${projectId}`);
}
