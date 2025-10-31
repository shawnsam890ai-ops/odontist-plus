import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/inventory_item.dart';

class InventoryProvider with ChangeNotifier {
  final List<InventoryItem> _items = [];
  final List<LabCostItem> _labCosts = [];
  bool _loaded = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _invSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _costSub;

  List<InventoryItem> get items => List.unmodifiable(_items);
  List<LabCostItem> get labCosts => List.unmodifiable(_labCosts);

  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final base = FirebaseFirestore.instance.collection('users').doc(uid);
        final invSnap = await base.collection('inventory').get();
        _items
          ..clear()
          ..addAll(invSnap.docs.map((d) => InventoryItem.fromJson(d.data())));
        final costSnap = await base.collection('lab_costs').get();
        _labCosts
          ..clear()
          ..addAll(costSnap.docs.map((d) {
            final m = d.data();
            return LabCostItem(
              id: m['id'] as String? ?? d.id,
              description: (m['description'] as String?) ?? '',
              cost: (m['cost'] as num?)?.toDouble() ?? 0,
            );
          }));

        // Start realtime listeners
        _startListeners(base);
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  void _startListeners(DocumentReference<Map<String, dynamic>> base) {
    try {
      _invSub?.cancel();
      _invSub = base.collection('inventory').snapshots().listen((snap) {
        _items
          ..clear()
          ..addAll(snap.docs.map((d) => InventoryItem.fromJson(d.data())));
        notifyListeners();
      });

      _costSub?.cancel();
      _costSub = base.collection('lab_costs').snapshots().listen((snap) {
        _labCosts
          ..clear()
          ..addAll(snap.docs.map((d) {
            final m = d.data();
            return LabCostItem(
              id: m['id'] as String? ?? d.id,
              description: (m['description'] as String?) ?? '',
              cost: (m['cost'] as num?)?.toDouble() ?? 0,
            );
          }));
        notifyListeners();
      });
    } catch (_) {}
  }

  void addItem(InventoryItem item) {
    _items.add(item);
    // Write-through to Firestore
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('inventory')
            .doc(item.id)
            .set(item.toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  void updateItem(String id, {int? quantity, double? unitCost, String? name, String? category, String? subCategory, String? unit, DateTime? expiryDate, String? supplierName, int? reorderLevel}) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final item = _items[idx];
    if (quantity != null) item.quantity = quantity;
    if (unitCost != null) item.unitCost = unitCost;
    final newName = (name != null && name.trim().isNotEmpty) ? name.trim() : item.name;
    _items[idx] = InventoryItem(
      id: item.id,
      name: newName,
      quantity: item.quantity,
      unitCost: item.unitCost,
      category: category ?? item.category,
      subCategory: subCategory ?? item.subCategory,
      unit: unit ?? item.unit,
      expiryDate: expiryDate ?? item.expiryDate,
      supplierName: supplierName ?? item.supplierName,
      reorderLevel: reorderLevel ?? item.reorderLevel,
      lastUpdated: DateTime.now(),
    );
    // Mirror to Firestore
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('inventory')
            .doc(id)
            .set(_items[idx].toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((e) => e.id == id);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        FirebaseFirestore.instance.collection('users').doc(uid).collection('inventory').doc(id).delete();
      }
    } catch (_) {}
    notifyListeners();
  }

  void addLabCost(LabCostItem cost) {
    _labCosts.add(cost);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        FirebaseFirestore.instance.collection('users').doc(uid).collection('lab_costs').doc(cost.id).set({
          'id': cost.id,
          'description': cost.description,
          'cost': cost.cost,
        });
      }
    } catch (_) {}
    notifyListeners();
  }

  void updateLabCost(String id, {double? cost, String? description}) {
    final idx = _labCosts.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final existing = _labCosts[idx];
    _labCosts[idx] = LabCostItem(
        id: existing.id,
        description: description != null && description.trim().isNotEmpty ? description.trim() : existing.description,
        cost: cost ?? existing.cost);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final v = _labCosts[idx];
        FirebaseFirestore.instance.collection('users').doc(uid).collection('lab_costs').doc(id).set({
          'id': v.id,
          'description': v.description,
          'cost': v.cost,
        });
      }
    } catch (_) {}
    notifyListeners();
  }

  void removeLabCost(String id) {
    _labCosts.removeWhere((e) => e.id == id);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        FirebaseFirestore.instance.collection('users').doc(uid).collection('lab_costs').doc(id).delete();
      }
    } catch (_) {}
    notifyListeners();
  }

  double get totalInventoryValue => _items.fold(0.0, (p, e) => p + e.total);
  double get totalLabCost => _labCosts.fold(0.0, (p, e) => p + e.cost);

  @override
  void dispose() {
    _invSub?.cancel();
    _costSub?.cancel();
    super.dispose();
  }
}
