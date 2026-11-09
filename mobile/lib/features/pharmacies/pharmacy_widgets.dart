import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../models/pharmacy.dart';

/// OpenStreetMap with the user's position and pharmacy pins, framed to fit
/// them all. Tapping a pin calls [onTapPharmacy].
class PharmacyMap extends StatelessWidget {
  const PharmacyMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.pharmacies,
    this.onTapPharmacy,
  });

  final double latitude;
  final double longitude;
  final List<NearbyPharmacy> pharmacies;
  final ValueChanged<NearbyPharmacy>? onTapPharmacy;

  @override
  Widget build(BuildContext context) {
    final me = LatLng(latitude, longitude);
    final points = [me, ...pharmacies.map((p) => LatLng(p.latitude, p.longitude))];

    return FlutterMap(
      // Re-frame when the result set changes (e.g. a filter is toggled).
      key: ValueKey(Object.hashAll(pharmacies.map((p) => p.id))),
      options: MapOptions(
        initialCameraFit: points.length > 1
            ? CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(40), maxZoom: 16)
            : null,
        initialCenter: me,
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.hakikisha.hakikisha',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: me,
              width: 20,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
            for (final p in pharmacies)
              Marker(
                point: LatLng(p.latitude, p.longitude),
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: onTapPharmacy == null ? null : () => onTapPharmacy!(p),
                  child: Tooltip(
                    message: p.name,
                    child: const Icon(Icons.location_on, color: HakikishaColors.green, size: 40),
                  ),
                ),
              ),
          ],
        ),
        const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
      ],
    );
  }
}

/// A pharmacy's name, distance, address, opening status, and buttons for
/// directions and calling.
class PharmacyCard extends StatelessWidget {
  const PharmacyCard({super.key, required this.pharmacy, this.margin = const EdgeInsets.only(bottom: 12)});

  final NearbyPharmacy pharmacy;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final phone = pharmacy.phone;

    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(pharmacy.name, style: textTheme.titleMedium)),
                Text('${pharmacy.distanceKm.toStringAsFixed(1)} km', style: textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 4),
            Text(pharmacy.address, style: textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OpenStatusChip(isOpenNow: pharmacy.isOpenNow),
                if (pharmacy.stocksMedicine == true) const _InStockChip(),
                if (pharmacy.hours != null) Text(pharmacy.hours!, style: textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              children: [
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.https('www.google.com', '/maps/dir/', {
                      'api': '1',
                      'destination': '${pharmacy.latitude},${pharmacy.longitude}',
                    }),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.directions),
                  label: const Text('Directions'),
                ),
                if (phone != null)
                  TextButton.icon(
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OpenStatusChip extends StatelessWidget {
  const OpenStatusChip({super.key, required this.isOpenNow});

  final bool? isOpenNow;

  @override
  Widget build(BuildContext context) {
    final (label, icon, fg, bg) = switch (isOpenNow) {
      true => ('Open now', Icons.schedule, HakikishaColors.green, HakikishaColors.verifiedBg),
      false => ('Closed', Icons.block, HakikishaColors.danger, HakikishaColors.dangerBg),
      null => ('Hours unknown', Icons.help_outline, HakikishaColors.warning, HakikishaColors.warningBg),
    };
    return _Chip(label: label, icon: icon, foreground: fg, background: bg);
  }
}

class _InStockChip extends StatelessWidget {
  const _InStockChip();

  @override
  Widget build(BuildContext context) => const _Chip(
        label: 'In stock',
        icon: Icons.inventory_2_outlined,
        foreground: HakikishaColors.green,
        background: HakikishaColors.verifiedBg,
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon, required this.foreground, required this.background});

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: foreground, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
