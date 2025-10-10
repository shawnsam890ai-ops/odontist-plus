import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lab_vendor.dart';

class LabRegistryRepository {
  static const _key = 'lab_registry_v1';
  List<LabVendor> _labs = [];

  List<LabVendor> get labs => List.unmodifiable(_labs);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _labs = list.map((e) => LabVendor.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_labs.map((e) => e.toJson()).toList()));
  }

  Future<void> addLab(LabVendor lab) async {
    _labs.add(lab);
    await _persist();
  }

  Future<void> updateLab(String id, {String? name, String? address}) async {
    final idx = _labs.indexWhere((l) => l.id == id);
    if (idx == -1) return;
    final l = _labs[idx];
    _labs[idx] = LabVendor(id: l.id, name: name ?? l.name, address: address ?? l.address, products: l.products);
    await _persist();
  }

  Future<void> deleteLab(String id) async {
    _labs.removeWhere((l) => l.id == id);
    await _persist();
  }

  Future<void> addProduct(String labId, LabProduct p) async {
    final l = _labs.firstWhere((e) => e.id == labId, orElse: () => throw ArgumentError('Lab not found'));
    l.products.add(p);
    await _persist();
  }

  Future<void> updateProduct(String labId, String productId, {String? name, double? rate}) async {
    final l = _labs.firstWhere((e) => e.id == labId, orElse: () => throw ArgumentError('Lab not found'));
    final idx = l.products.indexWhere((e) => e.id == productId);
    if (idx == -1) return;
    final p = l.products[idx];
    l.products[idx] = LabProduct(id: p.id, name: name ?? p.name, rate: rate ?? p.rate);
    await _persist();
  }

  Future<void> deleteProduct(String labId, String productId) async {
    final l = _labs.firstWhere((e) => e.id == labId, orElse: () => throw ArgumentError('Lab not found'));
    l.products.removeWhere((e) => e.id == productId);
    await _persist();
  }
}
