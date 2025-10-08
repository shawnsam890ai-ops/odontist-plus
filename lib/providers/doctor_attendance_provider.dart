import 'package:flutter/foundation.dart';
import '../models/doctor_payment.dart';

class DoctorAttendanceProvider with ChangeNotifier {
  final Map<String, Map<DateTime, bool>> _attendance = {};
  final Map<String, DoctorPaymentTracker> _payments = {};

  Map<String, Map<DateTime, bool>> get attendance => _attendance;
  Iterable<DoctorPaymentTracker> get trackers => _payments.values;

  void mark(String doctorName, DateTime day, bool present) {
    _attendance.putIfAbsent(doctorName, () => {});
    final dateKey = DateTime(day.year, day.month, day.day);
    _attendance[doctorName]![dateKey] = present;
    notifyListeners();
  }

  void ensureDoctor(String doctorName) {
    _payments.putIfAbsent(doctorName, () => DoctorPaymentTracker(doctorName: doctorName));
  }

  void recordPayment(String doctorName, double amount) {
    ensureDoctor(doctorName);
    _payments[doctorName]!.paid += amount;
    notifyListeners();
  }

  void addDue(String doctorName, double amount) {
    ensureDoctor(doctorName);
    _payments[doctorName]!.totalDue += amount;
    notifyListeners();
  }
}
