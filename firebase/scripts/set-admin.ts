// Grants (or with --remove, revokes) admin access for an existing account.
// Admin is a custom claim on the user's ID token, which the security rules
// check; it can't be self-assigned from the app.
//
//   npm run set-admin -- someone@example.com
//   npm run set-admin -- someone@example.com --remove
//   npm run set-admin -- someone@example.com --production
//
// The user must sign out and back in afterwards to pick up the new claim.

import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

import { initAdmin } from "./firebaseAdmin";

async function main() {
  const email = process.argv.slice(2).find((arg) => !arg.startsWith("--"));
  if (!email) {
    throw new Error("Usage: npm run set-admin -- <email> [--remove] [--production]");
  }
  const remove = process.argv.includes("--remove");

  initAdmin();
  const user = await getAuth().getUserByEmail(email);
  const claims = { ...(user.customClaims ?? {}) };
  if (remove) {
    delete claims.admin;
  } else {
    claims.admin = true;
  }
  await getAuth().setCustomUserClaims(user.uid, claims);

  // The profile's role is display-only; keep it in step with the claim.
  const profile = getFirestore().collection("users").doc(user.uid);
  if ((await profile.get()).exists) {
    await profile.update({ role: remove ? "consumer" : "admin" });
  }

  console.log(`${remove ? "Removed admin from" : "Made admin:"} ${email} (${user.uid}). They need to log in again.`);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
