import 'package:uuid/uuid.dart';

class StaffAttendanceEntry {
  final String id;
  final String staffName;
  final DateTime date;
  bool present;

  StaffAttendanceEntry({String? id, required this.staffName, required this.date, this.present = false})
      : id = id ?? const Uuid().v4();
}
