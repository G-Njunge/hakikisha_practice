import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/medicine.dart';

/// A medicine's regulatory approval status, as an icon and label (never
/// colour alone).
class ApprovalChip extends StatelessWidget {
  const ApprovalChip({super.key, required this.status});

  final ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, fg, bg) = switch (status) {
      ApprovalStatus.approved => (Icons.verified, HakikishaColors.green, HakikishaColors.verifiedBg),
      ApprovalStatus.pending => (Icons.hourglass_top, HakikishaColors.warning, HakikishaColors.warningBg),
      ApprovalStatus.rejected ||
      ApprovalStatus.expired => (Icons.gpp_bad_outlined, HakikishaColors.danger, HakikishaColors.dangerBg),
      ApprovalStatus.unknown => (Icons.help_outline, HakikishaColors.warning, HakikishaColors.warningBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(status.label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
