import 'package:uuid/uuid.dart';

class Appointment {
  final String id;
  final String patientId;
  final DateTime dateTime;
  final String? reason;
  final String? doctorId;
  final String? doctorName;

  Appointment({
    String? id,
    required this.patientId,
    required this.dateTime,
    this.reason,
    this.doctorId,
    this.doctorName,
  }) : id = id ?? const Uuid().v4();
}
