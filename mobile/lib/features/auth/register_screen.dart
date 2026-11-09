import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/countries.dart';
import '../../core/password_policy.dart';
import '../../core/theme.dart';
import 'auth_controller.dart';

/// Roles open to self-registration (admins are only ever promoted by hand).
const _roles = [
  ('consumer', 'Consumer', Icons.person_outline),
  ('pharmacist', 'Pharmacist', Icons.local_pharmacy_outlined),
  ('manufacturer', 'Manufacturer', Icons.factory_outlined),
];

/// Pops with `true` once the account exists and is signed in.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  String? _country;
  String _role = 'consumer';
  bool _showPassword = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // Firebase doesn't reveal whether an email already has an account (that
  // would let anyone probe for users), so a taken email is reported on submit.
  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Please enter your email address.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) return 'Please enter a valid email address.';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).register(
            fullName: _fullName.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            country: _country!,
            role: _role,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Welcome to Hakikisha! We've emailed you a link to verify your address.")),
      );
      context.pop(true);
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create an account')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Full name'),
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: !_showPassword,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                validator: (v) => meetsPasswordPolicy(v ?? '') ? null : "Your password doesn't meet the requirements below.",
              ),
              const SizedBox(height: 8),
              for (final rule in passwordRules) _RuleRow(rule: rule, password: _password.text),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _country,
                decoration: const InputDecoration(labelText: 'Country'),
                items: [for (final c in registrationCountries) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (value) => setState(() => _country = value),
                validator: (v) => v == null ? 'Please select your country.' : null,
              ),
              const SizedBox(height: 24),
              Text('I am a…', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  for (final (value, label, icon) in _roles)
                    ButtonSegment(value: value, label: Text(label), icon: Icon(icon)),
                ],
                selected: {_role},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => setState(() => _role = selection.single),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create account'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _submitting ? null : () => context.pop(),
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule, required this.password});

  final PasswordRule rule;
  final String password;

  @override
  Widget build(BuildContext context) {
    final met = rule.isMetBy(password);
    final color = met ? HakikishaColors.green : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: color),
          const SizedBox(width: 8),
          Text(rule.label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
