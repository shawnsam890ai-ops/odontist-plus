import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class PhoneOtpPage extends StatefulWidget {
  static const routeName = '/phone-otp';
  const PhoneOtpPage({super.key});

  @override
  State<PhoneOtpPage> createState() => _PhoneOtpPageState();
}

class _PhoneOtpPageState extends State<PhoneOtpPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _verificationId;
  bool _sent = false;
  bool _busy = false;
  String? _error;
  Timer? _timer;
  int _sec = 0;

  Future<void> _send() async {
    setState(() { _busy = true; _error = null; });
    try {
      await fb_auth.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phone.text.trim(),
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          // Auto-retrieval on some devices
          try { await fb_auth.FirebaseAuth.instance.signInWithCredential(cred); if (mounted) Navigator.of(context).pop(true); } catch (_) {}
        },
        verificationFailed: (e) { setState(() => _error = e.message); },
        codeSent: (id, _) {
          setState(() { _verificationId = id; _sent = true; _sec = 60; });
          _timer?.cancel();
          _timer = Timer.periodic(const Duration(seconds: 1), (t){ if (_sec<=0) t.cancel(); else setState(()=>_sec--); });
        },
        codeAutoRetrievalTimeout: (id) => setState(() => _verificationId = id),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_verificationId == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final cred = fb_auth.PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: _code.text.trim());
      await fb_auth.FirebaseAuth.instance.signInWithCredential(cred);
      if (mounted) Navigator.of(context).pop(true);
    } on fb_auth.FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in with Phone')),
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
                  TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone (+91xxxxxxxxxx)')),
                  const SizedBox(height: 12),
                  if (_sent) TextField(controller: _code, decoration: const InputDecoration(labelText: '6-digit code')),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 12),
                  if (!_sent)
                    ElevatedButton(onPressed: _busy? null : _send, child: _busy? const CircularProgressIndicator() : const Text('Send code'))
                  else
                    ElevatedButton(onPressed: _busy? null : _verify, child: _busy? const CircularProgressIndicator() : const Text('Verify & Sign in')),
                  if (_sent) Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(_sec>0? 'Resend available in $_sec s' : 'You can request a new code.'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
