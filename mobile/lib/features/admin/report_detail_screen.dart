import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors.dart';
import '../../models/report.dart';
import 'admin_repository.dart';
import 'report_status_chip.dart';

/// One report, for an admin to work: read it (with photo and reporter), email
/// the regulator, keep notes, and move it through review to a decision.
class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportProvider(reportId));
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: report.when(
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
                  onPressed: () => ref.invalidate(reportProvider(reportId)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (report) => _ReportBody(report: report),
      ),
    );
  }
}

class _ReportBody extends ConsumerStatefulWidget {
  const _ReportBody({required this.report});

  final Report report;

  @override
  ConsumerState<_ReportBody> createState() => _ReportBodyState();
}

class _ReportBodyState extends ConsumerState<_ReportBody> {
  late final _notes = TextEditingController(text: widget.report.adminNotes ?? '');
  bool _busy = false;

  Report get report => widget.report;
  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// Runs an update, then reloads the report so the screen shows the result.
  Future<void> _run(Future<void> Function() update, {String? done}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await update();
      ref.invalidate(reportProvider(report.id));
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply(ReportAction action) async {
    if (action.closes) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${action.label}?'),
          content: Text('This closes the report as "${action.result.label}". It can\'t be reopened.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action.label)),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _run(() => _repo.applyAction(report.id, action), done: 'Report marked ${action.result.label.toLowerCase()}.');
  }

  /// No server on the free plan: open the admin's mail app with the alert
  /// written out, then record that the regulator was told.
  Future<void> _emailRegulator(Regulator regulator) async {
    final email = regulatorEmail(report);
    final uri = Uri(
      scheme: 'mailto',
      path: regulator.email,
      // Built by hand: Uri's queryParameters encodes spaces as "+", which
      // mail apps show literally.
      query: 'subject=${Uri.encodeComponent(email.subject)}&body=${Uri.encodeComponent(email.body)}',
    );
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No email app found. Email ${regulator.email} directly.')),
        );
      }
      return;
    }
    if (!mounted) return;
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Did you send it?'),
        content: Text('Mark this report as sent to ${regulator.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, sent')),
        ],
      ),
    );
    if (sent == true) await _run(() => _repo.markRegulatorNotified(report.id));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final actions = availableActions(report.status);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(report.displayName, style: textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ReportStatusChip(status: report.status),
            if (report.createdAt != null) Text('Filed ${formatDate(report.createdAt!)}', style: textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 16),
        _Field(label: 'Country', value: report.country),
        if (report.purchaseLocation != null) _Field(label: 'Where bought', value: report.purchaseLocation!),
        if (report.productName != null && report.productName != report.displayName)
          _Field(label: 'Name given', value: report.productName!),
        _Field(label: 'From a scan', value: report.scanId == null ? 'No' : 'Yes (${report.scanId})'),
        if (report.reportedBy != null) _Reporter(uid: report.reportedBy!),
        const SizedBox(height: 8),
        Text('Description', style: textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(report.description, style: textTheme.bodyLarge),
        if (report.hasPhoto) ...[
          const SizedBox(height: 16),
          Text('Photo', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          _Photo(reportId: report.id),
        ],
        const Divider(height: 40),
        Text('Regulator', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        _RegulatorSection(
          report: report,
          busy: _busy,
          onEmail: _emailRegulator,
        ),
        const Divider(height: 40),
        Text('Notes', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Visible to admins only'),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : () => _run(() => _repo.saveNotes(report.id, _notes.text), done: 'Notes saved.'),
            child: const Text('Save notes'),
          ),
        ),
        if (actions.isNotEmpty) ...[
          const Divider(height: 40),
          Text('Decision', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in actions)
                action.closes
                    ? FilledButton.tonal(onPressed: _busy ? null : () => _apply(action), child: Text(action.label))
                    : OutlinedButton(onPressed: _busy ? null : () => _apply(action), child: Text(action.label)),
            ],
          ),
        ] else if (report.resolvedAt != null) ...[
          const SizedBox(height: 16),
          Text('Closed ${formatDate(report.resolvedAt!)}.', style: textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
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
    );
  }
}

class _Reporter extends ConsumerWidget {
  const _Reporter({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = switch (ref.watch(reporterProvider(uid))) {
      AsyncData(value: final reporter?) => '${reporter.name} (${reporter.email})',
      AsyncData() || AsyncError() => 'Unknown account',
      _ => 'Loading…',
    };
    return _Field(label: 'Reported by', value: value);
  }
}

class _Photo extends ConsumerWidget {
  const _Photo({required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(reportPhotoProvider(reportId))) {
      AsyncData(value: final bytes?) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      AsyncData() || AsyncError() => const Text("The photo couldn't be loaded."),
      _ => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
    };
  }
}

class _RegulatorSection extends ConsumerWidget {
  const _RegulatorSection({required this.report, required this.busy, required this.onEmail});

  final Report report;
  final bool busy;
  final ValueChanged<Regulator> onEmail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regulator = ref.watch(regulatorProvider(report.country));
    return switch (regulator) {
      AsyncData(value: final regulator?) => _details(context, regulator),
      AsyncData() => Text('No regulator on file for ${report.country}.'),
      AsyncError(:final error) => Text('$error'),
      _ => const LinearProgressIndicator(),
    };
  }

  Widget _details(BuildContext context, Regulator regulator) {
    final notified = report.regulatorNotifiedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${regulator.name} · ${regulator.email}'),
        const SizedBox(height: 4),
        Text(
          notified == null ? 'Not emailed yet.' : 'Emailed ${formatDate(notified)}.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : () => onEmail(regulator),
          icon: const Icon(Icons.mail_outline),
          label: Text(notified == null ? 'Email regulator' : 'Email regulator again'),
        ),
      ],
    );
  }
}
