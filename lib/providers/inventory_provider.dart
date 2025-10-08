import 'package:flutter/foundation.dart';
import '../models/inventory_item.dart';

class InventoryProvider with ChangeNotifier {
  final List<InventoryItem> _items = [];
  final List<LabCostItem> _labCosts = [];

  List<InventoryItem> get items => List.unmodifiable(_items);
  List<LabCostItem> get labCosts => List.unmodifiable(_labCosts);

  void addItem(InventoryItem item) {
    _items.add(item);
    notifyListeners();
  }

  void updateItem(String id, {int? quantity, double? unitCost, String? name}) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final item = _items[idx];
    if (quantity != null) item.quantity = quantity;
    if (unitCost != null) item.unitCost = unitCost;
    if (name != null && name.trim().isNotEmpty) _items[idx] = InventoryItem(id: item.id, name: name.trim(), quantity: item.quantity, unitCost: item.unitCost);
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void addLabCost(LabCostItem cost) {
    _labCosts.add(cost);
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
    notifyListeners();
  }

  void removeLabCost(String id) {
    _labCosts.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  double get totalInventoryValue => _items.fold(0.0, (p, e) => p + e.total);
  double get totalLabCost => _labCosts.fold(0.0, (p, e) => p + e.cost);
}
