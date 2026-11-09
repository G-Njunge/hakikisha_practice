import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/errors.dart';
import '../../core/location.dart';
import '../../models/pharmacy.dart';
import '../verify/medicine_repository.dart';
import 'pharmacy_widgets.dart';

/// Finds pharmacies near the user that stock [medicineId]: asks for location
/// on demand, then shows them on a map and as a nearest-first list. Used
/// inside the verification flow and on a medicine's detail screen.
class NearbyPharmacies extends ConsumerStatefulWidget {
  const NearbyPharmacies({super.key, required this.medicineId});

  final String medicineId;

  @override
  ConsumerState<NearbyPharmacies> createState() => _NearbyPharmaciesState();
}

class _NearbyPharmaciesState extends ConsumerState<NearbyPharmacies> {
  bool _loading = false;
  String? _error;
  bool _settingsHint = false;
  Position? _position;
  List<NearbyPharmacy>? _pharmacies;

  Future<void> _find() async {
    setState(() {
      _loading = true;
      _error = null;
      _settingsHint = false;
    });
    try {
      final position = await currentPosition();
      final pharmacies = await ref.read(medicineRepositoryProvider).nearbyPharmacies(
            lat: position.latitude,
            lng: position.longitude,
            medicineId: widget.medicineId,
          );
      setState(() {
        _position = position;
        _pharmacies = pharmacies;
      });
    } on LocationException catch (e) {
      setState(() {
        _error = e.message;
        _settingsHint = e.problem == LocationProblem.deniedForever;
      });
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pharmacies = _pharmacies;
    final position = _position;

    if (pharmacies == null || position == null) {
      return LocationPrompt(
        message: 'Buy from a licensed pharmacy. Share your location to see which nearby pharmacies stock this medicine.',
        loading: _loading,
        error: _error,
        showSettings: _settingsHint,
        onFind: _find,
      );
    }

    if (pharmacies.isEmpty) {
      return const IconMessage(
        icon: Icons.storefront_outlined,
        text: 'No pharmacies within 10 km have this medicine confirmed in stock.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 240,
            child: PharmacyMap(latitude: position.latitude, longitude: position.longitude, pharmacies: pharmacies),
          ),
        ),
        const SizedBox(height: 16),
        for (final pharmacy in pharmacies) PharmacyCard(pharmacy: pharmacy),
      ],
    );
  }
}

/// Explains why location is needed, with a button to share it.
class LocationPrompt extends StatelessWidget {
  const LocationPrompt({
    super.key,
    required this.message,
    required this.loading,
    required this.error,
    required this.showSettings,
    required this.onFind,
  });

  final String message;
  final bool loading;
  final String? error;
  final bool showSettings;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IconMessage(icon: Icons.location_on_outlined, text: message),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: loading ? null : onFind,
          icon: loading
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location),
          label: const Text('Find pharmacies near me'),
        ),
        if (showSettings) TextButton(onPressed: Geolocator.openAppSettings, child: const Text('Open Settings')),
      ],
    );
  }
}

class IconMessage extends StatelessWidget {
  const IconMessage({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}
