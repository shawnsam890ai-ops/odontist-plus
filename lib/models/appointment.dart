import 'package:uuid/uuid.dart';

enum AppointmentStatus { scheduled, attended, missed }

class Appointment {
  final String id;
  final String patientId;
  final DateTime dateTime;
  final String? reason;
  final String? doctorId;
  final String? doctorName;
  AppointmentStatus status;

  Appointment({
    String? id,
    required this.patientId,
    required this.dateTime,
    this.reason,
    this.doctorId,
    this.doctorName,
    this.status = AppointmentStatus.scheduled,
  }) : id = id ?? const Uuid().v4();
}
