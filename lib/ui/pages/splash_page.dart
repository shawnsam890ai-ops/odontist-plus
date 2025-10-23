import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/license_provider.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'pending_approval_page.dart';

class SplashPage extends StatefulWidget {
  static const routeName = '/';
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _navTimer;
  @override
  void initState() {
    super.initState();
    _navTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      await auth.ensureLoaded();
      // Ensure license state is refreshed before deciding the route
      try {
        await context.read<LicenseProvider>().refresh();
      } catch (_) {}
      if (!mounted) return;
      final license = context.read<LicenseProvider>();
      if (!auth.isLoggedIn) {
        Navigator.of(context).pushReplacementNamed(LoginPage.routeName);
      } else if (license.allowed) {
        // Allowed by trial/active subscription
        Navigator.of(context).pushReplacementNamed(DashboardPage.routeName);
      } else {
        // Not allowed yet (no trial/expired) – show pending/paywall screen
        Navigator.of(context).pushReplacementNamed(PendingApprovalPage.routeName);
      }
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primary.withOpacity(.10), cs.secondary.withOpacity(.10), cs.surface],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [cs.primary, cs.tertiary]),
                  boxShadow: [
                    BoxShadow(color: cs.primary.withOpacity(.35), blurRadius: 24, spreadRadius: 2, offset: const Offset(0,8)),
                  ],
                ),
                child: Icon(Icons.health_and_safety, color: cs.onPrimary, size: 42),
              )
                  .animate()
                  .scale(duration: 500.ms, curve: Curves.easeOutBack)
                  .then()
                  .shake(duration: 500.ms, hz: 2, curve: Curves.easeOut),
              const SizedBox(height: 18),
              Text('Odontist Plus', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .move(begin: const Offset(0, 8), end: Offset.zero, curve: Curves.easeOutCubic),
              const SizedBox(height: 12),
              Text('Loading your workspace...', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
                  .animate()
                  .fadeIn(duration: 650.ms, delay: 150.ms),
              const SizedBox(height: 22),
              SizedBox(
                width: 160,
                child: LinearProgressIndicator(borderRadius: BorderRadius.circular(12), color: cs.primary),
              ).animate().fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
