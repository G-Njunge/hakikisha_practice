import '../core/geo.dart';
import '../core/opening_hours.dart';

/// A pharmacy near the user, with distance and opening status worked out.
class NearbyPharmacy {
  const NearbyPharmacy({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.hours,
    required this.distanceKm,
    required this.stocksMedicine,
    required this.isOpenNow,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;
  final String? hours;
  final double distanceKm;

  /// Null when the search wasn't for a specific medicine.
  final bool? stocksMedicine;

  /// Null when the pharmacy's hours are missing or unparseable — "unknown",
  /// not "closed".
  final bool? isOpenNow;
}

/// A `pharmacies` document as read from Firestore.
class PharmacyRecord {
  const PharmacyRecord({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.hours,
    required this.stockedMedicineIds,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;
  final String? hours;
  final List<String> stockedMedicineIds;
}

/// Pharmacies within [radiusKm] of the user: ones stocking [medicineId] first,
/// then nearest first — the ordering the old API's SQL used.
List<NearbyPharmacy> rankNearbyPharmacies(
  Iterable<PharmacyRecord> pharmacies, {
  required double lat,
  required double lng,
  String? medicineId,
  double radiusKm = 10,
  bool openNowOnly = false,
  DateTime? now,
}) {
  final results = <NearbyPharmacy>[];
  for (final p in pharmacies) {
    final distance = distanceKm(lat, lng, p.latitude, p.longitude);
    if (distance > radiusKm) continue;
    final open = isOpenNow(p.hours, at: now);
    if (openNowOnly && open != true) continue;
    results.add(NearbyPharmacy(
      id: p.id,
      name: p.name,
      address: p.address,
      latitude: p.latitude,
      longitude: p.longitude,
      phone: p.phone,
      hours: p.hours,
      distanceKm: (distance * 10).round() / 10,
      stocksMedicine: medicineId == null ? null : p.stockedMedicineIds.contains(medicineId),
      isOpenNow: open,
    ));
  }
  results.sort((a, b) {
    final stock = (b.stocksMedicine == true ? 1 : 0) - (a.stocksMedicine == true ? 1 : 0);
    return stock != 0 ? stock : a.distanceKm.compareTo(b.distanceKm);
  });
  return results;
}
