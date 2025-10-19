import 'package:flutter/foundation.dart';
import '../repositories/lab_registry_repository.dart';
import '../models/lab_vendor.dart';

class LabRegistryProvider with ChangeNotifier {
  final LabRegistryRepository _repo = LabRegistryRepository();
  bool _loaded = false;

  List<LabVendor> get labs => _repo.labs;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _repo.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> addLab(String name, String address, {String? labPhone, String? staffName, String? staffPhone}) async {
    await _repo.addLab(LabVendor(name: name, address: address, labPhone: labPhone, staffName: staffName, staffPhone: staffPhone));
    notifyListeners();
  }

  Future<void> updateLab(String id, {String? name, String? address, String? labPhone, String? staffName, String? staffPhone}) async {
    await _repo.updateLab(id, name: name, address: address, labPhone: labPhone, staffName: staffName, staffPhone: staffPhone);
    notifyListeners();
  }

  Future<void> deleteLab(String id) async {
    await _repo.deleteLab(id);
    notifyListeners();
  }

  Future<void> addProduct(String labId, String name, double rate) async {
    await _repo.addProduct(labId, LabProduct(name: name, rate: rate));
    notifyListeners();
  }

  Future<void> updateProduct(String labId, String productId, {String? name, double? rate}) async {
    await _repo.updateProduct(labId, productId, name: name, rate: rate);
    notifyListeners();
  }

  Future<void> deleteProduct(String labId, String productId) async {
    await _repo.deleteProduct(labId, productId);
    notifyListeners();
  }
}
