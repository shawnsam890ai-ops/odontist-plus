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
}
