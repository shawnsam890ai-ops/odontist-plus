import 'package:flutter/foundation.dart';
import '../models/staff_attendance.dart';
import '../models/staff_member.dart';
import 'revenue_provider.dart';

class StaffAttendanceProvider with ChangeNotifier {
  final List<StaffAttendanceEntry> _entries = [];
  final List<StaffMember> _staff = [];
  final Map<String, Map<String, MonthlySalaryRecord>> _salaryRecords = {}; // staffName -> { 'YYYY-MM' : record }
  RevenueProvider? _revenue;

  List<StaffAttendanceEntry> forDay(DateTime day) => _entries
      .where((e) => e.date.year == day.year && e.date.month == day.month && e.date.day == day.day)
      .toList();

  void mark(String staffName, DateTime day, bool present) {
    // Backwards-compatible simple full-day mark (sets both halves)
    _ensureNameExists(staffName);
    final existing = _entries.firstWhere(
        (e) => e.staffName == staffName && e.date.year == day.year && e.date.month == day.month && e.date.day == day.day,
        orElse: () => StaffAttendanceEntry(staffName: staffName, date: day));
    if (!_entries.contains(existing)) {
      _entries.add(existing);
    }
    existing.setFull(present);
    notifyListeners();
  }

  List<String> get staffNames => _staff.map((s) => s.name).toList()..sort();

  List<StaffMember> get staffMembers => List.unmodifiable(_staff);

  StaffMember? staffByName(String name) =>
      _staff.firstWhere((s) => s.name == name, orElse: () => StaffMember(id: '__none__', name: '')); 

  void registerRevenueProvider(RevenueProvider revenue) {
    _revenue = revenue;
  }

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

  /// Update existing staff basic information by id. Name must remain unique.
  void updateStaff(StaffMember updated) {
    final idx = _staff.indexWhere((s) => s.id == updated.id);
    if (idx == -1) return;
    // If name changed ensure no collision
    final newName = updated.name.trim();
    if (newName.isEmpty) return;
    if (_staff.any((s) => s.name == newName && s.id != updated.id)) return;
    final oldName = _staff[idx].name;
    _staff[idx] = updated;
    // If name changed migrate attendance + salary records to new name key
    if (oldName != newName) {
      // Rebuild attendance entries with new name (since staffName is final)
      for (int i = 0; i < _entries.length; i++) {
        final e = _entries[i];
        if (e.staffName == oldName) {
          _entries[i] = StaffAttendanceEntry(id: e.id, staffName: newName, date: e.date, morningPresent: e.morningPresent, eveningPresent: e.eveningPresent);
        }
      }
      if (_salaryRecords.containsKey(oldName)) {
        _salaryRecords[newName] = _salaryRecords.remove(oldName)!;
      }
    }
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
    // Remove any revenue entries for this staff member's salaries
    _revenue?.removeByDescriptionPrefix('Staff Salary: $name ');
    notifyListeners();
  }

