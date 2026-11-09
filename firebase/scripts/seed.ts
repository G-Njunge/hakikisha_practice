// Seeds Firestore with the reference data the app reads: medicines (with
// checklists and photo names), pharmacies (with stock), and the regulators
// reports are sent to. Safe to re-run: every document is overwritten by ID.
//
//   npm run seed                 # local emulators (start them first)
//   npm run seed -- --production # a real project (see README)

import path from "node:path";

import { GeoPoint, getFirestore, type WriteBatch } from "firebase-admin/firestore";

import { initAdmin } from "./firebaseAdmin";
import {
  COUNTRY_TO_REGULATORS,
  MEDICINE_PHOTOS,
  SAFETY_COMPARISON_ITEMS,
  healthAuthorities,
  makeBarcode,
  medicines,
  packageVerificationItems,
  pharmacies,
  pharmacyStocksMedicine,
  type RegulatoryBody,
} from "./seedData";

/**
 * Reference photos ship inside the app (mobile/assets/medicines/), since
 * Cloud Storage isn't available on the free Spark plan. A medicine stores the
 * file name: "/assets/medicines/x.jpeg" (the old server path) → "x.jpeg".
 */
function photoFileFor(serverPath: string | undefined): string | null {
  return serverPath ? path.basename(serverPath) : null;
}

function slug(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

/** Firestore batches cap at 500 writes; this commits as it fills. */
class BatchWriter {
  private batch: WriteBatch;
  private count = 0;
  private pending: Promise<unknown>[] = [];

  constructor(private readonly db: FirebaseFirestore.Firestore) {
    this.batch = db.batch();
  }

  set(ref: FirebaseFirestore.DocumentReference, data: FirebaseFirestore.DocumentData) {
    this.batch.set(ref, data);
    if (++this.count === 500) this.flush();
  }

  private flush() {
    this.pending.push(this.batch.commit());
    this.batch = this.db.batch();
    this.count = 0;
  }

  async close() {
    if (this.count > 0) this.flush();
    await Promise.all(this.pending);
  }
}

async function seed() {
  initAdmin();
  const db = getFirestore();
  const writer = new BatchWriter(db);

  // Medicines, keyed by barcode so a scan is a single document read.
  const regulatorSeq: Record<RegulatoryBody, number> = { NAFDAC: 0, KEBS: 0, SAHPRA: 0, "Rwanda FDA": 0 };
  const barcodesByRegulator: Record<RegulatoryBody, string[]> = { NAFDAC: [], KEBS: [], SAHPRA: [], "Rwanda FDA": [] };
  let photoCount = 0;

  for (const medicine of medicines) {
    regulatorSeq[medicine.regulatoryBody] += 1;
    const barcode = medicine.barcode ?? makeBarcode(medicine.regulatoryBody, regulatorSeq[medicine.regulatoryBody]);
    barcodesByRegulator[medicine.regulatoryBody].push(barcode);

    const photos = MEDICINE_PHOTOS[medicine.name] ?? {};
    const tablet = photoFileFor(photos.tablet);
    const pkg = photoFileFor(photos.package);
    photoCount += [tablet, pkg].filter(Boolean).length;

    writer.set(db.collection("medicines").doc(barcode), {
      name: medicine.name,
      nameLower: medicine.name.toLowerCase(),
      genericName: medicine.genericName,
      genericNameLower: medicine.genericName?.toLowerCase() ?? null,
      manufacturer: medicine.manufacturer,
      dosageForm: medicine.dosageForm,
      strength: medicine.strength,
      barcode,
      regulatoryBody: medicine.regulatoryBody,
      approvalNumber: medicine.approvalNumber,
      approvalStatus: medicine.approvalStatus,
      photos: { tablet, package: pkg },
      packageVerification: packageVerificationItems(medicine.dosageForm),
      safetyComparison: SAFETY_COMPARISON_ITEMS,
    });
  }

  // Pharmacies, each with the barcodes it stocks (queried with
  // array-contains) — the same deterministic stock pattern as the old seed.
  let stockLinks = 0;
  for (const pharmacy of pharmacies) {
    const eligible = (COUNTRY_TO_REGULATORS[pharmacy.country] ?? []).flatMap((r) => barcodesByRegulator[r]);
    const stocked = eligible.filter((barcode) => pharmacyStocksMedicine(pharmacy.name, barcode));
    stockLinks += stocked.length;

    writer.set(db.collection("pharmacies").doc(slug(`${pharmacy.name} ${pharmacy.address}`)), {
      name: pharmacy.name,
      address: pharmacy.address,
      location: new GeoPoint(pharmacy.latitude, pharmacy.longitude),
      phone: pharmacy.phone,
      hours: pharmacy.hours,
      country: pharmacy.country,
      stockedMedicineIds: stocked,
    });
  }

  for (const authority of healthAuthorities) {
    writer.set(db.collection("healthAuthorities").doc(authority.country), {
      authorityName: authority.authorityName,
      email: authority.email,
    });
  }

  await writer.close();
  console.log(
    `Seeded ${medicines.length} medicines (${photoCount} photos referenced), ${pharmacies.length} pharmacies ` +
      `(${stockLinks} stock links) and ${healthAuthorities.length} health authorities.`
  );
}

seed().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
