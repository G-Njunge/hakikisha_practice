import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/medicine.dart';
import '../pharmacies/nearby_pharmacies.dart';
import '../report/report_screen.dart';
import '../verify/medicine_repository.dart';
import 'approval_chip.dart';
import 'medicine_photos.dart';

/// A medicine's registry entry: details, reference photos, where to buy it,
/// and a way to report a suspicious one. Reached from Search.
class MedicineDetailScreen extends ConsumerWidget {
  const MedicineDetailScreen({super.key, required this.medicineId});

  final String medicineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicine = ref.watch(medicineProvider(medicineId));

    return Scaffold(
      appBar: AppBar(title: Text(medicine.value?.name ?? 'Medicine')),
      body: medicine.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(medicineProvider(medicineId)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (medicine) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DetailsCard(medicine: medicine),
            const SizedBox(height: 24),
            _Heading('Genuine reference photos'),
            MedicinePhotos(medicine: medicine),
            if (medicine.packageVerification.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Heading('How to identify a genuine package'),
              for (final item in medicine.packageVerification)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(item),
                ),
            ],
            const SizedBox(height: 24),
            _Heading('Find it nearby'),
            NearbyPharmacies(medicineId: medicine.id),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => openReportForm(context, ref, ReportTarget(medicineName: medicine.name)),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Report a suspicious pack'),
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rows = [
      ('Generic name', medicine.genericName),
      ('Strength', medicine.strength),
      ('Form', medicine.dosageForm),
      ('Manufacturer', medicine.manufacturer),
      ('Regulator', medicine.regulatoryBody),
      ('Approval no.', medicine.approvalNumber),
      ('Barcode', medicine.barcode),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(medicine.name, style: textTheme.headlineSmall),
            const SizedBox(height: 8),
            ApprovalChip(status: medicine.approvalStatus),
            const SizedBox(height: 12),
            for (final (label, value) in rows)
              if (value != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 112,
                        child: Text(label, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Expanded(child: Text(value, style: textTheme.bodyMedium)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
