import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'patient_provider.dart';
import '../models/patient.dart';

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

  // Reference to patient provider (registered from UI) so we can check usage before deletion
  PatientProvider? _patientProvider;
  void registerPatientProvider(PatientProvider provider) {
    _patientProvider = provider;
  }

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

    // Ensure all lists are sorted alphabetically (case-insensitive) once loaded
    _sortList(complaints);
    _sortList(planOptions);
    _sortList(treatmentDoneOptions);
    _sortList(medicineOptions);
    _sortList(pastDentalHistory);
    _sortList(pastMedicalHistory);
    _sortList(medicationOptions);
    _sortList(drugAllergyOptions);
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
    // Prevent case-insensitive duplicates
    final exists = target.any((e) => e.toLowerCase() == value.toLowerCase());
    if (!exists) {
      target.add(value);
      _sortList(target);
      await _persist();
      notifyListeners();
    }
  }

  // Returns true if deletion succeeded, false if blocked due to usage
  Future<bool> removeValue(String listKey, String value) async {
    // Load patients if available but not yet loaded
    if (_patientProvider != null && !_patientProvider!.isLoaded) {
      await _patientProvider!.ensureLoaded();
    }
    final patients = _patientProvider?.patients ?? <Patient>[];
    if (_isInUse(listKey, value, patients)) {
      return false; // block deletion
    }
    List<String> target = _target(listKey);
    final removed = target.remove(value);
    if (removed) {
      _sortList(target); // keep sorted after removal
      await _persist();
      notifyListeners();
    }
    return removed;
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

  void _sortList(List<String> list) {
    list.sort((a,b){
      final al = a.toLowerCase();
      final bl = b.toLowerCase();
      final cmp = al.compareTo(bl);
      if (cmp != 0) return cmp;
      return a.compareTo(b); // tie-breaker to keep stable deterministic ordering
    });
  }

  bool _isInUse(String listKey, String value, List<Patient> patients) {
    if (patients.isEmpty) return false;
    switch (listKey) {
      case 'complaints':
        for (final p in patients) {
          for (final s in p.sessions) {
            final cc = s.chiefComplaint?.complaints ?? const [];
            if (cc.any((c) => c.toLowerCase() == value.toLowerCase())) return true;
          }
        }
        return false;
      case 'plan':
        for (final p in patients) {
          for (final s in p.sessions) {
            if (s.planOptions.any((c) => c.toLowerCase() == value.toLowerCase())) return true;
          }
        }
        return false;
      case 'done':
        for (final p in patients) {
          for (final s in p.sessions) {
            if (s.treatmentDoneOptions.any((c) => c.toLowerCase() == value.toLowerCase())) return true;
          }
        }
        return false;
      case 'medicines':
        for (final p in patients) {
          for (final s in p.sessions) {
            if (s.prescription.any((rx) => rx.medicine.toLowerCase() == value.toLowerCase())) return true;
          }
        }
        return false;
      case 'pastDental':
        return patients.any((p) => p.pastDentalHistory.any((e) => e.toLowerCase() == value.toLowerCase()));
      case 'pastMedical':
        return patients.any((p) => p.pastMedicalHistory.any((e) => e.toLowerCase() == value.toLowerCase()));
      case 'dynamicMedications':
        return patients.any((p) => p.currentMedications.any((e) => e.toLowerCase() == value.toLowerCase()));
      case 'drugAllergies':
        return patients.any((p) => p.drugAllergies.any((e) => e.toLowerCase() == value.toLowerCase()));
      default:
        return false;
    }
  }
}
