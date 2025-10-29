import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/utility_repository.dart';
import '../models/utility_service.dart';
import '../models/utility_payment.dart';
import '../models/bill_entry.dart';
import 'revenue_provider.dart';

class UtilityProvider with ChangeNotifier {
  final UtilityRepository _repo = UtilityRepository();
  final RevenueProvider revenue;
  bool _loaded = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _svcSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _paySub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _billSub;

  UtilityProvider({required this.revenue});

  List<UtilityService> get services => _repo.services;
  List<UtilityPayment> get payments => _repo.payments;
  List<BillEntry> get bills => _repo.bills;
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _repo.load();
    // Firestore sync: pull if remote exists; else push local once
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final base = FirebaseFirestore.instance.collection('users').doc(uid);
        final sSnap = await base.collection('utility_services').get();
        final pSnap = await base.collection('utility_payments').get();
        final bSnap = await base.collection('utility_bills').get();

        if (sSnap.docs.isNotEmpty || pSnap.docs.isNotEmpty || bSnap.docs.isNotEmpty) {
          // Replace local by clearing then adding
          for (final s in List<UtilityService>.from(_repo.services)) {
            await _repo.deleteService(s.id);
          }
          for (final d in sSnap.docs) {
            await _repo.addService(UtilityService.fromJson(d.data()));
          }
          // Payments
          for (final p in List<UtilityPayment>.from(_repo.payments)) {
            await _repo.deletePayment(p.id);
          }
          for (final d in pSnap.docs) {
            await _repo.addPayment(UtilityPayment.fromJson(d.data()));
          }
          // Bills
          for (final b in List<BillEntry>.from(_repo.bills)) {}
          for (final d in bSnap.docs) {
            await _repo.addBill(BillEntry.fromJson(d.data()));
          }
          // Start realtime listeners after initial pull
          _startListeners(base);
        } else if (_repo.services.isNotEmpty || _repo.payments.isNotEmpty || _repo.bills.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final s in _repo.services) {
            batch.set(base.collection('utility_services').doc(s.id), s.toJson());
          }
          for (final p in _repo.payments) {
            batch.set(base.collection('utility_payments').doc(p.id), p.toJson());
          }
          for (final b in _repo.bills) {
            batch.set(base.collection('utility_bills').doc(b.id), b.toJson());
          }
          await batch.commit();
          // Start realtime listeners regardless to pick up future changes
          _startListeners(base);
        }
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  void _startListeners(DocumentReference<Map<String, dynamic>> base) {
    try {
      _svcSub?.cancel();
      _svcSub = base.collection('utility_services').snapshots().listen((snap) async {
        final list = snap.docs.map((d) => UtilityService.fromJson(d.data())).toList();
        await _repo.replaceServices(list);
        notifyListeners();
      });
      _paySub?.cancel();
      _paySub = base.collection('utility_payments').snapshots().listen((snap) async {
        final list = snap.docs.map((d) => UtilityPayment.fromJson(d.data())).toList();
        await _repo.replacePayments(list);
        notifyListeners();
      });
      _billSub?.cancel();
      _billSub = base.collection('utility_bills').snapshots().listen((snap) async {
        final list = snap.docs.map((d) => BillEntry.fromJson(d.data())).toList();
        await _repo.replaceBills(list);
        notifyListeners();
      });
    } catch (_) {}
  }

  Future<void> addService(String name, {String? regNumber}) async {
    final s = UtilityService(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name, regNumber: regNumber);
    await _repo.addService(s);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('utility_services').doc(s.id).set(s.toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateService(String id, {String? name, String? regNumber, bool? active}) async {
    await _repo.updateService(id, name: name, regNumber: regNumber, active: active);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final s = _repo.services.firstWhere((e) => e.id == id);
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('utility_services').doc(id).set(s.toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> deleteService(String id) async {
    await _repo.deleteService(id);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('utility_services').doc(id).delete();
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> addPayment(String serviceId, {required DateTime date, required double amount, String? mode, bool paid = false, String? receiptPath}) async {
    final p = UtilityPayment(serviceId: serviceId, date: date, amount: amount, mode: mode, paid: paid, receiptPath: receiptPath);
    await _repo.addPayment(p);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('utility_payments').doc(p.id).set(p.toJson());
      }
    } catch (_) {}
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
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('utility_payments').doc(paymentId).set(updated.toJson());
      }
    } catch (_) {}
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
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('utility_payments').doc(paymentId).delete();
      }
    } catch (_) {}
    notifyListeners();
  }

  // Bills
  Future<void> addBill({required DateTime date, required String itemName, required double amount, String? receiptPath, String category = 'Other'}) async {
    final b = BillEntry(date: date, itemName: itemName, amount: amount, receiptPath: receiptPath, category: category);
    await _repo.addBill(b);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('utility_bills').doc(b.id).set(b.toJson());
      }
    } catch (_) {}
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
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('utility_bills').doc(id).delete();
      }
    } catch (_) {}
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
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('utility_bills').doc(updated.id).set(updated.toJson());
      }
    } catch (_) {}
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
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final base = FirebaseFirestore.instance.collection('users').doc(uid).collection('utility_bills');
        final batch = FirebaseFirestore.instance.batch();
        for (final id in ids) {
          batch.delete(base.doc(id));
        }
        await batch.commit();
      }
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _svcSub?.cancel();
    _paySub?.cancel();
    _billSub?.cancel();
    super.dispose();
  }
}
