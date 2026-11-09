import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/errors.dart';
import '../../core/location.dart';
import '../../models/medicine.dart';
import '../../models/pharmacy.dart';
import '../verify/medicine_repository.dart';
import 'nearby_pharmacies.dart';
import 'pharmacy_widgets.dart';

const _radiusOptions = [5.0, 10.0, 25.0];

/// The Pharmacies tab: nearby pharmacies, optionally only those stocking a
/// chosen medicine. Open ones only by default, since that's what someone
/// standing in the street needs; closed ones are a tap away.
class PharmaciesScreen extends ConsumerStatefulWidget {
  const PharmaciesScreen({super.key});

  @override
  ConsumerState<PharmaciesScreen> createState() => _PharmaciesScreenState();
}

class _PharmaciesScreenState extends ConsumerState<PharmaciesScreen> {
  Medicine? _medicine;
  bool _openNowOnly = true;
  double _radiusKm = 10;

  Position? _position;
  List<NearbyPharmacy>? _results;
  bool _locating = false;
  bool _searching = false;
  String? _error;
  bool _settingsHint = false;
  int _request = 0;

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
      _settingsHint = false;
    });
    try {
      _position = await currentPosition();
      await _search();
    } on LocationException catch (e) {
      setState(() {
        _error = e.message;
        _settingsHint = e.problem == LocationProblem.deniedForever;
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Re-runs the search for the current filters. Older requests that finish
  /// late are ignored, so quick filter changes can't show stale results.
  Future<void> _search() async {
    final position = _position;
    if (position == null) return;
    final request = ++_request;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await ref.read(medicineRepositoryProvider).nearbyPharmacies(
            lat: position.latitude,
            lng: position.longitude,
            medicineId: _medicine?.id,
            radiusKm: _radiusKm,
            openNow: _openNowOnly,
          );
      if (mounted && request == _request) setState(() => _results = results);
    } on AppException catch (e) {
      if (mounted && request == _request) setState(() => _error = e.message);
    } finally {
      if (mounted && request == _request) setState(() => _searching = false);
    }
  }

  void _update(VoidCallback change) {
    setState(change);
    _search();
  }

  void _showPharmacy(NearbyPharmacy pharmacy) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: PharmacyCard(pharmacy: pharmacy, margin: EdgeInsets.zero),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacies'),
        actions: [
          if (_position != null)
            IconButton(
              tooltip: 'Update my location',
              onPressed: _locating ? null : _locate,
              icon: const Icon(Icons.my_location),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _MedicinePicker(
              selected: _medicine,
              onSelected: (medicine) => _update(() => _medicine = medicine),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Open now'),
                  selected: _openNowOnly,
                  onSelected: (on) => _update(() => _openNowOnly = on),
                ),
                const SizedBox(width: 8),
                for (final radius in _radiusOptions) ...[
                  ChoiceChip(
                    label: Text('${radius.round()} km'),
                    selected: _radiusKm == radius,
                    onSelected: (_) => _update(() => _radiusKm = radius),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (_searching) const LinearProgressIndicator(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    final position = _position;
    final results = _results;

    if (position == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: LocationPrompt(
          message: 'Share your location to see licensed pharmacies near you, and which ones have your medicine.',
          loading: _locating,
          error: _error,
          showSettings: _settingsHint,
          onFind: _locate,
        ),
      );
    }

    if (results == null) {
      return _error == null
          ? const Center(child: CircularProgressIndicator())
          : _ErrorRetry(message: _error!, onRetry: _search);
    }

    if (results.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            IconMessage(icon: Icons.storefront_outlined, text: _emptyMessage()),
            const SizedBox(height: 16),
            if (_openNowOnly)
              OutlinedButton(
                onPressed: () => _update(() => _openNowOnly = false),
                child: const Text('Include closed pharmacies'),
              ),
            if (_radiusKm < _radiusOptions.last) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _update(() => _radiusKm = _radiusOptions.last),
                child: Text('Search within ${_radiusOptions.last.round()} km'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PharmacyMap(
            latitude: position.latitude,
            longitude: position.longitude,
            pharmacies: results,
            onTapPharmacy: _showPharmacy,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(_summary(results.length), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final pharmacy in results) PharmacyCard(pharmacy: pharmacy),
            ],
          ),
        ),
      ],
    );
  }

  String _summary(int count) {
    final what = count == 1 ? 'pharmacy' : 'pharmacies';
    final open = _openNowOnly ? ' open now' : '';
    final stock = _medicine == null ? '' : ' with ${_medicine!.name} in stock';
    return '$count $what$open$stock within ${_radiusKm.round()} km';
  }

  String _emptyMessage() {
    final open = _openNowOnly ? 'open ' : '';
    final stock = _medicine == null ? '' : ' with ${_medicine!.name} in stock';
    return 'No ${open}pharmacies$stock within ${_radiusKm.round()} km.';
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// Type-ahead over the registry. Empty means "any pharmacy".
class _MedicinePicker extends ConsumerStatefulWidget {
  const _MedicinePicker({required this.selected, required this.onSelected});

  final Medicine? selected;
  final ValueChanged<Medicine?> onSelected;

  @override
  ConsumerState<_MedicinePicker> createState() => _MedicinePickerState();
}

class _MedicinePickerState extends ConsumerState<_MedicinePicker> {
  TextEditingController? _field;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(medicineCatalogProvider).value ?? const <Medicine>[];

    return Autocomplete<Medicine>(
      displayStringForOption: (m) => m.name,
      optionsBuilder: (value) => searchMedicines(catalog, value.text),
      onSelected: (medicine) {
        FocusScope.of(context).unfocus();
        widget.onSelected(medicine);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        _field = controller;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Medicine (optional)',
            hintText: 'Show only pharmacies that stock it',
            prefixIcon: const Icon(Icons.medication_outlined),
            suffixIcon: widget.selected == null
                ? null
                : IconButton(
                    tooltip: 'Any medicine',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _field?.clear();
                      widget.onSelected(null);
                    },
                  ),
          ),
        );
      },
    );
  }
}
