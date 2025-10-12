import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/utility_service.dart';
import '../models/utility_payment.dart';

class UtilityRepository {
  static const _kServices = 'utility_services_v1';
  static const _kPayments = 'utility_payments_v1';

  final List<UtilityService> _services = [];
  final List<UtilityPayment> _payments = [];

  List<UtilityService> get services => List.unmodifiable(_services);
  List<UtilityPayment> get payments => List.unmodifiable(_payments);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Services
    _services.clear();
    final s = prefs.getString(_kServices);
    if (s != null && s.isNotEmpty) {
      final list = List<dynamic>.from(jsonDecode(s));
      for (final m in list) {
        _services.add(UtilityService.fromJson(Map<String, dynamic>.from(m as Map)));
      }
    }
    // Payments
    _payments.clear();
    final p = prefs.getString(_kPayments);
    if (p != null && p.isNotEmpty) {
      final list = List<dynamic>.from(jsonDecode(p));
      for (final m in list) {
        _payments.add(UtilityPayment.fromJson(Map<String, dynamic>.from(m as Map)));
      }
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServices, jsonEncode(_services.map((e) => e.toJson()).toList()));
    await prefs.setString(_kPayments, jsonEncode(_payments.map((e) => e.toJson()).toList()));
  }

  Future<void> addService(UtilityService s) async {
    _services.add(s);
    await _persist();
  }

  Future<void> updateService(String id, {String? name, String? regNumber, bool? active}) async {
    final idx = _services.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final s = _services[idx];
    if (name != null) s.name = name;
    if (regNumber != null) s.regNumber = regNumber;
    if (active != null) s.active = active;
    await _persist();
  }

  Future<void> deleteService(String id) async {
    _services.removeWhere((e) => e.id == id);
    _payments.removeWhere((e) => e.serviceId == id);
    await _persist();
  }

  Future<void> addPayment(UtilityPayment p) async {
    _payments.add(p);
    await _persist();
  }

  Future<void> updatePayment(UtilityPayment p) async {
    final idx = _payments.indexWhere((e) => e.id == p.id);
    if (idx == -1) return;
    _payments[idx] = p;
    await _persist();
  }

  Future<void> deletePayment(String id) async {
    _payments.removeWhere((e) => e.id == id);
    await _persist();
  }
}
