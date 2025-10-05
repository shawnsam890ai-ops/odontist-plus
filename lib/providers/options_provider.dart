import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Manages dynamic option lists (complaints, plan, treatment done, medicines)
class OptionsProvider extends ChangeNotifier {
  static const _storageKey = 'dynamic_options_v1';

  List<String> complaints = [];
  List<String> planOptions = [];
  List<String> treatmentDoneOptions = [];
  List<String> medicineOptions = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded({
    required List<String> defaultComplaints,
    required List<String> defaultPlan,
    required List<String> defaultTreatmentDone,
    required List<String> defaultMedicines,
  }) async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        complaints = (map['complaints'] as List<dynamic>? ?? []).cast<String>();
        planOptions = (map['plan'] as List<dynamic>? ?? []).cast<String>();
        treatmentDoneOptions = (map['done'] as List<dynamic>? ?? []).cast<String>();
        medicineOptions = (map['medicines'] as List<dynamic>? ?? []).cast<String>();
      } catch (_) {
        // fallback to defaults
      }
    }
    if (complaints.isEmpty) complaints = List.from(defaultComplaints);
    if (planOptions.isEmpty) planOptions = List.from(defaultPlan);
    if (treatmentDoneOptions.isEmpty) treatmentDoneOptions = List.from(defaultTreatmentDone);
    if (medicineOptions.isEmpty) medicineOptions = List.from(defaultMedicines);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode({
      'complaints': complaints,
      'plan': planOptions,
      'done': treatmentDoneOptions,
      'medicines': medicineOptions,
    }));
  }

  Future<void> addValue(String listKey, String value) async {
    value = value.trim();
    if (value.isEmpty) return;
    List<String> target = _target(listKey);
    if (!target.contains(value)) {
      target.add(value);
      await _persist();
      notifyListeners();
    }
  }

  Future<void> removeValue(String listKey, String value) async {
    List<String> target = _target(listKey);
    target.remove(value);
    await _persist();
    notifyListeners();
  }

  List<String> _target(String key) {
    switch (key) {
      case 'complaints':
        return complaints;
      case 'plan':
        return planOptions;
      case 'done':
        return treatmentDoneOptions;
      case 'medicines':
        return medicineOptions;
      default:
        return complaints;
    }
  }
}
