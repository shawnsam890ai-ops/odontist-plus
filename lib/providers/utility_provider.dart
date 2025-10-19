import 'package:flutter/foundation.dart';
import '../repositories/utility_repository.dart';
import '../models/utility_service.dart';
import '../models/utility_payment.dart';
import '../models/bill_entry.dart';
import 'revenue_provider.dart';

class UtilityProvider with ChangeNotifier {
  final UtilityRepository _repo = UtilityRepository();
  final RevenueProvider revenue;
  bool _loaded = false;

  UtilityProvider({required this.revenue});

  List<UtilityService> get services => _repo.services;
  List<UtilityPayment> get payments => _repo.payments;
  List<BillEntry> get bills => _repo.bills;
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _repo.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> addService(String name, {String? regNumber}) async {
    final s = UtilityService(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name, regNumber: regNumber);
    await _repo.addService(s);
    notifyListeners();
  }

  Future<void> updateService(String id, {String? name, String? regNumber, bool? active}) async {
    await _repo.updateService(id, name: name, regNumber: regNumber, active: active);
    notifyListeners();
  }

  Future<void> deleteService(String id) async {
    await _repo.deleteService(id);
    notifyListeners();
  }

  Future<void> addPayment(String serviceId, {required DateTime date, required double amount, String? mode, bool paid = false, String? receiptPath}) async {
    final p = UtilityPayment(serviceId: serviceId, date: date, amount: amount, mode: mode, paid: paid, receiptPath: receiptPath);
    await _repo.addPayment(p);
    // If paid, reflect in revenue as negative amount
    if (paid && amount != 0) {
      final svc = services.firstWhere((s) => s.id == serviceId, orElse: () => UtilityService(id: serviceId, name: 'Utility'));
      final desc = 'Utility: ${svc.name} ${date.year}-${date.month.toString().padLeft(2, '0')}';
      await revenue.removeByDescription(desc); // dedupe if added again
      await revenue.addRevenue(patientId: 'utility', description: desc, amount: -amount);
    }
    notifyListeners();
  }

  Future<void> updatePaymentPaid(String paymentId, bool paid) async {
    final idx = payments.indexWhere((e) => e.id == paymentId);
    if (idx == -1) return;
    final p = payments[idx];
    final updated = UtilityPayment(id: p.id, serviceId: p.serviceId, date: p.date, amount: p.amount, mode: p.mode, paid: paid, receiptPath: p.receiptPath);
    await _repo.updatePayment(updated);
    final svc = services.firstWhere((s) => s.id == p.serviceId, orElse: () => UtilityService(id: p.serviceId, name: 'Utility'));
    final desc = 'Utility: ${svc.name} ${p.date.year}-${p.date.month.toString().padLeft(2, '0')}';
    if (paid) {
      await revenue.removeByDescription(desc);
      await revenue.addRevenue(patientId: 'utility', description: desc, amount: -p.amount);
    } else {
      await revenue.removeByDescription(desc);
    }
    notifyListeners();
  }

  Future<void> deletePayment(String paymentId) async {
    await _repo.deletePayment(paymentId);
    notifyListeners();
  }

  // Bills
  Future<void> addBill({required DateTime date, required String itemName, required double amount, String? receiptPath, String category = 'Other'}) async {
    final b = BillEntry(date: date, itemName: itemName, amount: amount, receiptPath: receiptPath, category: category);
    await _repo.addBill(b);
    // Reflect as negative in revenue
    final desc = 'Bill: $itemName ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await revenue.addRevenue(patientId: 'bill', description: desc, amount: -amount);
    notifyListeners();
  }

  Future<void> deleteBill(String id) async {
    // Remove matching revenue entry before deleting
    try {
      final existing = bills.firstWhere((e) => e.id == id);
      final oldDesc = 'Bill: ${existing.itemName} ${existing.date.year}-${existing.date.month.toString().padLeft(2, '0')}-${existing.date.day.toString().padLeft(2, '0')}';
      await revenue.removeByDescription(oldDesc);
    } catch (_) {}
    await _repo.deleteBill(id);
    notifyListeners();
  }

  Future<void> updateBill(BillEntry updated) async {
    // Remove old revenue entry (based on existing record), then add for updated.
    try {
      final existing = bills.firstWhere((e) => e.id == updated.id);
      final oldDesc = 'Bill: ${existing.itemName} ${existing.date.year}-${existing.date.month.toString().padLeft(2, '0')}-${existing.date.day.toString().padLeft(2, '0')}';
      await revenue.removeByDescription(oldDesc);
    } catch (_) {}
    await _repo.updateBill(updated);
    final newDesc = 'Bill: ${updated.itemName} ${updated.date.year}-${updated.date.month.toString().padLeft(2, '0')}-${updated.date.day.toString().padLeft(2, '0')}';
    await revenue.removeByDescription(newDesc); // dedupe just in case
    await revenue.addRevenue(patientId: 'bill', description: newDesc, amount: -updated.amount);
    notifyListeners();
  }

  Future<void> deleteBills(List<String> ids) async {
    for (final id in ids) {
      try {
        final existing = bills.firstWhere((e) => e.id == id);
        final oldDesc = 'Bill: ${existing.itemName} ${existing.date.year}-${existing.date.month.toString().padLeft(2, '0')}-${existing.date.day.toString().padLeft(2, '0')}';
        await revenue.removeByDescription(oldDesc);
      } catch (_) {}
    }
    await _repo.deleteBills(ids);
    notifyListeners();
  }
}
