import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../auth/auth_controller.dart';
import '../report/report_screen.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: auth.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Centered(
          children: [
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () => ref.invalidate(authControllerProvider), child: const Text('Try again')),
          ],
        ),
        data: (user) {
          if (user == null) {
            return _Centered(
              children: [
                const Icon(Icons.person_outline, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Scanning works without an account. Log in to report suspicious medicines and see your history.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => context.push('/login'), child: const Text('Log in')),
                const SizedBox(height: 8),
                TextButton(onPressed: () => context.push('/register'), child: const Text('Create an account')),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user.fullName),
                subtitle: Text('${user.email} · ${user.role}'),
              ),
              if (!user.isVerified) const _VerifyEmailCard(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report a suspicious medicine'),
                subtitle: const Text("For a product you can't scan"),
                onTap: () => openReportForm(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: () => ref.read(authControllerProvider.notifier).logout(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VerifyEmailCard extends ConsumerStatefulWidget {
  const _VerifyEmailCard();

  @override
  ConsumerState<_VerifyEmailCard> createState() => _VerifyEmailCardState();
}

class _VerifyEmailCardState extends ConsumerState<_VerifyEmailCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String? doneMessage) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (doneMessage != null) messenger.showSnackBar(SnackBar(content: Text(doneMessage)));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authControllerProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.mark_email_unread_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('Please verify your email address')),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Open the link we emailed you, then come back and tap "I\'ve verified".'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => _run(auth.refresh, null),
                  child: const Text("I've verified"),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _run(auth.resendVerificationEmail, 'Verification email sent.'),
                  child: const Text('Resend email'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
