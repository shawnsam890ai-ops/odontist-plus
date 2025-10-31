import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'patient_provider.dart';
import '../models/patient.dart';
import '../core/enums.dart';

// Manages dynamic option lists (complaints, plan, treatment done, medicines)
class OptionsProvider extends ChangeNotifier {
  static const _storageKey = 'dynamic_options_v1';

  List<String> complaints = [];
  List<String> oralFindingsOptions = [];
  List<String> planOptions = [];
  List<String> treatmentDoneOptions = [];
  List<String> medicineOptions = [];
  // New: dynamic list of medicine contents (active ingredients)
  List<String> medicineContents = [];
  List<String> pastDentalHistory = [];
  List<String> pastMedicalHistory = [];
  List<String> medicationOptions = [];
  List<String> drugAllergyOptions = [];
  // New: dynamic list of orthodontic doctors
  List<String> orthoDoctors = [];
  // New: dynamic list of root canal doctors
  List<String> rcDoctors = [];
  // New: dynamic list of prosthodontic doctors
  List<String> prosthoDoctors = [];
  // New: dynamic lists for lab work
  List<String> labNames = [];
  List<String> natureOfWorkOptions = [];
  List<String> toothShades = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _optionsStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  // Reference to patient provider (registered from UI) so we can check usage before deletion
  PatientProvider? _patientProvider;
  void registerPatientProvider(PatientProvider provider) {
    _patientProvider = provider;
  }

