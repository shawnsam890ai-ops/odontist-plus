import 'package:flutter/foundation.dart';
import '../models/appointment.dart';

class AppointmentProvider with ChangeNotifier {
  final List<Appointment> _appointments = [];

  List<Appointment> get appointments => List.unmodifiable(_appointments);

  void add(Appointment a) {
    _appointments.add(a);
    notifyListeners();
  }

  /// Remove an appointment by id.
  void remove(String id) {
    _appointments.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  List<Appointment> forDay(DateTime day) {
    return _appointments.where((a) => a.dateTime.year == day.year && a.dateTime.month == day.month && a.dateTime.day == day.day).toList();
  }
}
