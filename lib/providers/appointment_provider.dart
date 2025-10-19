import 'package:flutter/foundation.dart';
import '../models/appointment.dart';
import '../services/notification_service.dart';

class AppointmentProvider with ChangeNotifier {
  final List<Appointment> _appointments = [];

  List<Appointment> get appointments => List.unmodifiable(_appointments);

  void add(Appointment a) {
    _appointments.add(a);
    _scheduleIfNeeded(a);
    notifyListeners();
  }

  /// Remove an appointment by id.
  void remove(String id) {
    _appointments.removeWhere((a) => a.id == id);
    _cancelNotification(id);
    notifyListeners();
  }

  List<Appointment> forDay(DateTime day) {
    return _appointments.where((a) => a.dateTime.year == day.year && a.dateTime.month == day.month && a.dateTime.day == day.day).toList();
  }

  void markAttended(String id) {
    final idx = _appointments.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    _appointments[idx].status = AppointmentStatus.attended;
    _cancelNotification(id);
    notifyListeners();
  }

  void markMissed(String id) {
    final idx = _appointments.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    _appointments[idx].status = AppointmentStatus.missed;
    _cancelNotification(id);
    notifyListeners();
  }

  void reschedule(String id, DateTime newDateTime) {
    final idx = _appointments.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    final a = _appointments[idx];
    _appointments[idx] = Appointment(
      id: a.id,
      patientId: a.patientId,
      dateTime: newDateTime,
      reason: a.reason,
      doctorId: a.doctorId,
      doctorName: a.doctorName,
      status: AppointmentStatus.scheduled,
    );
    // Cancel previous notification (if any) and schedule new
    _cancelNotification(id);
    _scheduleIfNeeded(_appointments[idx]);
    notifyListeners();
  }

  /// Appointments that are scheduled within [withinMinutes] from now (future only) and still scheduled.
  List<Appointment> upcomingWithin({int withinMinutes = 60}) {
    final now = DateTime.now();
    final until = now.add(Duration(minutes: withinMinutes));
    return _appointments
        .where((a) => a.status == AppointmentStatus.scheduled && a.dateTime.isAfter(now) && a.dateTime.isBefore(until))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  /// Appointments that are due now (past up to grace minutes) and still scheduled.
  List<Appointment> dueNow({int graceMinutes = 5}) {
    final now = DateTime.now();
    final since = now.subtract(Duration(minutes: graceMinutes));
    return _appointments
        .where((a) => a.status == AppointmentStatus.scheduled && !a.dateTime.isAfter(now) && a.dateTime.isAfter(since))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<Appointment> missed() => _appointments.where((a) => a.status == AppointmentStatus.missed).toList();

  // Notification helpers
  int _notifIdFor(String id) => id.hashCode & 0x7fffffff;

  void _cancelNotification(String id) {
    NotificationService.instance.cancel(_notifIdFor(id));
  }

  void _scheduleIfNeeded(Appointment a) {
    if (a.status != AppointmentStatus.scheduled) return;
    if (a.dateTime.isBefore(DateTime.now())) return;
    final title = 'Appointment Reminder';
    final timeStr = _fmtTime(a.dateTime);
    final withDoc = (a.doctorName != null && a.doctorName!.trim().isNotEmpty) ? ' with Dr. ${a.doctorName}' : '';
    final reason = (a.reason != null && a.reason!.trim().isNotEmpty) ? ' — ${a.reason}' : '';
    final body = 'Today at $timeStr$withDoc$reason';
    NotificationService.instance.scheduleAppointmentNotification(
      id: _notifIdFor(a.id),
      title: title,
      body: body,
      scheduledTime: a.dateTime,
      payload: a.id,
    );
  }

  String _fmtTime(DateTime dt) {
    final hour = dt.hour;
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }
}
