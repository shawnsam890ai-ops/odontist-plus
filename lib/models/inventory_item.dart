import 'package:uuid/uuid.dart';

/// Inventory model covering Instruments and Materials with categories & subcategories.
/// Backward compatible with older fields used by the UI (name, quantity, unitCost, total).
class InventoryItem {
  // Primary identifiers
  final String id; // itemId in Firestore
  final String name; // itemName

  // Core stock fields
  int quantity;
  double unitCost; // costPerUnit

  // Extended fields
  final String category; // Instruments | Materials
  final String subCategory; // e.g., Diagnostic Instruments, Restorative Materials
  final String unit; // pcs, box, bottle, etc.
  final DateTime? expiryDate; // nullable
  final String supplierName;
  final int reorderLevel; // min qty threshold
  DateTime lastUpdated;

  InventoryItem({
    String? id,
    required this.name,
    this.quantity = 0,
    this.unitCost = 0,
    this.category = 'Uncategorized',
    this.subCategory = 'General',
    this.unit = 'pcs',
    this.expiryDate,
    this.supplierName = '',
    this.reorderLevel = 0,
    DateTime? lastUpdated,
  })  : id = id ?? const Uuid().v4(),
        lastUpdated = lastUpdated ?? DateTime.now();

  double get total => quantity * unitCost;

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': id,
        'name': name,
        'itemName': name,
        'quantity': quantity,
        'unitCost': unitCost,
        'costPerUnit': unitCost,
        'category': category,
        'subCategory': subCategory,
        'unit': unit,
        'expiryDate': expiryDate?.toIso8601String(),
        'supplierName': supplierName,
        'reorderLevel': reorderLevel,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
        id: (j['id'] as String?) ?? (j['itemId'] as String?),
        name: (j['name'] as String?) ?? (j['itemName'] as String?) ?? 'Item',
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        unitCost: (j['unitCost'] as num?)?.toDouble() ?? (j['costPerUnit'] as num?)?.toDouble() ?? 0,
        category: (j['category'] as String?) ?? 'Uncategorized',
        subCategory: (j['subCategory'] as String?) ?? 'General',
        unit: (j['unit'] as String?) ?? 'pcs',
        expiryDate: (j['expiryDate'] as String?) != null && (j['expiryDate'] as String).isNotEmpty
            ? DateTime.tryParse(j['expiryDate'] as String)
            : null,
        supplierName: (j['supplierName'] as String?) ?? '',
        reorderLevel: (j['reorderLevel'] as num?)?.toInt() ?? 0,
        lastUpdated: DateTime.tryParse(j['lastUpdated'] as String? ?? '') ?? DateTime.now(),
      );
}

class LabCostItem {
  final String id;
  final String description;
  double cost;
  LabCostItem({String? id, required this.description, this.cost = 0}) : id = id ?? const Uuid().v4();
}
