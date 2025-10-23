import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/patient_repository.dart';
import '../models/patient.dart';
import '../models/treatment_session.dart';
import '../core/enums.dart';
import 'revenue_provider.dart';

class PatientProvider extends ChangeNotifier {
  final PatientRepository _repo = PatientRepository();
  RevenueProvider? _revenue;
  bool _loaded = false;

  List<Patient> get patients => _repo.patients;
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _repo.load();
    // Attempt to pull from Firestore and replace local cache
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('patients')
            .get();
        if (snap.docs.isNotEmpty) {
          final items = snap.docs.map((d) => Patient.fromJson(d.data())).toList();
          await _repo.replaceAll(items);
        } else if (_repo.patients.isNotEmpty) {
          // First-time migration: push local cache to Firestore
          final batch = FirebaseFirestore.instance.batch();
          final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('patients');
          for (final p in _repo.patients) {
            batch.set(col.doc(p.id), p.toJson());
          }
          await batch.commit();
        }
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  // Called from main to register cross-provider dependency without cyclic constructor.
  void registerRevenueProvider(RevenueProvider revenue) {
    _revenue = revenue;
  }

  Future<void> addPatient({
    required String name,
    required int age,
    required Sex sex,
    required String address,
    required String phone,
    List<String>? pastDentalHistory,
    List<String>? pastMedicalHistory,
    List<String>? currentMedications,
    List<String>? drugAllergies,
    bool? pregnant,
    bool? breastfeeding,
  }) async {
    final patient = await _repo.addPatient(
      name: name,
      age: age,
      sex: sex,
      address: address,
      phone: phone,
      pastDentalHistory: pastDentalHistory,
      pastMedicalHistory: pastMedicalHistory,
      currentMedications: currentMedications,
      drugAllergies: drugAllergies,
      pregnant: pregnant,
      breastfeeding: breastfeeding,
    );
    // Mirror to Firestore
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('patients').doc(patient.id).set(patient.toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  Patient? byId(String id) => _repo.getById(id);

  Future<void> updateCustomNumber(String patientId, String customNumber) async {
    await _repo.updateCustomNumber(patientId, customNumber);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final p = _repo.getById(patientId);
        if (p != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).collection('patients').doc(patientId).set(p.toJson());
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updatePatient({
    required String patientId,
    String? name,
    int? age,
    Sex? sex,
    String? address,
    String? phone,
    List<String>? pastDentalHistory,
    List<String>? pastMedicalHistory,
    List<String>? currentMedications,
    List<String>? drugAllergies,
    bool? pregnant,
    bool? breastfeeding,
  }) async {
    await _repo.updatePatient(
      patientId: patientId,
      name: name,
      age: age,
      sex: sex,
      address: address,
      phone: phone,
      pastDentalHistory: pastDentalHistory,
      pastMedicalHistory: pastMedicalHistory,
      currentMedications: currentMedications,
      drugAllergies: drugAllergies,
      pregnant: pregnant,
      breastfeeding: breastfeeding,
    );
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final p = _repo.getById(patientId);
        if (p != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).collection('patients').doc(patientId).set(p.toJson());
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> deletePatient(String patientId) async {
    await _repo.deletePatient(patientId);
    // Remove any revenue entries tied to this patient
    await _revenue?.removeByPatientId(patientId);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('patients').doc(patientId).delete();
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> addSession(String patientId, TreatmentSession session) async {
    await _repo.addTreatmentSession(patientId, session);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final p = _repo.getById(patientId);
        if (p != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).collection('patients').doc(patientId).set(p.toJson());
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateSession(String patientId, TreatmentSession session) async {
    await _repo.updateTreatmentSession(patientId, session);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final p = _repo.getById(patientId);
        if (p != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).collection('patients').doc(patientId).set(p.toJson());
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> removeSession(String patientId, String sessionId) async {
    await _repo.removeTreatmentSession(patientId, sessionId);
    // Remove any clinic revenue ledger entries recorded for this session
    // These use the format: 'Clinic revenue (ledger): rx:<sessionId>:' as prefix
    await _revenue?.removeByDescriptionPrefix('Clinic revenue (ledger): rx:$sessionId:');
    // Remove medicine/lab profit entries for this session if descriptions use session context
    // If medicines/lab profits were not tagged by session in description, they will remain; that's acceptable.
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final p = _repo.getById(patientId);
        if (p != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).collection('patients').doc(patientId).set(p.toJson());
        }
      }
    } catch (_) {}
    notifyListeners();
  }
}
