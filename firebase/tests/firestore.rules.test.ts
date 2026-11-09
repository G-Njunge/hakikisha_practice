import { readFileSync } from "node:fs";
import path from "node:path";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { addDoc, collection, doc, getDoc, serverTimestamp, setDoc, updateDoc, writeBatch } from "firebase/firestore";
import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";

let env: RulesTestEnvironment;

const APPROVED = "6150000000017";
const PENDING = "6160000000038";
const UNKNOWN = "12345678";

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-hakikisha-rules",
    firestore: { rules: readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8") },
  });
});

afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "medicines", APPROVED), { name: "Coartem", approvalStatus: "approved" });
    await setDoc(doc(db, "medicines", PENDING), { name: "Vibramycin", approvalStatus: "pending" });
    await setDoc(doc(db, "healthAuthorities", "Rwanda"), { email: "fda@example.com" });
    await setDoc(doc(db, "users", "alice"), { fullName: "Alice", role: "consumer" });
    await setDoc(doc(db, "users", "root"), { fullName: "Root", role: "admin" });
    await setDoc(doc(db, "scans", "alice-scan"), { scannedBy: "alice", barcode: APPROVED });
    await setDoc(doc(db, "reports", "alice-report"), {
      reportedBy: "alice",
      description: "Seal broken",
      status: "pending",
      hasPhoto: true,
    });
    await setDoc(doc(db, "reportPhotos", "alice-report"), { reportedBy: "alice", data: "abc" });
  });
});

const anon = () => env.unauthenticatedContext().firestore();
const as = (uid: string, claims: Record<string, unknown> = {}) =>
  env.authenticatedContext(uid, { email: `${uid}@example.com`, ...claims }).firestore();
const admin = () => as("root", { admin: true });

describe("reference data", () => {
  it("lets anyone read medicines and pharmacies", async () => {
    await assertSucceeds(getDoc(doc(anon(), "medicines", APPROVED)));
    await assertSucceeds(getDoc(doc(anon(), "pharmacies", "any")));
  });

  it("lets nobody write them from the app, not even admins", async () => {
    await assertFails(setDoc(doc(admin(), "medicines", APPROVED), { approvalStatus: "rejected" }));
    await assertFails(setDoc(doc(admin(), "pharmacies", "new"), { name: "Fake" }));
  });

  it("shows regulator contact addresses to admins only", async () => {
    await assertSucceeds(getDoc(doc(admin(), "healthAuthorities", "Rwanda")));
    await assertFails(getDoc(doc(as("alice"), "healthAuthorities", "Rwanda")));
    await assertFails(setDoc(doc(admin(), "healthAuthorities", "Rwanda"), { email: "x@example.com" }));
  });
});

describe("users", () => {
  const profile = (overrides: Record<string, unknown> = {}) => ({
    fullName: "Bob",
    email: "bob@example.com",
    country: "Rwanda",
    role: "consumer",
    createdAt: serverTimestamp(),
    ...overrides,
  });

  it("lets a user create their own profile", async () => {
    await assertSucceeds(setDoc(doc(as("bob"), "users", "bob"), profile()));
  });

  it("refuses a self-assigned admin role", async () => {
    await assertFails(setDoc(doc(as("bob"), "users", "bob"), profile({ role: "admin" })));
  });

  it("refuses a profile for someone else, or with another email", async () => {
    await assertFails(setDoc(doc(as("bob"), "users", "carol"), profile()));
    await assertFails(setDoc(doc(as("bob"), "users", "bob"), profile({ email: "carol@example.com" })));
  });

  it("lets a user rename themselves but not change their role", async () => {
    await assertSucceeds(updateDoc(doc(as("alice"), "users", "alice"), { fullName: "Alice U." }));
    await assertFails(updateDoc(doc(as("alice"), "users", "alice"), { role: "pharmacist" }));
  });

  it("keeps profiles private to their owner and admins", async () => {
    await assertFails(getDoc(doc(as("bob"), "users", "alice")));
    await assertSucceeds(getDoc(doc(as("alice"), "users", "alice")));
    await assertSucceeds(getDoc(doc(admin(), "users", "alice")));
  });

  it("lets admins record when they last viewed the report queue, and no one else", async () => {
    await assertSucceeds(updateDoc(doc(admin(), "users", "root"), { reportsLastViewedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as("alice"), "users", "alice"), { reportsLastViewedAt: serverTimestamp() }));
  });
});

