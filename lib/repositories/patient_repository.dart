import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/patient.dart';
import '../models/treatment_session.dart';
import '../core/enums.dart';

class PatientRepository {
  static const _storageKey = 'patients_v1';
  final _uuid = const Uuid();
  List<Patient> _patients = [];

  List<Patient> get patients => List.unmodifiable(_patients);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _patients = list.map((e) => Patient.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_patients.map((e) => e.toJson()).toList()));
  }

  Future<Patient> addPatient({
    required String name,
    required int age,
    required Sex sex,
    required String address,
    required String phone,
  }) async {
    final patient = Patient(
      id: _uuid.v4(),
      displayNumber: _patients.length + 1,
      name: name,
      age: age,
      sex: sex,
      address: address,
      phone: phone,
      createdAt: DateTime.now(),
    );
    _patients.add(patient);
    await _persist();
    return patient;
  }

  Future<void> updateCustomNumber(String patientId, String customNumber) async {
    final index = _patients.indexWhere((p) => p.id == patientId);
    if (index == -1) return;
    _patients[index] = _patients[index].copyWith(customNumber: customNumber);
    await _persist();
  }

  Future<void> deletePatient(String patientId) async {
    _patients.removeWhere((p) => p.id == patientId);
    // Reindex displayNumber sequentially
    for (int i = 0; i < _patients.length; i++) {
      _patients[i] = _patients[i].copyWith(displayNumber: i + 1);
    }
    await _persist();
  }

  Patient? getById(String id) => _patients.firstWhere((p) => p.id == id, orElse: () => null as Patient);

  Future<void> addTreatmentSession(String patientId, TreatmentSession session) async {
    final idx = _patients.indexWhere((p) => p.id == patientId);
    if (idx == -1) return;
    final patient = _patients[idx];
    final updatedSessions = List<TreatmentSession>.from(patient.sessions)..add(session);
    _patients[idx] = patient.copyWith(sessions: updatedSessions);
    await _persist();
  }

  Future<void> updateTreatmentSession(String patientId, TreatmentSession session) async {
    final idx = _patients.indexWhere((p) => p.id == patientId);
    if (idx == -1) return;
    final patient = _patients[idx];
    final sessions = List<TreatmentSession>.from(patient.sessions);
    final sIdx = sessions.indexWhere((s) => s.id == session.id);
    if (sIdx == -1) return;
    sessions[sIdx] = session;
    _patients[idx] = patient.copyWith(sessions: sessions);
    await _persist();
  }
}
