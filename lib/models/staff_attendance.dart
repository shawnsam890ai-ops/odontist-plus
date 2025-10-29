import 'package:uuid/uuid.dart';

/// Attendance entry now supports half-day tracking via morning/evening flags.
class StaffAttendanceEntry {
  final String id;
  final String staffName;
  final DateTime date;
  // null => no mark (none). true => present, false => absent for that half.
  bool? morningPresent;
  bool? eveningPresent;

  StaffAttendanceEntry({String? id, required this.staffName, required this.date, this.morningPresent, this.eveningPresent})
      : id = id ?? const Uuid().v4();

  /// Convenience: set full-day present/absent
  void setFull(bool present) {
    morningPresent = present;
    eveningPresent = present;
  }

  /// Returns true if both halves are present
  bool get isFullPresent => morningPresent == true && eveningPresent == true;

  /// Returns true if both halves are absent (explicitly marked absent)
  bool get isFullAbsent => morningPresent == false && eveningPresent == false;

  /// Returns true if entry is unmarked
  bool get isNone => morningPresent == null && eveningPresent == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'staffName': staffName,
        'date': date.toIso8601String(),
        'morningPresent': morningPresent,
        'eveningPresent': eveningPresent,
      };

  factory StaffAttendanceEntry.fromJson(Map<String, dynamic> j) => StaffAttendanceEntry(
        id: (j['id'] as String?),
        staffName: (j['staffName'] as String?) ?? '',
        date: DateTime.tryParse((j['date'] as String?) ?? '') ?? DateTime.now(),
        morningPresent: j['morningPresent'] as bool?,
        eveningPresent: j['eveningPresent'] as bool?,
      );
}