describe("scans", () => {
  const scan = (overrides: Record<string, unknown> = {}) => ({
    barcode: APPROVED,
    medicineId: APPROVED,
    medicineName: "Coartem",
    result: "authentic",
    scannedBy: null,
    location: null,
    scannedAt: serverTimestamp(),
    ...overrides,
  });

  it("lets an anonymous user log a scan", async () => {
    await assertSucceeds(addDoc(collection(anon(), "scans"), scan()));
  });

  it("logs an unregistered barcode as unknown", async () => {
    await assertSucceeds(
      addDoc(collection(anon(), "scans"), scan({ barcode: UNKNOWN, medicineId: null, medicineName: null, result: "unknown" }))
    );
  });

  it("refuses a result that contradicts the registry", async () => {
    await assertFails(
      addDoc(collection(anon(), "scans"), scan({ barcode: PENDING, medicineId: PENDING, result: "authentic" }))
    );
    await assertFails(
      addDoc(collection(anon(), "scans"), scan({ barcode: UNKNOWN, medicineId: null, result: "authentic" }))
    );
  });

  it("attributes a signed-in scan to the scanner only", async () => {
    await assertSucceeds(addDoc(collection(as("bob"), "scans"), scan({ scannedBy: "bob" })));
    await assertFails(addDoc(collection(as("bob"), "scans"), scan({ scannedBy: "alice" })));
    await assertFails(addDoc(collection(as("bob"), "scans"), scan({ scannedBy: null })));
    await assertFails(addDoc(collection(anon(), "scans"), scan({ scannedBy: "bob" })));
  });

  it("refuses a malformed barcode", async () => {
    await assertFails(addDoc(collection(anon(), "scans"), scan({ barcode: "abc", medicineId: null, result: "unknown" })));
  });

  it("shows scan history only to its owner and admins", async () => {
    await assertSucceeds(getDoc(doc(as("alice"), "scans", "alice-scan")));
    await assertFails(getDoc(doc(as("bob"), "scans", "alice-scan")));
    await assertSucceeds(getDoc(doc(admin(), "scans", "alice-scan")));
  });

  it("never lets a scan be edited", async () => {
    await assertFails(updateDoc(doc(admin(), "scans", "alice-scan"), { result: "unknown" }));
  });
});

