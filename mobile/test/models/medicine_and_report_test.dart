import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakikisha/features/admin/admin_repository.dart';
import 'package:hakikisha/models/medicine.dart';
import 'package:hakikisha/models/report.dart';

Medicine medicine(String name, {String? generic}) => Medicine(
      id: name,
      name: name,
      genericName: generic,
      manufacturer: 'Maker',
      dosageForm: 'tablet',
      strength: null,
      barcode: name,
      regulatoryBody: 'Rwanda FDA',
      approvalNumber: '1',
      approvalStatus: ApprovalStatus.approved,
    );

void main() {
  group('searchMedicines', () {
    final catalog = [
      medicine('Coartem', generic: 'Artemether-Lumefantrine'),
      medicine('Lumartem', generic: 'Artemether-Lumefantrine'),
      medicine('Panadol', generic: 'Paracetamol'),
      medicine('Amoxil', generic: 'Amoxicillin'),
    ];

    test('ranks name prefix, then name contains, then generic name', () {
      expect(searchMedicines(catalog, 'art').map((m) => m.name), ['Coartem', 'Lumartem']);
      expect(searchMedicines(catalog, 'lum').map((m) => m.name), ['Lumartem', 'Coartem']);
    });

    test('is case-insensitive and ignores surrounding spaces', () {
      expect(searchMedicines(catalog, '  PARACET ').map((m) => m.name), ['Panadol']);
    });

    test('returns nothing for an empty query or no match', () {
      expect(searchMedicines(catalog, ''), isEmpty);
      expect(searchMedicines(catalog, 'zzz'), isEmpty);
    });
  });

  test('photos resolve to bundled assets, and missing ones stay null', () {
    final m = Medicine.fromFirestore('123', {
      'name': 'Panadol',
      'manufacturer': 'GSK',
      'regulatoryBody': 'NAFDAC',
      'approvalNumber': 'A4-1003',
      'approvalStatus': 'approved',
      'photos': {'package': 'panadol-package.jpeg', 'tablet': null},
      'packageVerification': ['Seal intact'],
    });

    expect(m.packagePhotoAsset, 'assets/medicines/panadol-package.jpeg');
    expect(m.tabletPhotoAsset, isNull);
    expect(m.packageVerification, ['Seal intact']);
    expect(m.barcode, '123');
  });

  group('report workflow', () {
    test('moves forward only, and closed reports have no actions', () {
      expect(availableActions(ReportStatus.pending), ReportAction.values);
      expect(availableActions(ReportStatus.investigating), isNot(contains(ReportAction.review)));
      expect(availableActions(ReportStatus.escalated), [ReportAction.approve, ReportAction.dismiss]);
      expect(availableActions(ReportStatus.resolved), isEmpty);
      expect(availableActions(ReportStatus.dismissed), isEmpty);
    });

    test('only approve and dismiss close a report', () {
      expect(ReportAction.values.where((a) => a.closes), [ReportAction.approve, ReportAction.dismiss]);
    });
  });

  test('the regulator email carries the report details', () {
    final report = Report.fromFirestore('rep-1', {
      'productName': 'Coartem 20/120',
      'description': 'Seal was broken',
      'country': 'Rwanda',
      'purchaseLocation': 'Kimironko market',
      'hasPhoto': true,
      'status': 'pending',
      'createdAt': Timestamp.fromDate(DateTime(2026, 10, 24, 12)),
    });

    final email = regulatorEmail(report);

    expect(email.subject, 'Counterfeit medicine report: Coartem 20/120');
    for (final part in ['Coartem 20/120', 'Rwanda', 'Kimironko market', '24 Oct 2026', 'Seal was broken', 'rep-1']) {
      expect(email.body, contains(part));
    }
  });

  group('admin stats helpers', () {
    test('lastDays gives the last 7 local days, oldest first, ending today', () {
      final days = lastDays(DateTime(2026, 3, 2, 15, 30));
      expect(days, hasLength(7));
      expect(days.first, DateTime(2026, 2, 24));
      expect(days.last, DateTime(2026, 3, 2));
    });

    test('rankByFrequency counts names, skipping unregistered scans', () {
      final ranked = rankByFrequency(['Panadol', null, 'Coartem', 'Panadol', null, 'Amoxil', 'Coartem', 'Panadol'],
          limit: 2);
      expect(ranked, [(name: 'Panadol', count: 3), (name: 'Coartem', count: 2)]);
    });
  });
}
