import 'dart:math';

import 'package:flutter/material.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Scans per day as a single-series bar chart: one hue (no legend needed;
/// the section title names it), thin bars with rounded tops anchored to the
/// baseline, a muted axis, and today's value labelled directly. Tap a bar for
/// its exact count; screen readers get a one-line summary.
class DailyScansChart extends StatelessWidget {
  const DailyScansChart({super.key, required this.days});

  final List<({DateTime day, int count})> days;

  static String _dayLabel(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bar = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: muted);
    final maxCount = days.fold(0, (m, d) => max(m, d.count));
    final total = days.fold(0, (sum, d) => sum + d.count);

    return Semantics(
      label: 'Scans per day for the last ${days.length} days: '
          '${days.map((d) => '${_dayLabel(d.day)}, ${d.count}').join('; ')}. Total $total.',
      excludeSemantics: true,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Baseline: recessive, so the bars carry the eye.
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
                ),
                if (maxCount == 0)
                  Center(child: Text('No scans in the last ${days.length} days', style: theme.textTheme.bodyMedium)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (i, d) in days.indexed)
                      Expanded(
                        child: Tooltip(
                          message: '${_dayLabel(d.day)}: ${d.count} ${d.count == 1 ? 'scan' : 'scans'}',
                          triggerMode: TooltipTriggerMode.tap,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const labelSpace = 18.0;
                              final usable = constraints.maxHeight - labelSpace;
                              final height = maxCount == 0 ? 0.0 : usable * d.count / maxCount;
                              final isToday = i == days.length - 1;
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Selective direct label: today's count only.
                                  if (isToday && maxCount > 0)
                                    SizedBox(
                                      height: labelSpace,
                                      child: Text('${d.count}', style: theme.textTheme.labelMedium),
                                    ),
                                  Container(
                                    width: 16,
                                    // A zero day keeps a sliver so the slot reads as "measured, none".
                                    height: d.count == 0 ? 0 : max(height, 2),
                                    decoration: BoxDecoration(
                                      color: bar,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final d in days)
                Expanded(child: Text(_weekdays[d.day.weekday - 1], style: labelStyle, textAlign: TextAlign.center)),
            ],
          ),
        ],
      ),
    );
  }
}
