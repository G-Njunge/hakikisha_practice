import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/medicine.dart';
import '../../models/scan_result.dart';
import '../medicine/medicine_photos.dart';
import '../pharmacies/nearby_pharmacies.dart';
import '../report/report_screen.dart';
import 'medicine_repository.dart';

/// The guided check after a scan: result → reference photos → package
/// checklist → where to buy it. An unknown barcode stops at the result.
class VerifyFlowScreen extends StatefulWidget {
  const VerifyFlowScreen({super.key, required this.result});

  final ScanResult result;

  @override
  State<VerifyFlowScreen> createState() => _VerifyFlowScreenState();
}

class _VerifyFlowScreenState extends State<VerifyFlowScreen> {
  final _pages = PageController();
  int _step = 0;

  static const _titles = ['Result', 'Compare photos', 'Check the package', 'Where to buy'];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    _pages.animateToPage(step, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final medicine = widget.result.medicine;

    if (medicine == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ResultCard(result: widget.result),
            const SizedBox(height: 16),
            _ReportButton(target: ReportTarget(scanId: widget.result.scanId)),
          ],
        ),
        bottomNavigationBar: _BottomBar(
          primaryLabel: 'Scan another',
          onPrimary: () => Navigator.of(context).pop(),
        ),
      );
    }

    final steps = [
      _ResultStep(result: widget.result),
      _PhotosStep(medicineId: medicine.id),
      _ChecklistStep(medicineId: medicine.id),
      _KeepAlive(child: _StepScroll(children: [NearbyPharmacies(medicineId: medicine.id)])),
    ];
    final isLast = _step == steps.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_step]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Text('Step ${_step + 1} of ${steps.length}', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(width: 12),
                Expanded(child: LinearProgressIndicator(value: (_step + 1) / steps.length)),
              ],
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pages,
        onPageChanged: (step) => setState(() => _step = step),
        children: steps,
      ),
      bottomNavigationBar: _BottomBar(
        secondaryLabel: _step == 0 ? null : 'Back',
        onSecondary: () => _goTo(_step - 1),
        primaryLabel: isLast ? 'Done' : 'Next',
        onPrimary: isLast ? () => Navigator.of(context).pop() : () => _goTo(_step + 1),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.primaryLabel, required this.onPrimary, this.secondaryLabel, this.onSecondary});

  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            if (secondaryLabel != null) ...[
              Expanded(child: OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel!))),
              const SizedBox(width: 12),
            ],
            Expanded(child: FilledButton(onPressed: onPrimary, child: Text(primaryLabel))),
          ],
        ),
      ),
    );
  }
}

/// PageView disposes off-screen pages; this keeps a step's state (e.g. found
/// pharmacies) when the user pages back and forth.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _StepScroll extends StatelessWidget {
  const _StepScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: children);
  }
}

// --- Step 1: result -----------------------------------------------------

class _ResultStep extends StatelessWidget {
  const _ResultStep({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(children: [
      _ResultCard(result: result),
      const SizedBox(height: 16),
      Text(
        "Next, compare what's in your hand with reference photos and a genuine-package checklist.",
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      _ReportButton(target: ReportTarget(scanId: result.scanId, medicineName: result.medicine?.name)),
    ]);
  }
}

class _ReportButton extends ConsumerWidget {
  const _ReportButton({required this.target});

  final ReportTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () => openReportForm(context, ref, target),
      icon: const Icon(Icons.flag_outlined),
      label: const Text('Report as suspicious'),
      style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final medicine = result.medicine;

    final (icon, title, fg, bg) = switch ((medicine, result.verified)) {
      (null, _) => (Icons.help_outline, 'Unknown product', HakikishaColors.danger, HakikishaColors.dangerBg),
      (_, true) => (Icons.verified, 'Registered medicine', HakikishaColors.green, HakikishaColors.verifiedBg),
      (_, false) => (Icons.warning_amber_rounded, 'Use caution', HakikishaColors.warning, HakikishaColors.warningBg),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: bg,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 32),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: textTheme.titleLarge?.copyWith(color: fg))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (medicine != null) ...[
                  Text(medicine.name, style: textTheme.headlineSmall),
                  Text(medicine.manufacturer, style: textTheme.bodyLarge),
                  const SizedBox(height: 12),
                  _Detail(label: 'Approval', value: medicine.approvalStatus.label),
                  if (result.batchNumber != null) _Detail(label: 'Batch', value: result.batchNumber!),
                  if (result.expiryDate != null) _Detail(label: 'Expires', value: _formatDate(result.expiryDate!)),
                ],
                _Detail(label: 'Barcode', value: result.barcode),
                if (result.message != null) ...[
                  const SizedBox(height: 12),
                  Text(result.message!, style: textTheme.bodyLarge),
                ],
                if (medicine == null) ...[
                  const SizedBox(height: 12),
                  Text(
                    "This doesn't necessarily mean it's counterfeit — it isn't in our registry yet. "
                    'Ask a pharmacist before using it.',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Text(label, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

// --- Steps 2 & 3: reference photos and checklist ------------------------

/// Shared loading/error handling for the steps backed by the medicine's
/// registry entry (both read the same cached request).
class _ProfileStep extends ConsumerWidget {
  const _ProfileStep({required this.medicineId, required this.builder});

  final String medicineId;
  final List<Widget> Function(BuildContext context, Medicine medicine) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicine = ref.watch(medicineProvider(medicineId));
    return medicine.when(
      data: (medicine) => _StepScroll(children: builder(context, medicine)),
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
    );
  }
}

class _PhotosStep extends StatelessWidget {
  const _PhotosStep({required this.medicineId});

  final String medicineId;

  @override
  Widget build(BuildContext context) {
    return _ProfileStep(
      medicineId: medicineId,
      builder: (context, medicine) => [
        Text(
          'Compare the pack and tablets in your hand with these genuine ${medicine.name} references.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        MedicinePhotos(medicine: medicine),
      ],
    );
  }
}

class _ChecklistStep extends StatefulWidget {
  const _ChecklistStep({required this.medicineId});

  final String medicineId;

  @override
  State<_ChecklistStep> createState() => _ChecklistStepState();
}

class _ChecklistStepState extends State<_ChecklistStep> with AutomaticKeepAliveClientMixin {
  final _checked = <int>{};

  // Keeps ticks when paging back and forth.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _ProfileStep(
      medicineId: widget.medicineId,
      builder: (context, medicine) {
        final items = medicine.packageVerification;
        if (items.isEmpty) {
          return [const Text('There is no package checklist for this medicine yet.')];
        }
        return [
          Text('Tick each point that matches the package in your hand.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          for (final (i, item) in items.indexed)
            CheckboxListTile(
              value: _checked.contains(i),
              onChanged: (on) => setState(() => on == true ? _checked.add(i) : _checked.remove(i)),
              title: Text(item),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          const SizedBox(height: 8),
          if (_checked.length == items.length)
            const Text('Everything matches. Still buy only from a licensed pharmacy.')
          else
            const Text("If anything doesn't match, don't use the medicine and ask a pharmacist."),
        ];
      },
    );
  }
}
