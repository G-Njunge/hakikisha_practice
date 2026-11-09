import 'package:flutter_test/flutter_test.dart';
import 'package:hakikisha/core/password_policy.dart';

void main() {
  test('accepts a password meeting every rule, as the server does', () {
    expect(meetsPasswordPolicy('Password123'), isTrue);
  });

  test('rejects passwords missing any one rule', () {
    expect(meetsPasswordPolicy('Pass123'), isFalse, reason: 'too short');
    expect(meetsPasswordPolicy('PASSWORD123'), isFalse, reason: 'no lowercase');
    expect(meetsPasswordPolicy('password123'), isFalse, reason: 'no uppercase');
    expect(meetsPasswordPolicy('PasswordOnly'), isFalse, reason: 'no number');
  });

  test('reports each rule separately for the live checklist', () {
    final met = passwordRules.where((rule) => rule.isMetBy('abc')).map((rule) => rule.label);
    expect(met, ['A lowercase letter']);
  });
}
