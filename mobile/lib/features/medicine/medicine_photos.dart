import 'package:flutter/material.dart';

import '../../models/medicine.dart';

/// A medicine's genuine reference photos (package, then tablets), from the
/// app's bundled assets.
class MedicinePhotos extends StatelessWidget {
  const MedicinePhotos({super.key, required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final photos = [
      if (medicine.packagePhotoAsset case final asset?) ('Package', asset),
      if (medicine.tabletPhotoAsset case final asset?) ('Tablets', asset),
    ];
    if (photos.isEmpty) {
      return const Text('Reference photos for this medicine are not available yet.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, asset) in photos) ...[
          Text(label, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              // A photo newer than this build of the app isn't bundled yet.
              errorBuilder: (context, _, _) => const SizedBox(
                height: 120,
                child: Center(child: Text('Update the app to see this photo.')),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
