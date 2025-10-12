import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/revenue_entry.dart';

class RevenueRepository {
  static const _storageKey = 'revenue_v1';
  final _uuid = const Uuid();
  List<RevenueEntry> _entries = [];

  List<RevenueEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _entries = list.map((e) => RevenueEntry.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }

  Future<RevenueEntry> addEntry({required String patientId, required String description, required double amount}) async {
    final entry = RevenueEntry(
      id: _uuid.v4(),
      date: DateTime.now(),
      patientId: patientId,
      description: description,
      amount: amount,
    );
    _entries.add(entry);
    await _persist();
    return entry;
  }

  Future<int> removeByDescription(String description) async {
    final before = _entries.length;
    _entries.removeWhere((e) => e.description == description);
    if (before != _entries.length) {
      await _persist();
    }
    return before - _entries.length;
  }

  double totalRevenue() => _entries.fold(0, (p, e) => p + e.amount);
}
