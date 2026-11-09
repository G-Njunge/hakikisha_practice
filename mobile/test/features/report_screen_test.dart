import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hakikisha/features/auth/auth_controller.dart';
import 'package:hakikisha/features/report/report_repository.dart';
import 'package:hakikisha/features/report/report_screen.dart';

import '../support/fake_auth.dart';

class _RecordingReportRepository implements ReportRepository {
  final submissions = <Map<String, Object?>>[];

  @override
  Future<void> submit({
    String? scanId,
    String? productName,
    String? medicineName,
    required String description,
    required String country,
    String? purchaseLocation,
    ReportPhoto? photo,
  }) async {
    submissions.add({
      'scanId': scanId,
      'productName': productName,
      'medicineName': medicineName,
      'description': description,
      'country': country,
      'purchaseLocation': purchaseLocation,
      'photo': photo,
    });
  }
}

Future<_RecordingReportRepository> _pumpReport(WidgetTester tester, ReportTarget target) async {
  // A tall phone, so the lazily-built form fits without scrolling.
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  final repo = _RecordingReportRepository();
  final container = ProviderContainer(overrides: [
    authControllerProvider.overrideWith(() => FakeAuthController(testUser)),
    reportRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  // In the app the form only opens once someone is signed in.
  await container.read(authControllerProvider.future);

  // Pushed over a home route, as in the app, so it has somewhere to pop to.
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(path: '/report', builder: (_, _) => ReportScreen(target: target)),
    ],
  );
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  ));
  router.push('/report');
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('reports a scanned medicine by scan id, defaulting to the account country', (tester) async {
    final repo = await _pumpReport(tester, const ReportTarget(scanId: 'scan-1', medicineName: 'Panadol'));

    expect(find.text('Panadol'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Product name'), findsNothing);
    expect(find.text('Rwanda'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'What made you suspicious?'), 'Seal was broken');
    await tester.ensureVisible(find.text('Send report'));
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();

    expect(repo.submissions.single, {
      'scanId': 'scan-1',
      'productName': null,
      'medicineName': 'Panadol',
      'description': 'Seal was broken',
      'country': 'Rwanda',
      'purchaseLocation': null,
      'photo': null,
    });
    expect(find.text('Report sent'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('an unknown product needs a name before it can be reported', (tester) async {
    final repo = await _pumpReport(tester, const ReportTarget(scanId: 'scan-2'));

    await tester.enterText(find.widgetWithText(TextFormField, 'What made you suspicious?'), 'Not in the registry');
    await tester.ensureVisible(find.text('Send report'));
    await tester.tap(find.text('Send report'));
    await tester.pump();

    expect(find.text('Please tell us which product this is about.'), findsOneWidget);
    expect(repo.submissions, isEmpty);

    await tester.enterText(find.widgetWithText(TextFormField, 'Product name'), 'Coartem 20/120');
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();

    expect(repo.submissions.single['scanId'], 'scan-2');
    expect(repo.submissions.single['productName'], 'Coartem 20/120');
  });
}
