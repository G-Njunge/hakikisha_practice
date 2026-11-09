import 'package:flutter_test/flutter_test.dart';
import 'package:hakikisha/core/geo.dart';
import 'package:hakikisha/models/medicine.dart';
import 'package:hakikisha/models/pharmacy.dart';
import 'package:hakikisha/models/scan_result.dart';

void main() {
  group('evaluateScan', () {
    test('an approved medicine is verified, logged as authentic', () {
      final result = evaluateScan(
        barcode: '6150000000017',
        scanId: 'scan-1',
        medicine: {'name': 'Coartem', 'manufacturer': 'Novartis', 'approvalStatus': 'approved'},
      );

      expect(result.verified, isTrue);
      expect(result.resultCode, 'authentic');
      expect(result.medicine!.id, '6150000000017');
      expect(result.message, isNull);
    });

    test('a medicine not yet approved is unverified, with the reason', () {
      final result = evaluateScan(
        barcode: '6160000000038',
        scanId: 'scan-2',
        medicine: {'name': 'Vibramycin', 'manufacturer': 'Cosmos', 'approvalStatus': 'pending'},
      );

      expect(result.verified, isFalse);
      expect(result.resultCode, 'unknown');
      expect(result.medicine!.approvalStatus, ApprovalStatus.pending);
      expect(result.message, contains('awaiting regulatory approval'));
    });

    test('an unregistered barcode has no medicine', () {
      final result = evaluateScan(barcode: '12345678', scanId: 'scan-3', medicine: null);

      expect(result.verified, isFalse);
      expect(result.medicine, isNull);
      expect(result.message, contains('does not exist'));
    });
  });

  test('distanceKm matches a known distance', () {
    // Kigali city centre (Kipharma) to Kanombe: about 9 km.
    expect(distanceKm(-1.9441, 30.0619, -1.9686, 30.1395), closeTo(9.0, 0.6));
    expect(distanceKm(-1.95, 30.09, -1.95, 30.09), 0);
  });

  group('rankNearbyPharmacies', () {
    PharmacyRecord pharmacy(String id, double lat, double lng, {List<String> stock = const [], String? hours}) =>
        PharmacyRecord(
          id: id,
          name: id,
          address: 'Kigali',
          latitude: lat,
          longitude: lng,
          phone: null,
          hours: hours,
          stockedMedicineIds: stock,
        );

    final monday10am = DateTime.utc(2026, 6, 1, 8);

    test('lists stocking pharmacies first, then nearest first, within the radius', () {
      final results = rankNearbyPharmacies(
        [
          pharmacy('near-no-stock', -1.9500, 30.0900),
          pharmacy('far-stock', -1.9700, 30.1100, stock: ['m1']),
          pharmacy('near-stock', -1.9510, 30.0910, stock: ['m1']),
          pharmacy('out-of-range', -2.5000, 30.5000, stock: ['m1']),
        ],
        lat: -1.95,
        lng: 30.09,
        medicineId: 'm1',
        now: monday10am,
      );

      expect(results.map((p) => p.id), ['near-stock', 'far-stock', 'near-no-stock']);
      expect(results.first.stocksMedicine, isTrue);
      expect(results.last.stocksMedicine, isFalse);
    });

    test('without a medicine, stock is unknown rather than false', () {
      final results = rankNearbyPharmacies([pharmacy('a', -1.95, 30.09)], lat: -1.95, lng: 30.09);
      expect(results.single.stocksMedicine, isNull);
    });

    test('can show only pharmacies open now', () {
      final results = rankNearbyPharmacies(
        [
          pharmacy('open', -1.95, 30.09, hours: 'Daily 07:00-22:00'),
          pharmacy('closed', -1.95, 30.09, hours: 'Mon-Fri 18:00-20:00'),
          pharmacy('unknown', -1.95, 30.09),
        ],
        lat: -1.95,
        lng: 30.09,
        openNowOnly: true,
        now: monday10am,
      );

      expect(results.map((p) => p.id), ['open']);
    });
  });
}
