import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/lab_registry_repository.dart';
import '../models/lab_vendor.dart';

class LabRegistryProvider with ChangeNotifier {
  final LabRegistryRepository _repo = LabRegistryRepository();
  bool _loaded = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _labSub;

  List<LabVendor> get labs => _repo.labs;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _repo.load();
    // Firestore sync for lab vendors
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('lab_registry');
        final snap = await col.get();
        if (snap.docs.isNotEmpty) {
          // Replace local by clearing then adding
          final list = snap.docs.map((d) => LabVendor.fromJson(d.data())).toList();
          await _repo.replaceAll(list);
          _startListener(col);
        } else if (_repo.labs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final l in _repo.labs) {
            batch.set(col.doc(l.id), l.toJson());
          }
          await batch.commit();
          _startListener(col);
        }
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  void _startListener(CollectionReference<Map<String, dynamic>> col) {
    try {
      _labSub?.cancel();
      _labSub = col.snapshots().listen((snap) async {
        final list = snap.docs.map((d) => LabVendor.fromJson(d.data())).toList();
        await _repo.replaceAll(list);
        notifyListeners();
      });
    } catch (_) {}
  }

  Future<void> addLab(String name, String address, {String? labPhone, String? staffName, String? staffPhone}) async {
    final l = LabVendor(name: name, address: address, labPhone: labPhone, staffName: staffName, staffPhone: staffPhone);
    await _repo.addLab(l);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('lab_registry').doc(l.id).set(l.toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateLab(String id, {String? name, String? address, String? labPhone, String? staffName, String? staffPhone}) async {
    await _repo.updateLab(id, name: name, address: address, labPhone: labPhone, staffName: staffName, staffPhone: staffPhone);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final l = _repo.labs.firstWhere((e) => e.id == id);
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('lab_registry').doc(id).set(l.toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> deleteLab(String id) async {
    await _repo.deleteLab(id);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('lab_registry').doc(id).delete();
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> addProduct(String labId, String name, double rate) async {
    await _repo.addProduct(labId, LabProduct(name: name, rate: rate));
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final l = _repo.labs.firstWhere((e) => e.id == labId);
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('lab_registry').doc(labId).set(l.toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateProduct(String labId, String productId, {String? name, double? rate}) async {
    await _repo.updateProduct(labId, productId, name: name, rate: rate);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final l = _repo.labs.firstWhere((e) => e.id == labId);
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('lab_registry').doc(labId).set(l.toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> deleteProduct(String labId, String productId) async {
    await _repo.deleteProduct(labId, productId);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final l = _repo.labs.firstWhere((e) => e.id == labId);
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('lab_registry').doc(labId).set(l.toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _labSub?.cancel();
    super.dispose();
  }
}
