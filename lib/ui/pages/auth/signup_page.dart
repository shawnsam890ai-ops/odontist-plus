import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  static const routeName = '/signup';
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _username = TextEditingController();
  final _clinic = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  bool _agreeTerms = false;
  bool _optInMarketing = false;

  String? _validatePassword(String? v) {
    if (v == null || v.length < 8) return 'Min 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Add at least one uppercase letter';
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\/;+='"'"'`~]').hasMatch(v)) return 'Add at least one symbol';
    return null;
  }

  Future<void> _signup() async {
    final ok = _form.currentState?.validate() ?? false;
    if (!ok) return;
    if (!_agreeTerms) {
      setState(() => _error = 'Please agree to the Terms & Conditions.');
      return;
    }
    if (_pass.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _pass.text);
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'profile': {
          'firstName': _first.text.trim(),
          'lastName': _last.text.trim(),
          'username': _username.text.trim(),
          'clinicName': _clinic.text.trim(),
        },
        'preferences': {
          'marketingOptIn': _optInMarketing,
        },
        // Auto-approval: provision a 3-day trial on account creation.
        'license_status': 'trial',
        'trial_start': FieldValue.serverTimestamp(),
        'integrity_passed_at': null,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = '${e.code}: ${e.message ?? 'Authentication failed'}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: TextFormField(controller: _first, decoration: const InputDecoration(labelText: 'First name'), validator: (v) => (v==null||v.isEmpty)?'Required':null)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _last, decoration: const InputDecoration(labelText: 'Last name'))),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(controller: _username, decoration: const InputDecoration(labelText: 'Preferred username'), validator: (v)=> (v==null||v.isEmpty)?'Required':null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _clinic, decoration: const InputDecoration(labelText: 'Clinic name')),                  
                  const SizedBox(height: 12),
                  TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress, validator: (v)=> (v==null||!v.contains('@'))?'Enter a valid email':null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _pass, decoration: InputDecoration(labelText: 'Create password', suffixIcon: IconButton(icon: Icon(_obscure?Icons.visibility:Icons.visibility_off), onPressed: ()=>setState(()=>_obscure=!_obscure))), obscureText: _obscure, validator: _validatePassword),
                  const SizedBox(height: 12),
                  TextFormField(controller: _confirm, decoration: InputDecoration(labelText: 'Confirm password', suffixIcon: IconButton(icon: Icon(_obscure?Icons.visibility:Icons.visibility_off), onPressed: ()=>setState(()=>_obscure=!_obscure))), obscureText: _obscure, validator: (v)=> v==_pass.text?null:'Passwords do not match'),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(value: _agreeTerms, onChanged: (v)=> setState(()=> _agreeTerms = v ?? false)),
                      Expanded(
                        child: Wrap(
                          children: [
                            const Text('I agree to the '),
                            InkWell(
                              onTap: () => Navigator.of(context).pushNamed('/terms'),
                              child: Text('Terms & Conditions', style: TextStyle(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(value: _optInMarketing, onChanged: (v)=> setState(()=> _optInMarketing = v ?? false)),
                      const Expanded(child: Text('Receive newsletters and promotional calls')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _busy?null:_signup, child: _busy? const CircularProgressIndicator() : const Text('Create account')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
