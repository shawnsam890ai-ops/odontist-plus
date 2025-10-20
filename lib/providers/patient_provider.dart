import 'package:flutter/foundation.dart';
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
    await _repo.addPatient(
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
    notifyListeners();
  }

  Patient? byId(String id) => _repo.getById(id);

  Future<void> updateCustomNumber(String patientId, String customNumber) async {
    await _repo.updateCustomNumber(patientId, customNumber);
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
    notifyListeners();
  }

  Future<void> deletePatient(String patientId) async {
    await _repo.deletePatient(patientId);
    // Remove any revenue entries tied to this patient
    await _revenue?.removeByPatientId(patientId);
    notifyListeners();
  }

  Future<void> addSession(String patientId, TreatmentSession session) async {
    await _repo.addTreatmentSession(patientId, session);
    notifyListeners();
  }

  Future<void> updateSession(String patientId, TreatmentSession session) async {
    await _repo.updateTreatmentSession(patientId, session);
    notifyListeners();
  }

  Future<void> removeSession(String patientId, String sessionId) async {
    await _repo.removeTreatmentSession(patientId, sessionId);
    // Remove any clinic revenue ledger entries recorded for this session
    // These use the format: 'Clinic revenue (ledger): rx:<sessionId>:' as prefix
    await _revenue?.removeByDescriptionPrefix('Clinic revenue (ledger): rx:$sessionId:');
    // Remove medicine/lab profit entries for this session if descriptions use session context
    // If medicines/lab profits were not tagged by session in description, they will remain; that's acceptable.
    notifyListeners();
  }
}
