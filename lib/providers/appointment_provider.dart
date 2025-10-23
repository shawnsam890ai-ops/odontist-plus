import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/appointment.dart';
import '../services/notification_service.dart';

class AppointmentProvider with ChangeNotifier {
  final List<Appointment> _appointments = [];
  bool _loaded = false;

  List<Appointment> get appointments => List.unmodifiable(_appointments);
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final snap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('appointments').get();
        _appointments
          ..clear()
          ..addAll(snap.docs.map((d) => Appointment.fromJson(d.data())));
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(Appointment a) async {
    _appointments.add(a);
    _scheduleIfNeeded(a);
    // Write-through to Firestore
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('appointments').doc(a.id).set(a.toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  /// Remove an appointment by id.
  Future<void> remove(String id) async {
    _appointments.removeWhere((a) => a.id == id);
    _cancelNotification(id);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('appointments').doc(id).delete();
      }
    } catch (_) {}
    notifyListeners();
  }

  List<Appointment> forDay(DateTime day) {
    return _appointments.where((a) => a.dateTime.year == day.year && a.dateTime.month == day.month && a.dateTime.day == day.day).toList();
  }

  Future<void> markAttended(String id) async {
    final idx = _appointments.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    _appointments[idx].status = AppointmentStatus.attended;
    _cancelNotification(id);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('appointments').doc(id).set(_appointments[idx].toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> markMissed(String id) async {
    final idx = _appointments.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    _appointments[idx].status = AppointmentStatus.missed;
    _cancelNotification(id);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('appointments').doc(id).set(_appointments[idx].toJson());
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> reschedule(String id, DateTime newDateTime) async {
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
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('appointments').doc(id).set(_appointments[idx].toJson());
      }
    } catch (_) {}
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
