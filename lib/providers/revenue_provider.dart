import 'package:flutter/foundation.dart';
import '../repositories/revenue_repository.dart';
import '../models/revenue_entry.dart';

class RevenueProvider extends ChangeNotifier {
  final RevenueRepository _repo = RevenueRepository();
  bool _loaded = false;

  List<RevenueEntry> get entries => _repo.entries;
  bool get isLoaded => _loaded;
  double get total => _repo.totalRevenue();

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _repo.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> addRevenue({required String patientId, required String description, required double amount}) async {
    await _repo.addEntry(patientId: patientId, description: description, amount: amount);
    notifyListeners();
  }

  Future<void> removeByDescription(String description) async {
    await _repo.removeByDescription(description);
    notifyListeners();
  }

  Future<int> removeByPatientId(String patientId) async {
    final removed = await _repo.removeByPatientId(patientId);
    if (removed > 0) notifyListeners();
    return removed;
  }

  Future<int> removeByDescriptionPrefix(String prefix) async {
    final removed = await _repo.removeByDescriptionPrefix(prefix);
    if (removed > 0) notifyListeners();
    return removed;
  }

  Future<int> removeByDescriptionForPatient(String patientId, String description) async {
    final removed = await _repo.removeByDescriptionForPatient(patientId, description);
    if (removed > 0) notifyListeners();
    return removed;
  }

  Future<void> clearAll() async {
    await _repo.clearAll();
    notifyListeners();
  }

  Future<bool> removeById(String id) async {
    final ok = await _repo.removeById(id);
    if (ok) notifyListeners();
    return ok;
  }
}
