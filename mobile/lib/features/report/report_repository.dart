import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/providers.dart';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(ref.watch(firestoreProvider), ref.watch(firebaseAuthProvider)),
);

/// Report photos are stored in Firestore as base64 (Cloud Storage isn't on
/// the free plan). Firestore documents max out at 1 MiB and the rules allow
/// 900,000 base64 characters, so the image itself must stay under ~650 KB;
/// the picker's downscaling keeps phone photos well below that.
const maxReportPhotoBytes = 650 * 1024;

class ReportPhoto {
  const ReportPhoto(this.bytes, {this.contentType = 'image/jpeg'});

  final Uint8List bytes;
  final String contentType;
}

class ReportRepository {
  ReportRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Files a counterfeit report for the signed-in user. At least one of
  /// [scanId] or [productName] identifies the product. Admins then see it in
  /// the report queue and email the regulator for [country] from there.
  Future<void> submit({
    String? scanId,
    String? productName,
    String? medicineName,
    required String description,
    required String country,
    String? purchaseLocation,
    ReportPhoto? photo,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppException('Please log in to report a medicine.');
    if (photo != null && photo.bytes.length > maxReportPhotoBytes) {
      throw const AppException('That photo is too large. Please try another one.');
    }

    // The report and its photo are written together, so a report never
    // claims a photo that isn't there (the security rules check this).
    final report = _db.collection('reports').doc();
    final batch = _db.batch()
      ..set(report, {
        'scanId': scanId,
        'productName': productName,
        'medicineName': medicineName,
        'description': description,
        'country': country,
        'purchaseLocation': purchaseLocation,
        'hasPhoto': photo != null,
        'status': 'pending',
        'reportedBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    if (photo != null) {
      batch.set(_db.collection('reportPhotos').doc(report.id), {
        'reportedBy': uid,
        'contentType': photo.contentType,
        'data': base64Encode(photo.bytes),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
    } catch (e) {
      throw toAppException(e);
    }
  }
}
