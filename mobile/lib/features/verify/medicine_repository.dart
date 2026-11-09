import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/providers.dart';
import '../../models/medicine.dart';
import '../../models/pharmacy.dart';
import '../../models/scan_result.dart';

final medicineRepositoryProvider = Provider<MedicineRepository>(
  (ref) => MedicineRepository(ref.watch(firestoreProvider), ref.watch(firebaseAuthProvider)),
);

/// One medicine, for the verification flow and the detail screen.
final medicineProvider = FutureProvider.autoDispose.family<Medicine, String>(
  (ref, medicineId) => ref.watch(medicineRepositoryProvider).medicine(medicineId),
);

/// The whole registry, loaded once per app session for search and the
/// pharmacy finder's medicine picker. It's a few dozen documents; past a few
/// hundred, search would move to prefix queries or a search service.
final medicineCatalogProvider = FutureProvider<List<Medicine>>(
  (ref) => ref.watch(medicineRepositoryProvider).allMedicines(),
);

/// Registry lookups (medicines, pharmacies) and the scan log, straight
/// against Firestore.
class MedicineRepository {
  MedicineRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Looks the barcode up and logs the scan. Works signed out; attributed to
  /// the user when signed in.
  Future<ScanResult> scanBarcode(String barcode) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _db.collection('medicines').doc(barcode).get();
    } catch (e) {
      throw toAppException(e);
    }

    final logEntry = _db.collection('scans').doc();
    final result = evaluateScan(barcode: barcode, scanId: logEntry.id, medicine: snapshot.data());

    // Logged in the background: the result doesn't depend on it, and Firestore
    // queues the write if the device is offline.
    unawaited(logEntry.set({
      'barcode': barcode,
      'medicineId': result.medicine?.id,
      'medicineName': result.medicine?.name,
      'result': result.resultCode,
      'scannedBy': _auth.currentUser?.uid,
      'location': null,
      'scannedAt': FieldValue.serverTimestamp(),
    }).catchError((Object e) => debugPrint('Failed to log scan: $e')));

    return result;
  }

  Future<Medicine> medicine(String medicineId) async {
    try {
      final snapshot = await _db.collection('medicines').doc(medicineId).get();
      final data = snapshot.data();
      if (data == null) throw const AppException("We couldn't find that medicine.");
      return Medicine.fromFirestore(snapshot.id, data);
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<List<Medicine>> allMedicines() async {
    try {
      final snapshot = await _db.collection('medicines').orderBy('nameLower').get();
      return [for (final doc in snapshot.docs) Medicine.fromFirestore(doc.id, doc.data())];
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// Pharmacies near the user. With [medicineId], only those stocking it are
  /// fetched. The whole directory is small (tens of pharmacies), so distance
  /// is filtered on the device; a geohash index would replace this at scale.
  Future<List<NearbyPharmacy>> nearbyPharmacies({
    required double lat,
    required double lng,
    String? medicineId,
    double radiusKm = 10,
    bool openNow = false,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db.collection('pharmacies');
      if (medicineId != null) {
        query = query.where('stockedMedicineIds', arrayContains: medicineId);
      }
      final snapshot = await query.get();
      return rankNearbyPharmacies(
        snapshot.docs.map(_pharmacyFromDoc),
        lat: lat,
        lng: lng,
        medicineId: medicineId,
        radiusKm: radiusKm,
        openNowOnly: openNow,
      );
    } catch (e) {
      throw toAppException(e);
    }
  }

  static PharmacyRecord _pharmacyFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final location = data['location'] as GeoPoint;
    return PharmacyRecord(
      id: doc.id,
      name: data['name'] as String,
      address: data['address'] as String,
      latitude: location.latitude,
      longitude: location.longitude,
      phone: data['phone'] as String?,
      hours: data['hours'] as String?,
      stockedMedicineIds: (data['stockedMedicineIds'] as List? ?? const []).cast<String>(),
    );
  }
}
