import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/license_provider.dart';
import 'dashboard_page.dart';
import 'pending_approval_page.dart';
import 'auth/signup_page.dart';
import 'auth/email_otp_page.dart';
import 'auth/phone_otp_page.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class LoginPage extends StatefulWidget {
  static const routeName = '/login';
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _showPassword = false;
  String? _error;

  Widget _oauthSection(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(children: const [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Or continue with')), Expanded(child: Divider())]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const EmailOtpPage()));
                if (result == true && context.mounted) {
                  final lic = context.read<LicenseProvider>();
                  await lic.refresh();
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacementNamed(lic.allowed ? DashboardPage.routeName : PendingApprovalPage.routeName);
                }
              },
              icon: const Icon(Icons.mail),
              label: const Text('Email OTP'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const PhoneOtpPage()));
                if (result == true && context.mounted) {
                  final lic = context.read<LicenseProvider>();
                  await lic.refresh();
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacementNamed(lic.allowed ? DashboardPage.routeName : PendingApprovalPage.routeName);
                }
              },
              icon: const Icon(Icons.sms),
              label: const Text('Phone OTP'),
            ),
            OutlinedButton.icon(onPressed: _signInWithGoogle, icon: const Icon(Icons.account_circle), label: const Text('Google')),
          ],
        ),
      ],
    );
  }

  Future<void> _signInWithGoogle() async {
    try {
      final g = GoogleSignIn(scopes: ['email']);
      final acc = await g.signIn();
      if (acc == null) return; // cancelled
      final auth = await acc.authentication;
      final cred = fb_auth.GoogleAuthProvider.credential(idToken: auth.idToken, accessToken: auth.accessToken);
      await fb_auth.FirebaseAuth.instance.signInWithCredential(cred);
      if (!mounted) return;
      // Refresh license status and navigate accordingly (auto-approval via trial)
      final lic = context.read<LicenseProvider>();
      await lic.refresh();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(lic.allowed ? DashboardPage.routeName : PendingApprovalPage.routeName);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Odontist Plus Login', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _userController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter email' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      obscureText: !_showPassword,
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter password' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _error = null);
                          final auth = context.read<AuthProvider>();
                          String? err;
                          err = await auth.signIn(_userController.text.trim(), _passController.text.trim());
                          if (err != null) {
                            setState(() => _error = err);
                            return;
                          }
                          if (!mounted) return;
                          // After sign-in, refresh license gating and route
                          final lic = context.read<LicenseProvider>();
                          await lic.refresh();
                          if (!mounted) return;
                          Navigator.of(context).pushReplacementNamed(lic.allowed ? DashboardPage.routeName : PendingApprovalPage.routeName);
                        },
                        child: const Text('Login'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushNamed(SignupPage.routeName),
                      child: const Text('New here? Create an account'),
                    ),
                    _oauthSection(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
