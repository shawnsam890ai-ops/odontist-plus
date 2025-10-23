import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/medicine_repository.dart';
import '../models/medicine.dart';

class MedicineProvider with ChangeNotifier {
  final MedicineRepository _repo = MedicineRepository();
  bool _loaded = false;

  List<Medicine> get medicines => _repo.items;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _repo.load();
    // Firestore sync: pull remote if exists; else push local once
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('medicines');
        final snap = await col.get();
        if (snap.docs.isNotEmpty) {
          final items = snap.docs.map((d) => Medicine.fromJson(d.data())).toList();
          // Replace local cache
          // There is no replaceAll in repo; rebuild storage by clearing and re-adding
          for (final m in List<Medicine>.from(_repo.items)) {
            await _repo.delete(m.id);
          }
          for (final m in items) {
            await _repo.add(
              name: m.name,
              storeAmount: m.storeAmount,
              mrp: m.mrp,
              strips: m.stripsAvailable,
              unitsPerStrip: m.unitsPerStrip,
            );
          }
        } else if (_repo.items.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final m in _repo.items) {
            batch.set(col.doc(m.id), m.toJson());
          }
          await batch.commit();
        }
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> addMedicine({required String name, required double storeAmount, required double mrp, required int strips, int unitsPerStrip = 10}) async {
    final m = await _repo.add(name: name, storeAmount: storeAmount, mrp: mrp, strips: strips, unitsPerStrip: unitsPerStrip);
    // Mirror to Firestore
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('medicines').doc(m.id).set(m.toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateMedicine(String id, {String? name, double? storeAmount, double? mrp, int? strips, int? unitsPerStrip}) async {
    await _repo.update(id, name: name, storeAmount: storeAmount, mrp: mrp, strips: strips, unitsPerStrip: unitsPerStrip);
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
      }
    } catch (_) {}
    notifyListeners();
  }
}