import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/medicine_repository.dart';
import '../models/medicine.dart';

class MedicineProvider with ChangeNotifier {
  final MedicineRepository _repo = MedicineRepository();
  bool _loaded = false;
  bool _listening = false;
  final Set<String> _pendingDeletes = <String>{};

  List<Medicine> get medicines => _repo.items;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _repo.load();
    await _loadPendingDeletes();
    await _syncFromRemoteAndListen();
    _loaded = true;
    notifyListeners();
  }

  Future<void> addMedicine({required String name, String? content, required double storeAmount, required double mrp, required int strips, int unitsPerStrip = 10, int freeStrips = 0, int looseTabs = 0}) async {
    final m = await _repo.add(name: name, content: content, storeAmount: storeAmount, mrp: mrp, strips: strips, unitsPerStrip: unitsPerStrip, freeStrips: freeStrips, looseTabs: looseTabs);
    // Mirror to Firestore
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('medicines').doc(m.id).set(m.toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateMedicine(String id, {String? name, String? content, double? storeAmount, double? mrp, int? strips, int? unitsPerStrip, int? freeStrips, int? looseTabs}) async {
    await _repo.update(id, name: name, content: content, storeAmount: storeAmount, mrp: mrp, strips: strips, unitsPerStrip: unitsPerStrip, freeStrips: freeStrips, looseTabs: looseTabs);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final m = _repo.items.firstWhere((e) => e.id == id, orElse: () => throw 'missing');
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('medicines').doc(id).set(m.toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> deleteMedicine(String id) async {
    await _repo.delete(id);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('medicines').doc(id).delete();
        // If remote delete succeeds, ensure tombstone cleared
        _pendingDeletes.remove(id);
        await _savePendingDeletes();
      } else {
        // Not signed in: queue tombstone so it doesn't reappear on next sync
        _pendingDeletes.add(id);
        await _savePendingDeletes();
      }
    } catch (_) {
      // Network/permission issue: mark tombstone so it won't resurrect from remote
      _pendingDeletes.add(id);
      await _savePendingDeletes();
    }
    notifyListeners();
  }

  void _startRemoteListener(CollectionReference<Map<String, dynamic>> col) {
    if (_listening) return;
    _listening = true;
    col.orderBy('name').snapshots().listen((snap) async {
      // Apply tombstones on live updates too
      for (final d in snap.docs) {
        final id = (d.data()['id'] as String?) ?? d.id;
        if (_pendingDeletes.contains(id)) {
          try {
            await col.doc(id).delete();
          } catch (_) {}
        }
      }
      final items = snap.docs
          .where((d) => !_pendingDeletes.contains((d.data()['id'] as String?) ?? d.id))
          .map((d) => Medicine.fromJson(d.data()))
          .toList();
      await _repo.setAll(items);
      // Remove tombstones that no longer exist remotely
      final remoteIds = snap.docs.map((d) => (d.data()['id'] as String?) ?? d.id).toSet();
      final removed = _pendingDeletes.where((id) => !remoteIds.contains(id)).toList();
      if (removed.isNotEmpty) {
        _pendingDeletes.removeAll(removed);
        await _savePendingDeletes();
      }
      notifyListeners();
    });
  }

  // Manual refresh callable from UI
  Future<void> refresh() async {
    await _syncFromRemoteAndListen();
  }

  Future<void> _syncFromRemoteAndListen() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('medicines');
      final snap = await col.get();
      if (snap.docs.isNotEmpty) {
        // Apply tombstones: delete remotely if an id is marked pending delete locally
        for (final d in snap.docs) {
          final id = (d.data()['id'] as String?) ?? d.id;
          if (_pendingDeletes.contains(id)) {
            try {
              await col.doc(id).delete();
            } catch (_) {}
          }
        }
        final filtered = snap.docs
            .where((d) => !_pendingDeletes.contains((d.data()['id'] as String?) ?? d.id))
            .map((d) => Medicine.fromJson(d.data()))
            .toList();
        await _repo.setAll(filtered);
        // Clear tombstones that no longer exist remotely
        final remoteIds = snap.docs.map((d) => (d.data()['id'] as String?) ?? d.id).toSet();
        final removed = _pendingDeletes.where((id) => !remoteIds.contains(id)).toList();
        if (removed.isNotEmpty) {
          _pendingDeletes.removeAll(removed);
          await _savePendingDeletes();
        }
      } else if (_repo.items.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final m in _repo.items) {
          batch.set(col.doc(m.id), m.toJson());
        }
        await batch.commit();
      }
      _startRemoteListener(col);
    } catch (_) {}
  }

  // Pending delete persistence -------------------------------------------------
  static const _kPendingDeleteKey = 'med_del_pending_v1';
  Future<void> _loadPendingDeletes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPendingDeleteKey) ?? const [];
      _pendingDeletes
        ..clear()
        ..addAll(list);
    } catch (_) {}
  }

  Future<void> _savePendingDeletes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kPendingDeleteKey, _pendingDeletes.toList());
    } catch (_) {}
  }
}