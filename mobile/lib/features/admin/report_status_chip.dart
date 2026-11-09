import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/report.dart';

/// A report's status as icon + label (never colour alone).
class ReportStatusChip extends StatelessWidget {
  const ReportStatusChip({super.key, required this.status});

  final ReportStatus status;

  static IconData iconFor(ReportStatus status) => switch (status) {
        ReportStatus.pending => Icons.schedule,
        ReportStatus.investigating => Icons.manage_search,
        ReportStatus.escalated => Icons.priority_high,
        ReportStatus.resolved => Icons.check_circle_outline,
        ReportStatus.dismissed => Icons.do_not_disturb_on_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (fg, bg) = switch (status) {
      ReportStatus.pending => (HakikishaColors.warning, HakikishaColors.warningBg),
      ReportStatus.investigating => (scheme.onSecondaryContainer, scheme.secondaryContainer),
      ReportStatus.escalated => (HakikishaColors.danger, HakikishaColors.dangerBg),
      ReportStatus.resolved => (HakikishaColors.green, HakikishaColors.verifiedBg),
      ReportStatus.dismissed => (scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(status), size: 14, color: fg),
          const SizedBox(width: 4),
          Text(status.label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