describe("reports", () => {
  const report = (uid: string, overrides: Record<string, unknown> = {}) => ({
    scanId: "scan-1",
    productName: null,
    medicineName: "Coartem",
    description: "Seal was broken",
    country: "Rwanda",
    purchaseLocation: null,
    hasPhoto: false,
    status: "pending",
    reportedBy: uid,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  });

  it("lets a signed-in user file a report", async () => {
    await assertSucceeds(addDoc(collection(as("bob"), "reports"), report("bob")));
  });

  it("refuses reports from signed-out users", async () => {
    await assertFails(addDoc(collection(anon(), "reports"), report("bob")));
  });

  it("refuses a report filed in someone else's name, or not pending", async () => {
    await assertFails(addDoc(collection(as("bob"), "reports"), report("alice")));
    await assertFails(addDoc(collection(as("bob"), "reports"), report("bob", { status: "resolved" })));
  });

  it("only accepts countries with a regulator on file", async () => {
    await assertFails(addDoc(collection(as("bob"), "reports"), report("bob", { country: "Atlantis" })));
  });

  it("requires a product: a scan or a name", async () => {
    await assertFails(addDoc(collection(as("bob"), "reports"), report("bob", { scanId: null, productName: "" })));
    await assertSucceeds(
      addDoc(collection(as("bob"), "reports"), report("bob", { scanId: null, productName: "Coartem 20/120" }))
    );
  });

  it("lets admins update status and record that the regulator was emailed", async () => {
    await assertSucceeds(
      updateDoc(doc(admin(), "reports", "alice-report"), {
        regulatorNotifiedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it("shows a report only to its reporter and admins", async () => {
    await assertSucceeds(getDoc(doc(as("alice"), "reports", "alice-report")));
    await assertFails(getDoc(doc(as("bob"), "reports", "alice-report")));
    await assertSucceeds(getDoc(doc(admin(), "reports", "alice-report")));
  });

  it("lets admins update status and notes, and nothing else", async () => {
    const ref = doc(admin(), "reports", "alice-report");
    await assertSucceeds(
      updateDoc(ref, { status: "investigating", adminNotes: "Checking batch", updatedAt: serverTimestamp() })
    );
    await assertFails(updateDoc(ref, { description: "Edited", updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { status: "made-up", updatedAt: serverTimestamp() }));
  });

  it("doesn't let reporters change their own report's status", async () => {
    await assertFails(
      updateDoc(doc(as("alice"), "reports", "alice-report"), { status: "resolved", updatedAt: serverTimestamp() })
    );
  });
});

describe("report photos", () => {
  const report = (uid: string, hasPhoto: boolean) => ({
    scanId: "scan-1",
    productName: null,
    medicineName: "Coartem",
    description: "Seal was broken",
    country: "Rwanda",
    purchaseLocation: null,
    hasPhoto,
    status: "pending",
    reportedBy: uid,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  const photo = (uid: string, data = "/9j/4AAQSkZJRg==") => ({
    reportedBy: uid,
    contentType: "image/jpeg",
    data,
    createdAt: serverTimestamp(),
  });

  /** Files a report and (optionally) its photo in one batch, as the app does. */
  function fileReport(uid: string, options: { hasPhoto: boolean; photo?: Record<string, unknown> }) {
    const db = as(uid);
    const reportRef = doc(collection(db, "reports"));
    const batch = writeBatch(db);
    batch.set(reportRef, report(uid, options.hasPhoto));
    if (options.photo) batch.set(doc(db, "reportPhotos", reportRef.id), options.photo);
    return batch.commit();
  }

  it("accepts a report and its photo written together", async () => {
    await assertSucceeds(fileReport("bob", { hasPhoto: true, photo: photo("bob") }));
  });

  it("refuses a report that claims a photo it doesn't include, or the reverse", async () => {
    await assertFails(fileReport("bob", { hasPhoto: true }));
    await assertFails(fileReport("bob", { hasPhoto: false, photo: photo("bob") }));
  });

  it("refuses a photo attributed to someone else", async () => {
    await assertFails(fileReport("bob", { hasPhoto: true, photo: photo("alice") }));
  });

  it("refuses a photo on its own, or added to someone else's report", async () => {
    await assertFails(setDoc(doc(as("bob"), "reportPhotos", "loose"), photo("bob")));
    await assertFails(setDoc(doc(as("bob"), "reportPhotos", "alice-report"), photo("bob")));
  });

  it("refuses photos that aren't images or are too large", async () => {
    await assertFails(fileReport("bob", { hasPhoto: true, photo: { ...photo("bob"), contentType: "text/plain" } }));
    await assertFails(fileReport("bob", { hasPhoto: true, photo: photo("bob", "a".repeat(900_001)) }));
  });

  it("shows a photo only to its reporter and admins, and never lets it change", async () => {
    await assertSucceeds(getDoc(doc(as("alice"), "reportPhotos", "alice-report")));
    await assertSucceeds(getDoc(doc(admin(), "reportPhotos", "alice-report")));
    await assertFails(getDoc(doc(as("bob"), "reportPhotos", "alice-report")));
    await assertFails(setDoc(doc(as("alice"), "reportPhotos", "alice-report"), photo("alice", "replaced")));
  });
});
