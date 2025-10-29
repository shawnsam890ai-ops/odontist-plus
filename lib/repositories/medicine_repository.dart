import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/medicine.dart';

class MedicineRepository {
  static const _key = 'medicines_v1';
  final _uuid = const Uuid();
  List<Medicine> _items = [];

  List<Medicine> get items => List.unmodifiable(_items);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _items = list.map((e) => Medicine.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  Future<Medicine> add({String? id, required String name, required double storeAmount, required double mrp, required int strips, int unitsPerStrip = 10, int freeStrips = 0, int looseTabs = 0}) async {
    final m = Medicine(
      id: id ?? _uuid.v4(),
      name: name,
      storeAmount: storeAmount,
      mrp: mrp,
      stripsAvailable: strips,
      unitsPerStrip: unitsPerStrip,
      freeStrips: freeStrips,
      looseTabs: looseTabs,
    );
    _items.add(m);
    await _persist();
    return m;
  }

  Future<void> setAll(List<Medicine> items) async {
    _items = List<Medicine>.from(items);
    await _persist();
  }

  Future<void> update(String id, {String? name, double? storeAmount, double? mrp, int? strips, int? unitsPerStrip, int? freeStrips, int? looseTabs}) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final cur = _items[i];
    _items[i] = Medicine(
      id: cur.id,
      name: name ?? cur.name,
      storeAmount: storeAmount ?? cur.storeAmount,
      mrp: mrp ?? cur.mrp,
      stripsAvailable: strips ?? cur.stripsAvailable,
      unitsPerStrip: unitsPerStrip ?? cur.unitsPerStrip,
      freeStrips: freeStrips ?? cur.freeStrips,
      looseTabs: looseTabs ?? cur.looseTabs,
    );
    await _persist();
  }

  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _persist();
  }
}