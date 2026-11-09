import 'package:geolocator/geolocator.dart';

/// Why the device's location couldn't be read, so the UI can say what to do.
enum LocationProblem { servicesOff, denied, deniedForever, unavailable }

class LocationException implements Exception {
  const LocationException(this.problem);

  final LocationProblem problem;

  String get message => switch (problem) {
        LocationProblem.servicesOff => 'Turn on location services to find pharmacies near you.',
        LocationProblem.denied => 'Allow location access to find pharmacies near you.',
        LocationProblem.deniedForever =>
          'Location access is turned off for Hakikisha. Enable it in Settings to find pharmacies near you.',
        LocationProblem.unavailable => "We couldn't get your location. Please try again.",
      };
}

/// Asks for permission if needed and returns the current position.
Future<Position> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationException(LocationProblem.servicesOff);
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    throw const LocationException(LocationProblem.denied);
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationException(LocationProblem.deniedForever);
  }

  try {
    return await Geolocator.getCurrentPosition(
      // Neighbourhood-level accuracy is plenty for "pharmacies within 10 km"
      // and returns much faster than a GPS fix.
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
  } catch (_) {
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) return lastKnown;
    throw const LocationException(LocationProblem.unavailable);
  }
}
