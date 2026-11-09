import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../models/report.dart';
import 'admin_repository.dart';
import 'daily_scans_chart.dart';
import 'report_status_chip.dart';

/// The Admin tab (admins only): platform stats and the counterfeit report
/// queue.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this)..addListener(_onTabChanged);

  void _onTabChanged() {
    // Opening the queue counts as seeing the new reports.
    if (_tabs.index == 1 && !_tabs.indexIsChanging) _markReportsViewed();
  }

  Future<void> _markReportsViewed() async {
    try {
      await ref.read(adminRepositoryProvider).markReportsViewed();
      ref.invalidate(unreadReportsProvider);
    } on AppException {
      // Only the badge depends on this; it'll catch up next time.
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadReportsProvider).value ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(text: 'Overview'),
            Tab(
              child: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Reports')),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: const [_Overview(), _ReportQueue()]),
    );
  }
}

// --- Overview ----------------------------------------------------------------

class _Overview extends ConsumerWidget {
  const _Overview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminStatsProvider.future),
      child: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => ref.invalidate(adminStatsProvider), child: const Text('Try again')),
          ],
        ),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatTile(label: 'Scans', value: stats.scans, icon: Icons.qr_code_scanner),
                _StatTile(label: 'Reports', value: stats.reports, icon: Icons.flag_outlined),
                _StatTile(label: 'Users', value: stats.users, icon: Icons.people_outline),
                _StatTile(label: 'Medicines', value: stats.medicines, icon: Icons.medication_outlined),
                _StatTile(label: 'Pharmacies', value: stats.pharmacies, icon: Icons.storefront_outlined),
              ],
            ),
            const SizedBox(height: 24),
            _Section(
              title: 'Scans, last 7 days',
              child: SizedBox(height: 180, child: DailyScansChart(days: stats.scansPerDay)),
            ),
            _Section(
              title: 'Scan results',
              child: Column(
                children: [
                  _CountRow(
                    icon: Icons.verified_outlined,
                    label: 'Registered & approved',
                    count: stats.scansByResult['authentic'] ?? 0,
                  ),
                  _CountRow(
                    icon: Icons.help_outline,
                    label: 'Unregistered or not approved',
                    count: stats.scansByResult['unknown'] ?? 0,
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Reports by status',
              child: Column(
                children: [
                  for (final status in ReportStatus.values)
                    _CountRow(
                      icon: ReportStatusChip.iconFor(status),
                      label: status.label,
                      count: stats.reportsByStatus[status] ?? 0,
                    ),
                ],
              ),
            ),
            _Section(
              title: 'Most scanned',
              subtitle: 'Registered medicines in the latest $topScannedSampleSize scans',
              child: stats.topScanned.isEmpty
                  ? const Text('No registered medicines scanned yet.')
                  : Column(
                      children: [
                        for (final (i, entry) in stats.topScanned.indexed)
                          _CountRow(label: '${i + 1}. ${entry.name}', count: entry.count),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 150,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text('$value', style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(label, style: textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleMedium),
          if (subtitle != null) Text(subtitle!, style: textTheme.bodySmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, required this.count, this.icon});

  final IconData? icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(label, style: textTheme.bodyLarge)),
          Text('$count', style: textTheme.titleMedium),
        ],
      ),
    );
  }
}

// --- Report queue --------------------------------------------------------------

class _ReportQueue extends ConsumerStatefulWidget {
  const _ReportQueue();

  @override
  ConsumerState<_ReportQueue> createState() => _ReportQueueState();
}

class _ReportQueueState extends ConsumerState<_ReportQueue> with AutomaticKeepAliveClientMixin {
  ReportStatus? _status;
  final _reports = <Report>[];
  ReportPage? _lastPage;
  bool _loading = false;
  String? _error;
  int _request = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() => _load(reset: true);

  Future<void> _load({bool reset = false}) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _reports.clear();
        _lastPage = null;
      }
    });
    try {
      final page = await ref.read(adminRepositoryProvider).reports(status: _status, after: _lastPage?.cursor);
      if (!mounted || request != _request) return;
      setState(() {
        _reports.addAll(page.reports);
        _lastPage = page;
      });
    } on AppException catch (e) {
      if (mounted && request == _request) setState(() => _error = e.message);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _open(Report report) async {
    await context.push('/admin/reports/${report.id}');
    // The report may have changed status; the list and stats follow it.
    ref.invalidate(adminStatsProvider);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              for (final status in <ReportStatus?>[null, ...ReportStatus.values]) ...[
                ChoiceChip(
                  label: Text(status?.label ?? 'All'),
                  selected: _status == status,
                  onSelected: (_) {
                    setState(() => _status = status);
                    _reload();
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                if (_reports.isEmpty && !_loading && _error == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Text(
                      _status == null ? 'No reports yet.' : 'No ${_status!.label.toLowerCase()} reports.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final report in _reports) _ReportCard(report: report, onTap: () => _open(report)),
                if (_loading)
                  const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                else if (_lastPage?.hasMore ?? false)
                  OutlinedButton(onPressed: _load, child: const Text('Load more')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final Report report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(report.displayName, style: textTheme.titleMedium)),
                  ReportStatusChip(status: report.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [report.country, if (report.createdAt != null) formatDate(report.createdAt!)].join(' · '),
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(report.description, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (report.hasPhoto || report.regulatorNotifiedAt != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  children: [
                    if (report.hasPhoto)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.photo_outlined, size: 16, color: muted),
                        const SizedBox(width: 4),
                        Text('Photo', style: textTheme.bodySmall),
                      ]),
                    if (report.regulatorNotifiedAt != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.mark_email_read_outlined, size: 16, color: muted),
                        const SizedBox(width: 4),
                        Text('Regulator emailed', style: textTheme.bodySmall),
                      ]),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
