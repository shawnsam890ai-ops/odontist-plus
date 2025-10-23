import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'login_page.dart';

class PendingApprovalPage extends StatelessWidget {
  static const routeName = '/pending-approval';
  const PendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Awaiting Approval')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_empty, size: 56),
              const SizedBox(height: 16),
              Text(
                'Hi ${auth.user?.displayName ?? auth.user?.email ?? ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text('Your access is not enabled yet. If this is your first sign-in, please try again shortly or contact support.'),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () async {
                  await context.read<AuthProvider>().signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(LoginPage.routeName, (route) => false);
                  }
                },
                child: const Text('Sign out'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
