import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hakikisha/features/auth/auth_controller.dart';
import 'package:hakikisha/features/auth/auth_repository.dart';
import 'package:hakikisha/features/auth/register_screen.dart';

import '../support/fake_auth.dart';

Future<(FakeAuthRepository, ProviderContainer)> _pumpRegister(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  final repo = FakeAuthRepository();
  final container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repo)]);
  addTearDown(container.dispose);

  // Pushed over a home route, as in the app, so it has somewhere to pop to.
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    ],
  );
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  ));
  router.push('/register');
  await tester.pumpAndSettle();
  return (repo, container);
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  testWidgets('ticks off password rules as they are met', (tester) async {
    await _pumpRegister(tester);
    Icon iconFor(String rule) => tester.widget<Icon>(
          find.descendant(of: find.widgetWithText(Row, rule), matching: find.byType(Icon)),
        );

    expect(iconFor('An uppercase letter').icon, Icons.radio_button_unchecked);

    await tester.enterText(_field('Password'), 'Abcdefg1');
    await tester.pump();

    for (final rule in ['At least 8 characters', 'A lowercase letter', 'An uppercase letter', 'A number']) {
      expect(iconFor(rule).icon, Icons.check_circle, reason: rule);
    }
  });

  testWidgets('creates the account with the chosen role and signs it in', (tester) async {
    final (repo, container) = await _pumpRegister(tester);

    await tester.enterText(_field('Full name'), 'Amani Uwase');
    await tester.enterText(_field('Email'), 'amani@example.com');
    await tester.enterText(_field('Password'), 'Password123');
    await tester.tap(find.text('Country'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rwanda').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pharmacist'));
    await tester.pump();

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(repo.registered.single, {
      'fullName': 'Amani Uwase',
      'email': 'amani@example.com',
      'password': 'Password123',
      'country': 'Rwanda',
      'role': 'pharmacist',
    });
    expect(container.read(authControllerProvider).value?.email, 'amani@example.com');
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('shows why sign-up failed and stays on the form', (tester) async {
    final (repo, _) = await _pumpRegister(tester);

    await tester.enterText(_field('Full name'), 'Amani Uwase');
    await tester.enterText(_field('Email'), 'taken@example.com');
    await tester.enterText(_field('Password'), 'Password123');
    await tester.tap(find.text('Country'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rwanda').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('That email is already registered.'), findsOneWidget);
    expect(find.text('Create account'), findsWidgets);
    expect(repo.registered, isEmpty);
  });
}
