import 'package:flutter/foundation.dart';
import '../models/staff_attendance.dart';
import '../models/staff_member.dart';

class StaffAttendanceProvider with ChangeNotifier {
  final List<StaffAttendanceEntry> _entries = [];
  final List<StaffMember> _staff = [];
  final Map<String, Map<String, MonthlySalaryRecord>> _salaryRecords = {}; // staffName -> { 'YYYY-MM' : record }

  List<StaffAttendanceEntry> forDay(DateTime day) => _entries
      .where((e) => e.date.year == day.year && e.date.month == day.month && e.date.day == day.day)
      .toList();

  void mark(String staffName, DateTime day, bool present) {
    _ensureNameExists(staffName);
    final existing = _entries.firstWhere(
        (e) => e.staffName == staffName && e.date.year == day.year && e.date.month == day.month && e.date.day == day.day,
        orElse: () => StaffAttendanceEntry(staffName: staffName, date: day));
    if (!_entries.contains(existing)) {
      _entries.add(existing);
    }
    existing.present = present;
    notifyListeners();
  }

  List<String> get staffNames => _staff.map((s) => s.name).toList()..sort();

  List<StaffMember> get staffMembers => List.unmodifiable(_staff);

  StaffMember? staffByName(String name) =>
      _staff.firstWhere((s) => s.name == name, orElse: () => StaffMember(id: '__none__', name: '')); 

  void _ensureNameExists(String name) {
    if (_staff.any((s) => s.name == name)) return;
    _staff.add(StaffMember(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name));
  }

  void addStaffDetailed(StaffMember member) {
    if (member.name.trim().isEmpty) return;
    // avoid duplicates by name
    if (_staff.any((s) => s.name == member.name)) return;
    _staff.add(member);
    notifyListeners();
  }

  // Backwards compatible simple add by name
  void addStaff(String name) => addStaffDetailed(StaffMember(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name.trim()));

  void removeStaff(String name) {
    final before = _staff.length;
    _staff.removeWhere((s) => s.name == name);
    if (before == _staff.length) return; // nothing removed
    _entries.removeWhere((e) => e.staffName == name);
    _salaryRecords.remove(name);
    notifyListeners();
  }

  MonthlySalaryRecord ensureSalaryRecord(String staffName, int year, int month) {
    final key = '$year-${month.toString().padLeft(2,'0')}';
    _salaryRecords.putIfAbsent(staffName, () => {});
    _salaryRecords[staffName]!.putIfAbsent(key, () => MonthlySalaryRecord(year: year, month: month));
    return _salaryRecords[staffName]![key]!;
  }

  MonthlySalaryRecord? getSalaryRecord(String staffName, int year, int month) {
    final key = '$year-${month.toString().padLeft(2,'0')}';
    return _salaryRecords[staffName]?[key];
  }

  /// Get entries for a full month for a staff (map day->present?)
  List<StaffAttendanceEntry> forMonth(String staffName, int year, int month) => _entries
      .where((e) => e.staffName == staffName && e.date.year == year && e.date.month == month)
      .toList();

  int presentCount(String staffName, int year, int month) => forMonth(staffName, year, month).where((e) => e.present).length;
  int absentCount(String staffName, int year, int month) {
    final totalMarked = forMonth(staffName, year, month).length;
    return totalMarked - presentCount(staffName, year, month);
  }

  double monthlySalaryComputed(String staffName, int year, int month) {
    final record = getSalaryRecord(staffName, year, month);
    if (record == null) return 0;
    return record.totalSalary; // external logic sets
  }

  void setMonthlySalary(String staffName, int year, int month, double amount) {
    final rec = ensureSalaryRecord(staffName, year, month);
    rec.totalSalary = amount;
    notifyListeners();
  }

  void markSalaryPaid(String staffName, int year, int month, {double? amount}) {
    final rec = ensureSalaryRecord(staffName, year, month);
    if (amount != null) rec.paidAmount = amount;
    rec.paid = true;
    notifyListeners();
  }

  /// Cycle attendance state: none -> present -> absent -> none
  void cycle(String staffName, DateTime day) {
    final existing = _entries.firstWhere(
        (e) => e.staffName == staffName && e.date.year == day.year && e.date.month == day.month && e.date.day == day.day,
        orElse: () => StaffAttendanceEntry(staffName: staffName, date: day));
    if (!_entries.contains(existing)) {
      // Was none; set to present first
      existing.present = true;
      _entries.add(existing);
    } else {
      if (existing.present) {
        // present -> absent (represented by present=false but keep entry)
        existing.present = false;
      } else {
        // absent -> remove (back to none)
        _entries.remove(existing);
      }
    }
    notifyListeners();
  }

  bool? stateFor(String staffName, DateTime day) {
    final match = _entries.firstWhere(
        (e) => e.staffName == staffName && e.date.year == day.year && e.date.month == day.month && e.date.day == day.day,
        orElse: () => StaffAttendanceEntry(staffName: '__none__', date: day));
    if (match.staffName == '__none__') return null; // none
    return match.present; // true=present, false=absent
  }
}

class MonthlySalaryRecord {
  final int year;
  final int month; // 1-12
  double totalSalary; // decided externally (fixed or computed)
  bool paid;
  double paidAmount;
  MonthlySalaryRecord({required this.year, required this.month, this.totalSalary = 0, this.paid = false, this.paidAmount = 0});
}