  Future<void> ensureLoaded({
    required List<String> defaultComplaints,
    required List<String> defaultOralFindings,
    required List<String> defaultPlan,
    required List<String> defaultTreatmentDone,
    required List<String> defaultMedicines,
    required List<String> defaultPastDental,
    required List<String> defaultPastMedical,
    required List<String> defaultMedicationOptions,
  required List<String> defaultDrugAllergies,
  List<String>? defaultMedicineContents,
    List<String>? defaultOrthoDoctors, // optional to avoid forcing callers now
    List<String>? defaultRcDoctors,
    List<String>? defaultProsthoDoctors,
    List<String>? defaultLabNames,
    List<String>? defaultNatureOfWork,
    List<String>? defaultToothShades,
  }) async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        complaints = (map['complaints'] as List<dynamic>? ?? []).cast<String>();
  oralFindingsOptions = (map['oralFindings'] as List<dynamic>? ?? []).cast<String>();
        planOptions = (map['plan'] as List<dynamic>? ?? []).cast<String>();
        treatmentDoneOptions = (map['done'] as List<dynamic>? ?? []).cast<String>();
  medicineOptions = (map['medicines'] as List<dynamic>? ?? []).cast<String>();
  medicineContents = (map['medicineContents'] as List<dynamic>? ?? []).cast<String>();
        pastDentalHistory = (map['pastDental'] as List<dynamic>? ?? []).cast<String>();
        pastMedicalHistory = (map['pastMedical'] as List<dynamic>? ?? []).cast<String>();
        medicationOptions = (map['dynamicMedications'] as List<dynamic>? ?? []).cast<String>();
        drugAllergyOptions = (map['drugAllergies'] as List<dynamic>? ?? []).cast<String>();
        orthoDoctors = (map['orthoDoctors'] as List<dynamic>? ?? []).cast<String>();
  rcDoctors = (map['rcDoctors'] as List<dynamic>? ?? []).cast<String>();
        prosthoDoctors = (map['prosthoDoctors'] as List<dynamic>? ?? []).cast<String>();
        labNames = (map['labNames'] as List<dynamic>? ?? []).cast<String>();
        natureOfWorkOptions = (map['natureOfWork'] as List<dynamic>? ?? []).cast<String>();
        toothShades = (map['toothShades'] as List<dynamic>? ?? []).cast<String>();
      } catch (_) {
        // fallback to defaults
      }
    }
    if (complaints.isEmpty) complaints = List.from(defaultComplaints);
  if (oralFindingsOptions.isEmpty) oralFindingsOptions = List.from(defaultOralFindings);
    if (planOptions.isEmpty) planOptions = List.from(defaultPlan);
    if (treatmentDoneOptions.isEmpty) treatmentDoneOptions = List.from(defaultTreatmentDone);
  if (medicineOptions.isEmpty) medicineOptions = List.from(defaultMedicines);
  if (medicineContents.isEmpty && (defaultMedicineContents != null)) medicineContents = List.from(defaultMedicineContents);
    if (pastDentalHistory.isEmpty) pastDentalHistory = List.from(defaultPastDental);
    if (pastMedicalHistory.isEmpty) pastMedicalHistory = List.from(defaultPastMedical);
    if (medicationOptions.isEmpty) medicationOptions = List.from(defaultMedicationOptions);
    if (drugAllergyOptions.isEmpty) drugAllergyOptions = List.from(defaultDrugAllergies);
  if (orthoDoctors.isEmpty && (defaultOrthoDoctors != null)) orthoDoctors = List.from(defaultOrthoDoctors);
    if (rcDoctors.isEmpty && (defaultRcDoctors != null)) rcDoctors = List.from(defaultRcDoctors);
    if (prosthoDoctors.isEmpty && (defaultProsthoDoctors != null)) prosthoDoctors = List.from(defaultProsthoDoctors);
    if (labNames.isEmpty && (defaultLabNames != null)) labNames = List.from(defaultLabNames);
    if (natureOfWorkOptions.isEmpty && (defaultNatureOfWork != null)) natureOfWorkOptions = List.from(defaultNatureOfWork);
    if (toothShades.isEmpty && (defaultToothShades != null)) toothShades = List.from(defaultToothShades);

    // Ensure all lists are sorted alphabetically (case-insensitive) once loaded
    _sortList(complaints);
  _sortList(oralFindingsOptions);
    _sortList(planOptions);
    _sortList(treatmentDoneOptions);
  _sortList(medicineOptions);
  _sortList(medicineContents);
    _sortList(pastDentalHistory);
    _sortList(pastMedicalHistory);
    _sortList(medicationOptions);
    _sortList(drugAllergyOptions);
  _sortList(orthoDoctors);
    _sortList(rcDoctors);
    _sortList(prosthoDoctors);
    _sortList(labNames);
    _sortList(natureOfWorkOptions);
    _sortList(toothShades);
    _loaded = true;
    // After local/defaults, try to hydrate from Firestore if available.
    await _loadFromFirestore();
    // Start realtime listener so changes from other devices reflect immediately
    _startListener();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode({
      'complaints': complaints,
      'oralFindings': oralFindingsOptions,
      'plan': planOptions,
      'done': treatmentDoneOptions,
  'medicines': medicineOptions,
  'medicineContents': medicineContents,
      'pastDental': pastDentalHistory,
      'pastMedical': pastMedicalHistory,
      'dynamicMedications': medicationOptions,
      'drugAllergies': drugAllergyOptions,
      'orthoDoctors': orthoDoctors,
      'rcDoctors': rcDoctors,
      'prosthoDoctors': prosthoDoctors,
      'labNames': labNames,
      'natureOfWork': natureOfWorkOptions,
      'toothShades': toothShades,
    }));
    // Firestore write-through (best-effort)
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('settings')
            .doc('options')
            .set({
          'complaints': complaints,
          'oralFindings': oralFindingsOptions,
          'plan': planOptions,
          'done': treatmentDoneOptions,
          'medicines': medicineOptions,
          'medicineContents': medicineContents,
          'pastDental': pastDentalHistory,
          'pastMedical': pastMedicalHistory,
          'dynamicMedications': medicationOptions,
          'drugAllergies': drugAllergyOptions,
          'orthoDoctors': orthoDoctors,
          'rcDoctors': rcDoctors,
          'prosthoDoctors': prosthoDoctors,
          'labNames': labNames,
          'natureOfWork': natureOfWorkOptions,
          'toothShades': toothShades,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // ignore online sync failure
    }
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
      case 'oralFindings':
        return oralFindingsOptions;
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
      case 'orthoDoctors':
        return orthoDoctors;
      case 'rcDoctors':
        return rcDoctors;
      case 'prosthoDoctors':
        return prosthoDoctors;
      case 'labNames':
        return labNames;
      case 'natureOfWork':
        return natureOfWorkOptions;
      case 'toothShades':
        return toothShades;
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
      case 'oralFindings':
        for (final p in patients) {
          for (final s in p.sessions) {
            for (final f in s.oralExamFindings) {
              if (f.finding.toLowerCase() == value.toLowerCase()) return true;
            }
            for (final f in s.rootCanalFindings) {
              if (f.finding.toLowerCase() == value.toLowerCase()) return true;
            }
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
      case 'orthoDoctors':
        // Check if any session references this doctor
        for (final p in patients) {
          for (final s in p.sessions) {
            if (s.orthoDoctorInCharge != null && s.orthoDoctorInCharge!.toLowerCase() == value.toLowerCase()) return true;
          }
        }
        return false;
      case 'rcDoctors':
        for (final p in patients) {
          for (final s in p.sessions) {
            if (s.type == TreatmentType.rootCanal && s.rootCanalDoctorInCharge != null && s.rootCanalDoctorInCharge!.toLowerCase() == value.toLowerCase()) {
              return true;
            }
          }
        }
        return false;
      case 'prosthoDoctors':
        for (final p in patients) {
          for (final s in p.sessions) {
            if (s.type == TreatmentType.prosthodontic && s.prosthodonticDoctorInCharge != null && s.prosthodonticDoctorInCharge!.toLowerCase() == value.toLowerCase()) {
              return true;
            }
          }
        }
        return false;
      case 'labNames':
        for (final p in patients) {
          for (final s in p.sessions) {
            if (s.type == TreatmentType.labWork && s.labName != null && s.labName!.toLowerCase() == value.toLowerCase()) {
              return true;
            }
          }
        }
        return false;
      case 'natureOfWork':
        for (final p in patients) {
          for (final s in p.sessions) {
            if (s.type == TreatmentType.labWork && s.natureOfWork != null && s.natureOfWork!.toLowerCase() == value.toLowerCase()) {
              return true;
            }
          }
        }
        return false;
      case 'toothShades':
        for (final p in patients) {
          for (final s in p.sessions) {
            if (s.type == TreatmentType.labWork && s.toothShade != null && s.toothShade!.toLowerCase() == value.toLowerCase()) {
              return true;
            }
          }
        }
        return false;
      default:
        return false;
    }
  }

  Future<void> _loadFromFirestore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('options')
          .get();
      if (!doc.exists) return;
      final data = doc.data() ?? <String, dynamic>{};
      // Only override if values exist in Firestore; otherwise keep local/defaults
      complaints = (data['complaints'] as List<dynamic>? ?? complaints).cast<String>();
      oralFindingsOptions = (data['oralFindings'] as List<dynamic>? ?? oralFindingsOptions).cast<String>();
      planOptions = (data['plan'] as List<dynamic>? ?? planOptions).cast<String>();
      treatmentDoneOptions = (data['done'] as List<dynamic>? ?? treatmentDoneOptions).cast<String>();
      medicineOptions = (data['medicines'] as List<dynamic>? ?? medicineOptions).cast<String>();
      pastDentalHistory = (data['pastDental'] as List<dynamic>? ?? pastDentalHistory).cast<String>();
      pastMedicalHistory = (data['pastMedical'] as List<dynamic>? ?? pastMedicalHistory).cast<String>();
      medicationOptions = (data['dynamicMedications'] as List<dynamic>? ?? medicationOptions).cast<String>();
      drugAllergyOptions = (data['drugAllergies'] as List<dynamic>? ?? drugAllergyOptions).cast<String>();
      orthoDoctors = (data['orthoDoctors'] as List<dynamic>? ?? orthoDoctors).cast<String>();
      rcDoctors = (data['rcDoctors'] as List<dynamic>? ?? rcDoctors).cast<String>();
      prosthoDoctors = (data['prosthoDoctors'] as List<dynamic>? ?? prosthoDoctors).cast<String>();
      labNames = (data['labNames'] as List<dynamic>? ?? labNames).cast<String>();
      natureOfWorkOptions = (data['natureOfWork'] as List<dynamic>? ?? natureOfWorkOptions).cast<String>();
      toothShades = (data['toothShades'] as List<dynamic>? ?? toothShades).cast<String>();
      // Keep lists sorted
      _sortList(complaints);
      _sortList(oralFindingsOptions);
      _sortList(planOptions);
      _sortList(treatmentDoneOptions);
      _sortList(medicineOptions);
      _sortList(pastDentalHistory);
      _sortList(pastMedicalHistory);
      _sortList(medicationOptions);
      _sortList(drugAllergyOptions);
      _sortList(orthoDoctors);
      _sortList(rcDoctors);
      _sortList(prosthoDoctors);
      _sortList(labNames);
      _sortList(natureOfWorkOptions);
      _sortList(toothShades);
    } catch (_) {}
  }

  void _startListener() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      _sub?.cancel();
      _optionsStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('options')
          .snapshots();
      _sub = _optionsStream!.listen((snap) async {
        if (!snap.exists) return;
        await _loadFromFirestore();
        notifyListeners();
      });
    } catch (_) {}
  }
}
