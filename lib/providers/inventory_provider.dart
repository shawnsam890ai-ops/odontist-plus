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

  void addLabCost(LabCostItem cost) {
    _labCosts.add(cost);
    notifyListeners();
  }

  double get totalInventoryValue => _items.fold(0.0, (p, e) => p + e.total);
  double get totalLabCost => _labCosts.fold(0.0, (p, e) => p + e.cost);
}
