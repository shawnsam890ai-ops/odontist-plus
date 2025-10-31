import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/inventory_item.dart';

/// Firestore paths
/// users/{uid}/inventory -> collection of inventory items (flat), fields include category & subCategory.
class InventoryService {
  InventoryService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _itemsCol(String uid) =>
      _db.collection('users').doc(uid).collection('inventory');

  Future<String?> _uid() async {
    final user = _auth.currentUser;
    return user?.uid;
  }

  /// Add a new item
  Future<void> addItem(InventoryItem item) async {
    final uid = await _uid();
    if (uid == null) throw StateError('Not signed in');
    await _itemsCol(uid).doc(item.id).set(item.toJson());
  }

  /// Update stock quantity (absolute or delta). If [isDelta] is true, adds to the current quantity.
  Future<void> updateStockQuantity({required String itemId, required int quantity, bool isDelta = true}) async {
    final uid = await _uid();
    if (uid == null) throw StateError('Not signed in');
    final ref = _itemsCol(uid).doc(itemId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>?;
      final prev = (data?['quantity'] as num?)?.toInt() ?? 0;
      final newQty = isDelta ? prev + quantity : quantity;
      tx.set(ref, {
        ...?data,
        'id': itemId,
        'quantity': newQty,
        'lastUpdated': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    });
  }

  /// Fetch all items under a category (optionally by subCategory) as a live stream.
  Stream<List<InventoryItem>> fetchByCategory({required String category, String? subCategory}) async* {
    final uid = await _uid();
    if (uid == null) throw StateError('Not signed in');
    Query<Map<String, dynamic>> q = _itemsCol(uid).where('category', isEqualTo: category);
    if (subCategory != null && subCategory.isNotEmpty) {
      q = q.where('subCategory', isEqualTo: subCategory);
    }
    yield* q.snapshots().map((snap) => snap.docs.map((d) => InventoryItem.fromJson(d.data())).toList());
  }
}

/// Suggested category constants
class InventoryCategories {
  static const instruments = 'Instruments';
  static const materials = 'Materials';
}

class InstrumentSubcategories {
  static const diagnostic = 'Diagnostic Instruments';
  static const rotary = 'Rotary Instruments';
  static const surgical = 'Surgical Instruments';
  static const endodontic = 'Endodontic Instruments';
  static const periodontal = 'Periodontal Instruments';
  static const prosthodontic = 'Prosthodontic Instruments';
}

class MaterialSubcategories {
  static const restorative = 'Restorative Materials';
  static const impression = 'Impression Materials';
  static const endodontic = 'Endodontic Materials';
  static const prosthodontic = 'Prosthodontic Materials';
  static const preventive = 'Preventive Materials';
  static const surgical = 'Surgical Materials';
  static const disposables = 'Disposables';
}

/*
Example Firestore document (users/{uid}/inventory/{itemId})
{
  id: "3e2b...",
  itemId: "3e2b...",
  name: "GIC Type II",
  itemName: "GIC Type II",
  category: "Materials",
  subCategory: "Restorative Materials",
  quantity: 12,
  unit: "box",
  unitCost: 450.0,
  costPerUnit: 450.0,
  expiryDate: "2026-05-01T00:00:00.000Z",
  supplierName: "DentalSupplies Co.",
  reorderLevel: 3,
  lastUpdated: "2025-11-01T07:30:00.000Z"
}
*/
