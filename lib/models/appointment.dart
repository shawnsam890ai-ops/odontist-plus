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

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'dateTime': dateTime.toIso8601String(),
        'reason': reason,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'status': status.name,
      };

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'] as String?,
        patientId: j['patientId'] as String,
        dateTime: DateTime.tryParse(j['dateTime'] as String? ?? '') ?? DateTime.now(),
        reason: j['reason'] as String?,
        doctorId: j['doctorId'] as String?,
        doctorName: j['doctorName'] as String?,
        status: _parseStatus(j['status'] as String?),
      );
}

AppointmentStatus _parseStatus(String? s) {
  switch (s) {
    case 'attended':
      return AppointmentStatus.attended;
    case 'missed':
      return AppointmentStatus.missed;
    case 'scheduled':
    default:
      return AppointmentStatus.scheduled;
  }
}
