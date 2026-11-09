import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/providers.dart';
import '../../models/report.dart';
import '../auth/auth_controller.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(firestoreProvider), ref.watch(firebaseAuthProvider)),
);

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>(
  (ref) => ref.watch(adminRepositoryProvider).stats(),
);

/// Reports filed since this admin last opened the queue, for the tab badge.
/// Zero for everyone else.
final unreadReportsProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null || !user.isAdmin) return 0;
  return ref.watch(adminRepositoryProvider).unreadReportCount();
});

final reportProvider = FutureProvider.autoDispose.family<Report, String>(
  (ref, id) => ref.watch(adminRepositoryProvider).report(id),
);

final reportPhotoProvider = FutureProvider.autoDispose.family<Uint8List?, String>(
  (ref, reportId) => ref.watch(adminRepositoryProvider).reportPhoto(reportId),
);

final reporterProvider = FutureProvider.autoDispose.family<({String name, String email})?, String>(
  (ref, uid) => ref.watch(adminRepositoryProvider).reporter(uid),
);

final regulatorProvider = FutureProvider.autoDispose.family<Regulator?, String>(
  (ref, country) => ref.watch(adminRepositoryProvider).regulatorFor(country),
);

/// How many of the latest scans the "most scanned" list is drawn from.
const topScannedSampleSize = 200;

class AdminStats {
  const AdminStats({
    required this.users,
    required this.medicines,
    required this.pharmacies,
    required this.scans,
    required this.reports,
    required this.scansByResult,
    required this.reportsByStatus,
    required this.scansPerDay,
    required this.topScanned,
  });

  final int users;
  final int medicines;
  final int pharmacies;
  final int scans;
  final int reports;

  /// `authentic` / `unknown` counts from the scan log.
  final Map<String, int> scansByResult;
  final Map<ReportStatus, int> reportsByStatus;

  /// The last 7 days, oldest first, including days with no scans.
  final List<({DateTime day, int count})> scansPerDay;

  /// Most-scanned registered medicines among the latest scans.
  final List<({String name, int count})> topScanned;
}

/// Start of each of the last [days] local days, oldest first.
List<DateTime> lastDays(DateTime now, {int days = 7}) {
  final today = DateTime(now.year, now.month, now.day);
  return [for (var i = days - 1; i >= 0; i--) DateTime(today.year, today.month, today.day - i)];
}

/// Medicine names ranked by how often they appear; unregistered scans
/// (no name) aren't counted.
List<({String name, int count})> rankByFrequency(Iterable<String?> names, {int limit = 5}) {
  final counts = <String, int>{};
  for (final name in names) {
    if (name != null) counts[name] = (counts[name] ?? 0) + 1;
  }
  final ranked = counts.entries.toList()
    ..sort((a, b) => b.value != a.value ? b.value - a.value : a.key.compareTo(b.key));
  return [for (final e in ranked.take(limit)) (name: e.key, count: e.value)];
}

class ReportPage {
  const ReportPage(this.reports, this.cursor, {required this.hasMore});

  final List<Report> reports;

  /// Pass to the next [AdminRepository.reports] call to continue.
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}

class Regulator {
  const Regulator({required this.name, required this.email});

  final String name;
  final String email;
}

/// Admin-only reads and writes. The security rules check the caller's
/// `admin` claim on every one of these.
class AdminRepository {
  AdminRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _reports => _db.collection('reports');
  CollectionReference<Map<String, dynamic>> get _scans => _db.collection('scans');

  Future<int> _count(Query<Map<String, dynamic>> query) async => (await query.count().get()).count ?? 0;

