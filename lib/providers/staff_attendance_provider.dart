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
          _entries[i] = StaffAttendanceEntry(id: e.id, staffName: newName, date: e.date, present: e.present);
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
    rec.paymentDate = DateTime.now();
    // Post negative revenue entry for salary payout
    final desc = 'Staff Salary: $staffName ${year}-${month.toString().padLeft(2,'0')}';
    final amt = amount ?? rec.totalSalary;
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
    final desc = 'Staff Salary: $staffName ${year}-${month.toString().padLeft(2,'0')}';
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
  DateTime? paymentDate;
  MonthlySalaryRecord({required this.year, required this.month, this.totalSalary = 0, this.paid = false, this.paidAmount = 0, this.paymentDate});
}
