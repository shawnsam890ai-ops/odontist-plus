import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

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
              const Text('Your account is pending approval by an administrator.'),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => context.read<AuthProvider>().signOut(),
                child: const Text('Sign out'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
