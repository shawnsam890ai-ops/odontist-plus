import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/lab_work.dart';

class LabRepository {
  static const _storageKey = 'lab_work_v1';
  final _uuid = const Uuid();
  List<LabWork> _works = [];

  List<LabWork> byPatient(String patientId) => _works.where((w) => w.patientId == patientId).toList();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _works = list.map((e) => LabWork.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_works.map((e) => e.toJson()).toList()));
  }

  Future<LabWork> addWork({
    required String patientId,
    required String labName,
    required String workType,
    required String shade,
    required DateTime expectedDelivery,
    String? attachmentPath,
  }) async {
    final work = LabWork(
      id: _uuid.v4(),
      patientId: patientId,
      labName: labName,
      workType: workType,
      shade: shade,
      expectedDelivery: expectedDelivery,
      attachmentPath: attachmentPath,
    );
    _works.add(work);
    await _persist();
    return work;
  }

  Future<void> markDelivered(String id, bool delivered) async {
    final idx = _works.indexWhere((w) => w.id == id);
    if (idx == -1) return;
    final w = _works[idx];
    _works[idx] = w.copyWith(delivered: delivered);
    await _persist();
  }
}
