import 'package:flutter/foundation.dart';
import '../repositories/patient_repository.dart';
import '../models/patient.dart';
import '../models/treatment_session.dart';
import '../core/enums.dart';

class PatientProvider extends ChangeNotifier {
  final PatientRepository _repo = PatientRepository();
  bool _loaded = false;

  List<Patient> get patients => _repo.patients;
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _repo.load();
    _loaded = true;
    notifyListeners();
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
    );
    notifyListeners();
  }

  Patient? byId(String id) => _repo.getById(id);

  Future<void> updateCustomNumber(String patientId, String customNumber) async {
    await _repo.updateCustomNumber(patientId, customNumber);
    notifyListeners();
  }

  Future<void> deletePatient(String patientId) async {
    await _repo.deletePatient(patientId);
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
    notifyListeners();
  }
}
