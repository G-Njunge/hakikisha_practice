import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakikisha/features/medicine/search_screen.dart';
import 'package:hakikisha/features/verify/medicine_repository.dart';
import 'package:hakikisha/models/medicine.dart';

Medicine _medicine(String name, String generic, ApprovalStatus status) => Medicine(
      id: name,
      name: name,
      genericName: generic,
      manufacturer: 'Maker',
      dosageForm: 'tablet',
      strength: '500mg',
      barcode: name,
      regulatoryBody: 'Rwanda FDA',
      approvalNumber: '1',
      approvalStatus: status,
    );

void main() {
  testWidgets('lists the registry, then narrows as you type', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        medicineCatalogProvider.overrideWith((ref) async => [
              _medicine('Amoxil', 'Amoxicillin', ApprovalStatus.approved),
              _medicine('Panadol', 'Paracetamol', ApprovalStatus.approved),
              _medicine('Vibramycin', 'Doxycycline', ApprovalStatus.pending),
            ]),
      ],
      child: const MaterialApp(home: SearchScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Amoxil'), findsOneWidget);
    expect(find.text('Vibramycin'), findsOneWidget);
    expect(find.text('Approval pending'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'paracet');
    await tester.pump();

    expect(find.text('Panadol'), findsOneWidget);
    expect(find.text('Amoxil'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nothing like it');
    await tester.pump();

    expect(find.textContaining('No registered medicine matches'), findsOneWidget);
  });
}
