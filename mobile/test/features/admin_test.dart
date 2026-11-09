import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakikisha/features/admin/admin_repository.dart';
import 'package:hakikisha/features/admin/daily_scans_chart.dart';
import 'package:hakikisha/features/admin/report_detail_screen.dart';
import 'package:hakikisha/models/report.dart';

class _RecordingAdminRepository implements AdminRepository {
  final actions = <(String, ReportAction)>[];

  @override
  Future<void> applyAction(String reportId, ReportAction action) async => actions.add((reportId, action));

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Report _report(ReportStatus status) => Report(
      id: 'rep-1',
      scanId: null,
      productName: 'Coartem 20/120',
      medicineName: null,
      description: 'Seal was broken',
      country: 'Rwanda',
      purchaseLocation: null,
      hasPhoto: false,
      status: status,
      reportedBy: 'alice',
      createdAt: DateTime(2026, 10, 24),
      adminNotes: null,
      regulatorNotifiedAt: null,
      resolvedAt: null,
    );

Future<_RecordingAdminRepository> _pumpReport(WidgetTester tester, ReportStatus status) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  final repo = _RecordingAdminRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      adminRepositoryProvider.overrideWithValue(repo),
      reportProvider.overrideWith((ref, id) async => _report(status)),
      reporterProvider.overrideWith((ref, uid) async => (name: 'Alice', email: 'alice@example.com')),
      regulatorProvider.overrideWith(
        (ref, country) async => const Regulator(name: 'Rwanda FDA', email: 'fda@example.com'),
      ),
    ],
    child: const MaterialApp(home: ReportDetailScreen(reportId: 'rep-1')),
  ));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('a pending report shows its details, regulator and every action', (tester) async {
    await _pumpReport(tester, ReportStatus.pending);

    expect(find.text('Coartem 20/120'), findsOneWidget);
    expect(find.text('Alice (alice@example.com)'), findsOneWidget);
    expect(find.text('Rwanda FDA · fda@example.com'), findsOneWidget);
    expect(find.text('Not emailed yet.'), findsOneWidget);
    for (final action in ReportAction.values) {
      expect(find.text(action.label), findsOneWidget);
    }
  });

  testWidgets('starting a review applies it straight away', (tester) async {
    final repo = await _pumpReport(tester, ReportStatus.pending);

    await tester.tap(find.text('Start review'));
    await tester.pumpAndSettle();

    expect(repo.actions, [('rep-1', ReportAction.review)]);
  });

  testWidgets('closing a report asks for confirmation first', (tester) async {
    final repo = await _pumpReport(tester, ReportStatus.investigating);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Dismiss?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.actions, isEmpty);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Dismiss')));
    await tester.pumpAndSettle();
    expect(repo.actions, [('rep-1', ReportAction.dismiss)]);
  });

  testWidgets('a closed report offers no actions', (tester) async {
    await _pumpReport(tester, ReportStatus.resolved);

    for (final action in ReportAction.values) {
      expect(find.text(action.label), findsNothing);
    }
  });

  testWidgets('the daily scans chart labels each day and summarises for screen readers', (tester) async {
    final days = [for (var i = 0; i < 7; i++) (day: DateTime(2026, 10, 19 + i), count: i)];
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(height: 180, child: DailyScansChart(days: days))),
    ));

    for (final weekday in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.text(weekday), findsOneWidget);
    }
    // Only today's value is labelled directly.
    expect(find.text('6'), findsOneWidget);
    expect(find.text('5'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'Total 21\.')), findsOneWidget);
    semantics.dispose();
  });
}
