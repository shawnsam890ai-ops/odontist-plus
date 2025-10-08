import 'package:uuid/uuid.dart';

class InventoryItem {
  final String id;
  final String name;
  int quantity;
  double unitCost;

  InventoryItem({String? id, required this.name, this.quantity = 0, this.unitCost = 0})
      : id = id ?? const Uuid().v4();

  double get total => quantity * unitCost;
}

class LabCostItem {
  final String id;
  final String description;
  double cost;
  LabCostItem({String? id, required this.description, this.cost = 0}) : id = id ?? const Uuid().v4();
}
