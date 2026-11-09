import 'dart:math';

const _earthRadiusKm = 6371.0;

/// Great-circle distance in km (haversine), as the old API computed in SQL.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  double rad(double degrees) => degrees * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = pow(sin(dLat / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLng / 2), 2);
  return _earthRadiusKm * 2 * asin(sqrt(a));
}
