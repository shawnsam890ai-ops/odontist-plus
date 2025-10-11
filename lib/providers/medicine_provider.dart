import 'package:flutter/foundation.dart';
import '../repositories/medicine_repository.dart';
import '../models/medicine.dart';

class MedicineProvider with ChangeNotifier {
  final MedicineRepository _repo = MedicineRepository();
  bool _loaded = false;

  List<Medicine> get medicines => _repo.items;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _repo.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> addMedicine({required String name, required double storeAmount, required double mrp, required int strips}) async {
    await _repo.add(name: name, storeAmount: storeAmount, mrp: mrp, strips: strips);
    notifyListeners();
  }

  Future<void> updateMedicine(String id, {String? name, double? storeAmount, double? mrp, int? strips}) async {
    await _repo.update(id, name: name, storeAmount: storeAmount, mrp: mrp, strips: strips);
    notifyListeners();
  }

  Future<void> deleteMedicine(String id) async {
    await _repo.delete(id);
    notifyListeners();
  }
}