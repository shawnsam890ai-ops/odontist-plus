import 'package:flutter/foundation.dart';
import '../repositories/lab_repository.dart';
import '../models/lab_work.dart';

class LabProvider extends ChangeNotifier {
  final LabRepository _repo = LabRepository();
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _repo.load();
    _loaded = true;
    notifyListeners();
  }

  List<LabWork> byPatient(String patientId) => _repo.byPatient(patientId);

  Future<void> addWork({
    required String patientId,
    required String labName,
    required String workType,
    required String shade,
    required DateTime expectedDelivery,
    String? attachmentPath,
  }) async {
    await _repo.addWork(
      patientId: patientId,
      labName: labName,
      workType: workType,
      shade: shade,
      expectedDelivery: expectedDelivery,
      attachmentPath: attachmentPath,
    );
    notifyListeners();
  }

  Future<void> markDelivered(String id, bool delivered) async {
    await _repo.markDelivered(id, delivered);
    notifyListeners();
  }
}
