import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class EmailOtpPage extends StatefulWidget {
  static const routeName = '/email-otp';
  const EmailOtpPage({super.key});

  @override
  State<EmailOtpPage> createState() => _EmailOtpPageState();
}

class _EmailOtpPageState extends State<EmailOtpPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;

  Future<void> _request() async {
    setState(() { _busy = true; _error = null; });
    try {
      await FirebaseFunctions.instance.httpsCallable('auth_requestEmailOtp').call({'email': _email.text.trim()});
      setState(() => _sent = true);
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() { _busy = true; _error = null; });
    try {
      final res = await FirebaseFunctions.instance.httpsCallable('auth_verifyEmailOtp').call({'email': _email.text.trim(), 'code': _code.text.trim()});
  final token = (res.data as Map)['customToken'] as String;
  await fb_auth.FirebaseAuth.instance.signInWithCustomToken(token);
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in with Email Code')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')), 
                  const SizedBox(height: 12),
                  if (_sent) TextField(controller: _code, decoration: const InputDecoration(labelText: '6-digit code')), 
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 12),
                  if (!_sent)
                    ElevatedButton(onPressed: _busy? null : _request, child: _busy? const CircularProgressIndicator() : const Text('Send code'))
                  else
                    ElevatedButton(onPressed: _busy? null : _verify, child: _busy? const CircularProgressIndicator() : const Text('Verify & Sign in')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
