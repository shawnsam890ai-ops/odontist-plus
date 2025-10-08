import 'package:flutter/foundation.dart';
import '../models/staff_attendance.dart';

class StaffAttendanceProvider with ChangeNotifier {
  final List<StaffAttendanceEntry> _entries = [];

  List<StaffAttendanceEntry> forDay(DateTime day) => _entries
      .where((e) => e.date.year == day.year && e.date.month == day.month && e.date.day == day.day)
      .toList();

  void mark(String staffName, DateTime day, bool present) {
    final existing = _entries.firstWhere(
        (e) => e.staffName == staffName && e.date.year == day.year && e.date.month == day.month && e.date.day == day.day,
        orElse: () => StaffAttendanceEntry(staffName: staffName, date: day));
    if (!_entries.contains(existing)) {
      _entries.add(existing);
    }
    existing.present = present;
    notifyListeners();
  }
}
