import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/app_user.dart';

class AdminUsersPage extends StatefulWidget {
  static const routeName = '/admin-users';
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<AppUser> _pending = const [];
  bool _loading = true;

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final pending = await context.read<AuthProvider>().listPendingUsers();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Approvals')),
        body: const Center(child: Text('Not authorized.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('User Approvals')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_pending.any((_) => true)
              ? const Center(child: Text('No pending users.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (ctx, i) {
                    final u = _pending[i];
                    return ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(u.displayName ?? u.email),
                      subtitle: Text(u.email),
                      trailing: isAdmin
                          ? FilledButton(
                              onPressed: () async {
                                await context.read<AuthProvider>().approveUser(u.uid);
                                await _refresh();
                              },
                              child: const Text('Approve'),
                            )
                          : null,
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(),
                  itemCount: _pending.length,
                ),
    );
  }
}