  /// Counts use Firestore count queries (one billed read per 1,000 documents
  /// counted), so the dashboard stays cheap on the free plan.
  Future<AdminStats> stats({DateTime? now}) async {
    try {
      final days = lastDays(now ?? DateTime.now());
      final dayEnds = [...days.skip(1), days.last.add(const Duration(days: 1))];

      final totals = Future.wait([
        _count(_db.collection('users')),
        _count(_db.collection('medicines')),
        _count(_db.collection('pharmacies')),
        _count(_scans),
        _count(_reports),
      ]);
      final byResult = Future.wait([
        for (final result in ['authentic', 'unknown']) _count(_scans.where('result', isEqualTo: result)),
      ]);
      final byStatus = Future.wait([
        for (final status in ReportStatus.values) _count(_reports.where('status', isEqualTo: status.name)),
      ]);
      final perDay = Future.wait([
        for (var i = 0; i < days.length; i++)
          _count(_scans
              .where('scannedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(days[i]))
              .where('scannedAt', isLessThan: Timestamp.fromDate(dayEnds[i]))),
      ]);
      final recent = _scans.orderBy('scannedAt', descending: true).limit(topScannedSampleSize).get();

      final [users, medicines, pharmacies, scans, reports] = await totals;
      final [authentic, unknown] = await byResult;
      final statusCounts = await byStatus;
      final dayCounts = await perDay;
      final recentScans = await recent;

      return AdminStats(
        users: users,
        medicines: medicines,
        pharmacies: pharmacies,
        scans: scans,
        reports: reports,
        scansByResult: {'authentic': authentic, 'unknown': unknown},
        reportsByStatus: {
          for (var i = 0; i < ReportStatus.values.length; i++) ReportStatus.values[i]: statusCounts[i],
        },
        scansPerDay: [for (var i = 0; i < days.length; i++) (day: days[i], count: dayCounts[i])],
        topScanned: rankByFrequency(recentScans.docs.map((d) => d.data()['medicineName'] as String?)),
      );
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// Newest first, optionally only one [status].
  Future<ReportPage> reports({
    ReportStatus? status,
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _reports;
      if (status != null) query = query.where('status', isEqualTo: status.name);
      query = query.orderBy('createdAt', descending: true);
      if (after != null) query = query.startAfterDocument(after);
      // One extra tells us whether there's another page.
      final snapshot = await query.limit(pageSize + 1).get();
      final docs = snapshot.docs.take(pageSize).toList();
      return ReportPage(
        [for (final doc in docs) Report.fromFirestore(doc.id, doc.data())],
        docs.isEmpty ? null : docs.last,
        hasMore: snapshot.docs.length > pageSize,
      );
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<Report> report(String id) async {
    try {
      final snapshot = await _reports.doc(id).get();
      final data = snapshot.data();
      if (data == null) throw const AppException("We couldn't find that report.");
      return Report.fromFirestore(snapshot.id, data);
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<Uint8List?> reportPhoto(String reportId) async {
    try {
      final data = (await _db.collection('reportPhotos').doc(reportId).get()).data();
      final encoded = data?['data'] as String?;
      return encoded == null ? null : base64Decode(encoded);
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// The reporter's name and email, if their profile exists.
  Future<({String name, String email})?> reporter(String uid) async {
    try {
      final data = (await _db.collection('users').doc(uid).get()).data();
      if (data == null) return null;
      return (name: data['fullName'] as String? ?? '', email: data['email'] as String? ?? '');
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<Regulator?> regulatorFor(String country) async {
    try {
      final data = (await _db.collection('healthAuthorities').doc(country).get()).data();
      if (data == null) return null;
      return Regulator(name: data['authorityName'] as String, email: data['email'] as String);
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> applyAction(String reportId, ReportAction action) => _update(reportId, {
        'status': action.result.name,
        if (action.closes) ...{
          'resolvedBy': _auth.currentUser?.uid,
          'resolvedAt': FieldValue.serverTimestamp(),
        },
      });

  Future<void> saveNotes(String reportId, String notes) =>
      _update(reportId, {'adminNotes': notes.trim().isEmpty ? null : notes.trim()});

  Future<void> markRegulatorNotified(String reportId) =>
      _update(reportId, {'regulatorNotifiedAt': FieldValue.serverTimestamp()});

  Future<void> _update(String reportId, Map<String, Object?> changes) async {
    try {
      await _reports.doc(reportId).update({...changes, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<int> unreadReportCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;
    try {
      final lastViewed = (await _db.collection('users').doc(uid).get()).data()?['reportsLastViewedAt'];
      return await _count(
        lastViewed is Timestamp ? _reports.where('createdAt', isGreaterThan: lastViewed) : _reports,
      );
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// Records that this admin has seen the queue, clearing their badge.
  Future<void> markReportsViewed() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).update({'reportsLastViewedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw toAppException(e);
    }
  }
}
