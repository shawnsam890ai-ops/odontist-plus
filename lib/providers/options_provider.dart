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
  List<String> pastDentalHistory = [];
  List<String> pastMedicalHistory = [];
  List<String> medicationOptions = [];
  List<String> drugAllergyOptions = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded({
    required List<String> defaultComplaints,
    required List<String> defaultPlan,
    required List<String> defaultTreatmentDone,
    required List<String> defaultMedicines,
    required List<String> defaultPastDental,
    required List<String> defaultPastMedical,
    required List<String> defaultMedicationOptions,
    required List<String> defaultDrugAllergies,
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
        pastDentalHistory = (map['pastDental'] as List<dynamic>? ?? []).cast<String>();
        pastMedicalHistory = (map['pastMedical'] as List<dynamic>? ?? []).cast<String>();
        medicationOptions = (map['dynamicMedications'] as List<dynamic>? ?? []).cast<String>();
        drugAllergyOptions = (map['drugAllergies'] as List<dynamic>? ?? []).cast<String>();
      } catch (_) {
        // fallback to defaults
      }
    }
    if (complaints.isEmpty) complaints = List.from(defaultComplaints);
    if (planOptions.isEmpty) planOptions = List.from(defaultPlan);
    if (treatmentDoneOptions.isEmpty) treatmentDoneOptions = List.from(defaultTreatmentDone);
  if (medicineOptions.isEmpty) medicineOptions = List.from(defaultMedicines);
  if (pastDentalHistory.isEmpty) pastDentalHistory = List.from(defaultPastDental);
  if (pastMedicalHistory.isEmpty) pastMedicalHistory = List.from(defaultPastMedical);
  if (medicationOptions.isEmpty) medicationOptions = List.from(defaultMedicationOptions);
  if (drugAllergyOptions.isEmpty) drugAllergyOptions = List.from(defaultDrugAllergies);
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
      'pastDental': pastDentalHistory,
      'pastMedical': pastMedicalHistory,
      'dynamicMedications': medicationOptions,
      'drugAllergies': drugAllergyOptions,
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
      case 'pastDental':
        return pastDentalHistory;
      case 'pastMedical':
        return pastMedicalHistory;
      case 'dynamicMedications':
        return medicationOptions;
      case 'drugAllergies':
        return drugAllergyOptions;
      default:
        return complaints;
    }
  }
}
