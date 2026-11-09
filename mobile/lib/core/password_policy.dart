/// Mirrors server/src/lib/passwordPolicy.ts (kept in sync by hand), so the
/// registration form can show which rules a password still misses before the
/// server rejects it.
class PasswordRule {
  const PasswordRule(this.label, this._test);

  final String label;
  final bool Function(String password) _test;

  bool isMetBy(String password) => _test(password);
}

final passwordRules = [
  PasswordRule('At least 8 characters', (p) => p.length >= 8),
  PasswordRule('A lowercase letter', (p) => p.contains(RegExp('[a-z]'))),
  PasswordRule('An uppercase letter', (p) => p.contains(RegExp('[A-Z]'))),
  PasswordRule('A number', (p) => p.contains(RegExp('[0-9]'))),
];

bool meetsPasswordPolicy(String password) => passwordRules.every((rule) => rule.isMetBy(password));