  MonthlySalaryRecord ensureSalaryRecord(String staffName, int year, int month) {
  final key = '$year-${month.toString().padLeft(2,'0')}';
    _salaryRecords.putIfAbsent(staffName, () => {});
    _salaryRecords[staffName]!.putIfAbsent(key, () {
      final rec = MonthlySalaryRecord(year: year, month: month);
      // Default payment date based on staff preferred day, if available
      final staff = staffByName(staffName);
      final day = staff?.preferredPaymentDay;
      if (day != null && day > 0) {
        final lastDay = DateTime(year, month + 1, 0).day;
        final finalDay = day > lastDay ? lastDay : day;
        rec.paymentDate = DateTime(year, month, finalDay);
      }
      return rec;
    });
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

  /// Counts a half-day as 0.5 for present/absent summary (presentCount returns total present halves)
  int presentCount(String staffName, int year, int month) {
    final list = forMonth(staffName, year, month);
    int count = 0;
    for (final e in list) {
      if (e.morningPresent == true) count++;
      if (e.eveningPresent == true) count++;
    }
    return count;
  }

  int absentCount(String staffName, int year, int month) {
    final list = forMonth(staffName, year, month);
    int absent = 0;
    for (final e in list) {
      if (e.morningPresent != null) {
        if (e.morningPresent == false) absent++;
      }
      if (e.eveningPresent != null) {
        if (e.eveningPresent == false) absent++;
      }
    }
    return absent;
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

  void setMonthlyDeduction(String staffName, int year, int month, double deduction) {
    final rec = ensureSalaryRecord(staffName, year, month);
    rec.deduction = deduction;
    notifyListeners();
  }

  void markSalaryPaid(String staffName, int year, int month, {double? amount, String? mode, DateTime? date}) {
    final rec = ensureSalaryRecord(staffName, year, month);
    if (amount != null) rec.paidAmount = amount;
    rec.paid = true;
    rec.paymentDate = date ?? DateTime.now();
    rec.paymentMode = mode ?? rec.paymentMode;
    // Post negative revenue entry for salary payout
    // Remove unnecessary braces around simple identifier (year)
    final desc = 'Staff Salary: $staffName $year-${month.toString().padLeft(2,'0')}';
    // Use net amount (salary - deduction). If explicit amount provided, prefer it.
    final computedNet = (rec.totalSalary - (rec.deduction));
    final amt = amount ?? computedNet;
    if (_revenue != null && amt != 0) {
      _revenue!.removeByDescription(desc);
      _revenue!.addRevenue(patientId: 'staff', description: desc, amount: -amt);
    }
    notifyListeners();
  }

  void unmarkSalaryPaid(String staffName, int year, int month) {
    final rec = getSalaryRecord(staffName, year, month);
    if (rec == null) return;
    rec.paid = false;
    rec.paymentDate = null;
    final desc = 'Staff Salary: $staffName $year-${month.toString().padLeft(2,'0')}';
    _revenue?.removeByDescription(desc);
    notifyListeners();
  }

  /// Returns a list of salary records (most recent first) for a staff member.
  List<MonthlySalaryRecord> salaryHistory(String staffName) {
    final map = _salaryRecords[staffName];
    if (map == null) return [];
    final list = map.values.toList();
    list.sort((a, b) {
      if (a.year != b.year) return b.year.compareTo(a.year);
      return b.month.compareTo(a.month);
    });
    return list;
  }

  /// Filter salary history by year (descending months)
  List<MonthlySalaryRecord> salaryHistoryForYear(String staffName, int year) {
    return salaryHistory(staffName).where((r) => r.year == year).toList();
  }

  /// Manually set payment date (e.g., when user adjusts)
  void setPaymentDate(String staffName, int year, int month, DateTime date) {
    final rec = ensureSalaryRecord(staffName, year, month);
    rec.paymentDate = date;
    notifyListeners();
  }

  void setPaymentMode(String staffName, int year, int month, String mode) {
    final rec = ensureSalaryRecord(staffName, year, month);
    rec.paymentMode = mode;
    notifyListeners();
  }

  /// Cycle attendance state: none -> present -> absent -> none
  /// Cycle attendance states with half-day support.
  /// Order: none -> full present -> morning present only -> evening present only -> full absent -> none
  void cycle(String staffName, DateTime day) {
    final existing = _entries.firstWhere(
        (e) => e.staffName == staffName && e.date.year == day.year && e.date.month == day.month && e.date.day == day.day,
        orElse: () => StaffAttendanceEntry(staffName: staffName, date: day));
    if (!_entries.contains(existing)) {
      // none -> full present
      existing.setFull(true);
      _entries.add(existing);
    } else if (existing.isFullPresent) {
      // full present -> morning present only
      existing.morningPresent = true;
      existing.eveningPresent = null;
    } else if (existing.morningPresent == true && existing.eveningPresent == null) {
      // morning present only -> evening present only (representing morning absent/afternoon present)
      existing.morningPresent = null;
      existing.eveningPresent = true;
    } else if (existing.eveningPresent == true && existing.morningPresent == null) {
      // evening present only -> full absent
      existing.morningPresent = false;
      existing.eveningPresent = false;
    } else if (existing.isFullAbsent) {
      // full absent -> remove (none)
      _entries.remove(existing);
    } else {
      // fallback: remove
      _entries.remove(existing);
    }
    notifyListeners();
  }

  /// Returns a tuple-like result for the day: (morningPresent?, eveningPresent?)
  /// Each value is bool? (true present, false absent, null none)
  List<bool?> stateForSplit(String staffName, DateTime day) {
    final match = _entries.firstWhere(
        (e) => e.staffName == staffName && e.date.year == day.year && e.date.month == day.month && e.date.day == day.day,
        orElse: () => StaffAttendanceEntry(staffName: '__none__', date: day));
    if (match.staffName == '__none__') return [null, null];
    return [match.morningPresent, match.eveningPresent];
  }
}

class MonthlySalaryRecord {
  final int year;
  final int month; // 1-12
  double totalSalary; // decided externally (fixed or computed)
  bool paid;
  double paidAmount;
  double deduction; // any deduction to apply for this month
  DateTime? paymentDate;
  String? paymentMode; // Cash / UPI / Bank / Other
  MonthlySalaryRecord({required this.year, required this.month, this.totalSalary = 0, this.paid = false, this.paidAmount = 0, this.deduction = 0, this.paymentDate, this.paymentMode});
}
