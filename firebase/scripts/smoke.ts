// End-to-end check of the local backend, run by `npm run test:e2e` inside
// the emulators after seeding: the reference data is there, every photo a
// medicine references ships with the app, and stock queries work.

import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import path from "node:path";

import { getFirestore } from "firebase-admin/firestore";

import { initAdmin } from "./firebaseAdmin";
import * as seed from "./seedData";

const APP_PHOTO_DIR = path.join(__dirname, "..", "..", "mobile", "assets", "medicines");

async function main() {
  initAdmin();
  const db = getFirestore();

  const [medicines, pharmacies, authorities] = await Promise.all([
    db.collection("medicines").get(),
    db.collection("pharmacies").count().get(),
    db.collection("healthAuthorities").count().get(),
  ]);
  assert.equal(medicines.size, seed.medicines.length, "medicines seeded");
  assert.equal(pharmacies.data().count, seed.pharmacies.length, "pharmacies seeded");
  assert.equal(authorities.data().count, seed.healthAuthorities.length, "health authorities seeded");
  console.log("✓ reference data seeded");

  let photos = 0;
  for (const medicine of medicines.docs) {
    assert.equal(medicine.id, medicine.get("barcode"), "medicines are keyed by barcode");
    for (const file of Object.values(medicine.get("photos") as Record<string, string | null>)) {
      if (!file) continue;
      assert.ok(existsSync(path.join(APP_PHOTO_DIR, file)), `${file} is bundled in mobile/assets/medicines`);
      photos += 1;
    }
  }
  console.log(`✓ all ${photos} referenced photos are bundled with the app`);

  const panadol = medicines.docs.find((doc) => doc.get("name") === "Panadol");
  assert.ok(panadol, "Panadol exists");
  const stocking = await db.collection("pharmacies").where("stockedMedicineIds", "array-contains", panadol.id).get();
  assert.ok(stocking.size > 0, "some pharmacies stock Panadol");
  console.log(`✓ ${stocking.size} pharmacies stock Panadol`);

  console.log("Smoke test passed.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
