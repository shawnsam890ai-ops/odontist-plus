import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum LicenseStatus { unknown, trial, active, expired }

class LicenseState {
  final LicenseStatus status;
  final bool allowed;
  final bool trialValid;
  final bool active;
  final bool integrityRecent;
  final DateTime? expiryDate;
  const LicenseState({
    this.status = LicenseStatus.unknown,
    this.allowed = false,
    this.trialValid = false,
    this.active = false,
    this.integrityRecent = false,
    this.expiryDate,
  });

  LicenseState copyWith({
    LicenseStatus? status,
    bool? allowed,
    bool? trialValid,
    bool? active,
    bool? integrityRecent,
    DateTime? expiryDate,
  }) => LicenseState(
        status: status ?? this.status,
        allowed: allowed ?? this.allowed,
        trialValid: trialValid ?? this.trialValid,
        active: active ?? this.active,
        integrityRecent: integrityRecent ?? this.integrityRecent,
        expiryDate: expiryDate ?? this.expiryDate,
      );
}

class LicenseProvider extends ChangeNotifier {
  LicenseState _state = const LicenseState();
  Timer? _timer;

  LicenseState get state => _state;
  LicenseStatus get status => _state.status;
  bool get allowed => _state.allowed;

  Future<void> refresh() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('checkAccess');
      final res = await callable.call();
      final data = Map<String, dynamic>.from(res.data as Map);
      final statusStr = (data['license_status'] as String?) ?? 'unknown';
      final status = statusStr == 'active'
          ? LicenseStatus.active
          : (data['trialValid'] == true ? LicenseStatus.trial : LicenseStatus.expired);
      _state = _state.copyWith(
        status: status,
        allowed: data['allowed'] == true,
        trialValid: data['trialValid'] == true,
        active: data['active'] == true,
        integrityRecent: data['integrityRecent'] == true,
        // expiry date is not returned explicitly; optional to add later
      );
      notifyListeners();
    } catch (e) {
      // Fallback when Functions are not deployed: compute access from Firestore and
      // auto-provision a trial on first sign-in (auto-approval).
      await _refreshFromFirestore();
    }
  }

  Future<void> _refreshFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // not signed in yet
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!snap.exists) {
      // Create with 3-day trial on first sign-in. Allowed by rules on create.
      await ref.set({
        'profile': {
          'email': user.email,
          'displayName': user.displayName,
        },
        'license_status': 'trial',
        'trial_start': FieldValue.serverTimestamp(),
        'integrity_passed_at': null,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _state = _state.copyWith(status: LicenseStatus.trial, allowed: true, trialValid: true, active: false);
      notifyListeners();
      return;
    }

    final data = snap.data() ?? {};
    int trialStartMs = 0;
    final ts = data['trial_start'];
    if (ts is Timestamp) {
      trialStartMs = ts.millisecondsSinceEpoch;
    } else if (ts is Map && ts['_seconds'] is int) {
      trialStartMs = (ts['_seconds'] as int) * 1000;
    }
    final trialValid = trialStartMs > 0 && (nowMs - trialStartMs) <= const Duration(days: 3).inMilliseconds;
    int expiryMs = 0;
    final exp = data['expiry_date'];
    if (exp is Timestamp) {
      expiryMs = exp.millisecondsSinceEpoch;
    } else if (exp is Map && exp['_seconds'] is int) {
      expiryMs = (exp['_seconds'] as int) * 1000;
    }
    final active = (data['license_status'] == 'active') && expiryMs > nowMs;
    final status = active ? LicenseStatus.active : (trialValid ? LicenseStatus.trial : LicenseStatus.expired);
    _state = _state.copyWith(status: status, allowed: active || trialValid, trialValid: trialValid, active: active);
    notifyListeners();
  }

  void startAutoRefresh({Duration every = const Duration(minutes: 15)}) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
