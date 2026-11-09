import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakikisha/features/verify/medicine_repository.dart';
import 'package:hakikisha/features/verify/verify_flow_screen.dart';
import 'package:hakikisha/models/medicine.dart';
import 'package:hakikisha/models/scan_result.dart';

const _medicine = Medicine(
  id: 'm-1',
  name: 'Panadol',
  genericName: 'Paracetamol',
  manufacturer: 'GSK',
  dosageForm: 'Tablet',
  strength: '500mg',
  barcode: '5000158062528',
  regulatoryBody: 'Rwanda FDA',
  approvalNumber: 'RW-123',
  approvalStatus: ApprovalStatus.approved,
  packageVerification: ['Hologram on the seal', 'Batch number printed, not stickered'],
);

Widget _app(ScanResult result) => ProviderScope(
      overrides: [medicineProvider.overrideWith((ref, id) async => _medicine)],
      child: MaterialApp(home: VerifyFlowScreen(result: result)),
    );

void main() {
  testWidgets('an unknown barcode shows a single result page with no steps', (tester) async {
    await tester.pumpWidget(_app(const ScanResult(
      verified: false,
      scanId: 's-1',
      barcode: '12345678',
      medicine: null,
      batchNumber: null,
      expiryDate: null,
      message: 'This barcode does not exist in the Hakikisha database.',
    )));

    expect(find.text('Unknown product'), findsOneWidget);
    expect(find.text('Scan another'), findsOneWidget);
    expect(find.textContaining('Step'), findsNothing);
  });

  testWidgets('a registered medicine walks through the steps to the checklist', (tester) async {
    await tester.pumpWidget(_app(const ScanResult(
      verified: true,
      scanId: 's-2',
      barcode: '5000158062528',
      medicine: ScannedMedicine(id: 'm-1', name: 'Panadol', manufacturer: 'GSK', approvalStatus: ApprovalStatus.approved),
      batchNumber: 'B123',
      expiryDate: null,
      message: null,
    )));

    expect(find.text('Registered medicine'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(find.text('Reference photos for this medicine are not available yet.'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Hologram on the seal'), findsOneWidget);

    await tester.tap(find.text('Hologram on the seal'));
    await tester.tap(find.text('Batch number printed, not stickered'));
    await tester.pump();
    expect(find.text('Everything matches. Still buy only from a licensed pharmacy.'), findsOneWidget);
  });
}
