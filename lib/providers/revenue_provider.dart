import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/revenue_repository.dart';
import '../models/revenue_entry.dart';

class RevenueProvider extends ChangeNotifier {
  final RevenueRepository _repo = RevenueRepository();
  bool _loaded = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _revSub;

  List<RevenueEntry> get entries => _repo.entries;
  bool get isLoaded => _loaded;
  double get total => _repo.totalRevenue();

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _repo.load();
    // Pull from Firestore if available; if empty there, push local cache once
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
        final col = userDoc.collection('revenue');
        final snap = await col.get();
        if (snap.docs.isNotEmpty) {
          final items = snap.docs.map((d) => RevenueEntry.fromJson(d.data())).toList();
          await _repo.replaceAll(items);
          _startListener(col);
        } else if (_repo.entries.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final e in _repo.entries) {
            batch.set(col.doc(e.id), e.toJson());
          }
          await batch.commit();
          _startListener(col);
        } else {
          // Nothing local and nothing remote; still start listener for future updates
          _startListener(col);
        }
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  void _startListener(CollectionReference<Map<String, dynamic>> col) {
    try {
      _revSub?.cancel();
      _revSub = col.orderBy('date', descending: false).snapshots().listen((snap) async {
        final items = snap.docs.map((d) => RevenueEntry.fromJson(d.data())).toList();
        await _repo.replaceAll(items);
        notifyListeners();
      });
    } catch (_) {}
  }

  Future<void> addRevenue({required String patientId, required String description, required double amount}) async {
    final entry = await _repo.addEntry(patientId: patientId, description: description, amount: amount);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('revenue').doc(entry.id).set(entry.toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> removeByDescription(String description) async {
    await _repo.removeByDescription(description);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final q = await FirebaseFirestore.instance.collection('users').doc(uid).collection('revenue').where('description', isEqualTo: description).get();
        final batch = FirebaseFirestore.instance.batch();
        for (final d in q.docs) { batch.delete(d.reference); }
        await batch.commit();
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<int> removeByPatientId(String patientId) async {
    final removed = await _repo.removeByPatientId(patientId);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final q = await FirebaseFirestore.instance.collection('users').doc(uid).collection('revenue').where('patientId', isEqualTo: patientId).get();
        final batch = FirebaseFirestore.instance.batch();
        for (final d in q.docs) { batch.delete(d.reference); }
        await batch.commit();
      }
    } catch (_) {}
    if (removed > 0) notifyListeners();
    return removed;
  }

  Future<int> removeByDescriptionPrefix(String prefix) async {
    final removed = await _repo.removeByDescriptionPrefix(prefix);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final q = await FirebaseFirestore.instance.collection('users').doc(uid).collection('revenue').where('description', isGreaterThanOrEqualTo: prefix).where('description', isLessThan: prefix + '\uf8ff').get();
        final batch = FirebaseFirestore.instance.batch();
        for (final d in q.docs) { batch.delete(d.reference); }
        await batch.commit();
      }
    } catch (_) {}
    if (removed > 0) notifyListeners();
    return removed;
  }

  Future<int> removeByDescriptionForPatient(String patientId, String description) async {
    final removed = await _repo.removeByDescriptionForPatient(patientId, description);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final q = await FirebaseFirestore.instance.collection('users').doc(uid).collection('revenue')
            .where('patientId', isEqualTo: patientId).where('description', isEqualTo: description).get();
        final batch = FirebaseFirestore.instance.batch();
        for (final d in q.docs) { batch.delete(d.reference); }
        await batch.commit();
      }
    } catch (_) {}
    if (removed > 0) notifyListeners();
    return removed;
  }

  Future<void> clearAll() async {
    await _repo.clearAll();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final q = await FirebaseFirestore.instance.collection('users').doc(uid).collection('revenue').get();
        final batch = FirebaseFirestore.instance.batch();
        for (final d in q.docs) { batch.delete(d.reference); }
        await batch.commit();
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> removeById(String id) async {
    final ok = await _repo.removeById(id);
    if (ok) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).collection('revenue').doc(id).delete();
        }
      } catch (_) {}
    }
    if (ok) notifyListeners();
    return ok;
  }

  @override
  void dispose() {
    _revSub?.cancel();
    super.dispose();
  }
}
