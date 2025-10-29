import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/staff_attendance.dart';
import '../models/staff_member.dart';
import 'revenue_provider.dart';
import '../services/google_calendar_service.dart';

class StaffAttendanceProvider with ChangeNotifier {
  final List<StaffAttendanceEntry> _entries = [];
  final List<StaffMember> _staff = [];
  final Map<String, Map<String, MonthlySalaryRecord>> _salaryRecords = {}; // staffName -> { 'YYYY-MM' : record }
  RevenueProvider? _revenue;
  bool _loaded = false;
  bool _listeningStaff = false;
  bool _listeningAttendance = false;
  bool _listeningSalary = false;

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

  // Firestore base refs -------------------------------------------------------
  DocumentReference<Map<String, dynamic>>? _userDoc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final base = _userDoc();
      if (base == null) {
        _loaded = true; // Nothing to load when signed-out
        return;
      }
      // Pull once
      final staffSnap = await base.collection('staff').get();
      _staff
        ..clear()
        ..addAll(staffSnap.docs.map((d) => StaffMember.fromJson(d.data())));

      final attSnap = await base.collection('staff_attendance').get();
      _entries
        ..clear()
        ..addAll(attSnap.docs.map((d) => StaffAttendanceEntry.fromJson(d.data())));

      final salSnap = await base.collection('staff_salary_records').get();
      _salaryRecords.clear();
      for (final d in salSnap.docs) {
        final data = d.data();
        final staffName = (data['staffName'] as String?) ?? '';
        if (staffName.isEmpty) continue;
        final year = (data['year'] as num?)?.toInt() ?? 0;
        final month = (data['month'] as num?)?.toInt() ?? 0;
        if (year == 0 || month == 0) continue;
        final rec = MonthlySalaryRecord(
          year: year,
          month: month,
          totalSalary: (data['totalSalary'] as num?)?.toDouble() ?? 0,
          paid: (data['paid'] as bool?) ?? false,
          paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
          deduction: (data['deduction'] as num?)?.toDouble() ?? 0,
          paymentDate: data['paymentDate'] == null ? null : DateTime.tryParse(data['paymentDate'] as String),
          paymentMode: data['paymentMode'] as String?,
          calendarEventId: data['calendarEventId'] as String?,
        );
        _salaryRecords.putIfAbsent(staffName, () => {});
        final key = '$year-${month.toString().padLeft(2, '0')}';
        _salaryRecords[staffName]![key] = rec;
      }

      // Start realtime listeners
      _startListeners(base);
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  void _startListeners(DocumentReference<Map<String, dynamic>> base) {
    if (!_listeningStaff) {
      _listeningStaff = true;
      base.collection('staff').snapshots().listen((snap) {
        _staff
          ..clear()
          ..addAll(snap.docs.map((d) => StaffMember.fromJson(d.data())));
        notifyListeners();
      });
    }
    if (!_listeningAttendance) {
      _listeningAttendance = true;
      base.collection('staff_attendance').snapshots().listen((snap) {
        _entries
          ..clear()
          ..addAll(snap.docs.map((d) => StaffAttendanceEntry.fromJson(d.data())));
        notifyListeners();
      });
    }
    if (!_listeningSalary) {
      _listeningSalary = true;
      base.collection('staff_salary_records').snapshots().listen((snap) {
        _salaryRecords.clear();
        for (final d in snap.docs) {
          final data = d.data();
          final staffName = (data['staffName'] as String?) ?? '';
          if (staffName.isEmpty) continue;
          final year = (data['year'] as num?)?.toInt() ?? 0;
          final month = (data['month'] as num?)?.toInt() ?? 0;
          if (year == 0 || month == 0) continue;
          final rec = MonthlySalaryRecord(
            year: year,
            month: month,
            totalSalary: (data['totalSalary'] as num?)?.toDouble() ?? 0,
            paid: (data['paid'] as bool?) ?? false,
            paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
            deduction: (data['deduction'] as num?)?.toDouble() ?? 0,
            paymentDate: data['paymentDate'] == null ? null : DateTime.tryParse(data['paymentDate'] as String),
            paymentMode: data['paymentMode'] as String?,
            calendarEventId: data['calendarEventId'] as String?,
          );
          _salaryRecords.putIfAbsent(staffName, () => {});
          final key = '$year-${month.toString().padLeft(2, '0')}';
          _salaryRecords[staffName]![key] = rec;
        }
        notifyListeners();
      });
    }
  }

  void _ensureNameExists(String name) {
    if (_staff.any((s) => s.name == name)) return;
    _staff.add(StaffMember(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name));
    // Mirror to Firestore (minimal doc with id+name)
    try {
      final base = _userDoc();
      if (base != null) {
        final s = _staff.firstWhere((e) => e.name == name);
        base.collection('staff').doc(s.id).set(s.toJson());
      }
    } catch (_) {}
  }

  void addStaffDetailed(StaffMember member) {
    if (member.name.trim().isEmpty) return;
    // avoid duplicates by name
    if (_staff.any((s) => s.name == member.name)) return;
    _staff.add(member);
    // Firestore mirror
    try {
      final base = _userDoc();
      if (base != null) {
        base.collection('staff').doc(member.id).set(member.toJson());
      }
    } catch (_) {}
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
    // Firestore mirror
    try {
      final base = _userDoc();
      if (base != null) {
        base.collection('staff').doc(updated.id).set(updated.toJson());
      }
    } catch (_) {}
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
      // Update attendance/salary docs staffName field in Firestore (best-effort, async fire-and-forget)
      Future.microtask(() async {
        try {
          final base = _userDoc();
          if (base != null) {
            final q = await base.collection('staff_attendance').where('staffName', isEqualTo: oldName).get();
            final batch = FirebaseFirestore.instance.batch();
            for (final d in q.docs) {
              batch.set(d.reference, {...d.data(), 'staffName': newName});
            }
            await batch.commit();
            // Update salary records staffName
            final q2 = await base.collection('staff_salary_records').where('staffName', isEqualTo: oldName).get();
            final batch2 = FirebaseFirestore.instance.batch();
            for (final d in q2.docs) {
              batch2.set(d.reference, {...d.data(), 'staffName': newName});
            }
            await batch2.commit();
          }
        } catch (_) {}
      });
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
    // Firestore mirror (delete staff and related docs)
    Future.microtask(() async {
      try {
        final base = _userDoc();
        if (base != null) {
          // Delete staff doc (lookup by name if id unknown)
          final qStaff = await base.collection('staff').where('name', isEqualTo: name).limit(1).get();
          if (qStaff.docs.isNotEmpty) {
            await qStaff.docs.first.reference.delete();
          }
          // Delete attendance docs
          final qAtt = await base.collection('staff_attendance').where('staffName', isEqualTo: name).get();
          final batch = FirebaseFirestore.instance.batch();
          for (final d in qAtt.docs) {
            batch.delete(d.reference);
          }
          await batch.commit();
          // Delete salary records
          final qSal = await base.collection('staff_salary_records').where('staffName', isEqualTo: name).get();
          final batch2 = FirebaseFirestore.instance.batch();
          for (final d in qSal.docs) {
            batch2.delete(d.reference);
          }
          await batch2.commit();
        }
      } catch (_) {}
    });
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
    _saveSalaryRecord(staffName, rec);
    notifyListeners();
  }

  void setMonthlyDeduction(String staffName, int year, int month, double deduction) {
    final rec = ensureSalaryRecord(staffName, year, month);
    rec.deduction = deduction;
    _saveSalaryRecord(staffName, rec);
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
    _saveSalaryRecord(staffName, rec);
    notifyListeners();
  }

  void unmarkSalaryPaid(String staffName, int year, int month) {
    final rec = getSalaryRecord(staffName, year, month);
    if (rec == null) return;
    rec.paid = false;
    rec.paymentDate = null;
    final desc = 'Staff Salary: $staffName $year-${month.toString().padLeft(2,'0')}';
    _revenue?.removeByDescription(desc);
    _saveSalaryRecord(staffName, rec);
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
    _saveSalaryRecord(staffName, rec);
    notifyListeners();
    // Best-effort background calendar update: if we're already signed in and
    // have an event id, update the event time/details to match the new date.
    // Do NOT auto-create events here to avoid surprises; creation happens from UI.
    Future.microtask(() async {
      // Try silent sign-in only; skip if not available
      await GoogleCalendarService.instance.signInSilently();
      if (!GoogleCalendarService.instance.isSignedIn) return;
      final eventId = rec.calendarEventId;
      if (eventId == null || eventId.isEmpty) return;
      final start = DateTime(date.year, date.month, date.day, 10, 0);
      await GoogleCalendarService.instance.updateSalaryEvent(
        eventId: eventId,
        start: start,
        salary: rec.totalSalary,
        deduction: rec.deduction,
      );
    });
  }

  void setPaymentMode(String staffName, int year, int month, String mode) {
    final rec = ensureSalaryRecord(staffName, year, month);
    rec.paymentMode = mode;
    _saveSalaryRecord(staffName, rec);
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
      _saveAttendance(existing);
    } else if (existing.isFullPresent) {
      // full present -> morning present only
      existing.morningPresent = true;
      existing.eveningPresent = null;
      _saveAttendance(existing);
    } else if (existing.morningPresent == true && existing.eveningPresent == null) {
      // morning present only -> evening present only (representing morning absent/afternoon present)
      existing.morningPresent = null;
      existing.eveningPresent = true;
      _saveAttendance(existing);
    } else if (existing.eveningPresent == true && existing.morningPresent == null) {
      // evening present only -> full absent
      existing.morningPresent = false;
      existing.eveningPresent = false;
      _saveAttendance(existing);
    } else if (existing.isFullAbsent) {
      // full absent -> remove (none)
      _entries.remove(existing);
      _deleteAttendance(existing);
    } else {
      // fallback: remove
      _entries.remove(existing);
      _deleteAttendance(existing);
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

  /// Explicitly set morning/evening attendance for a given day.
  /// Use true for present, false for absent, null for holiday/none.
  void setSplit(String staffName, DateTime day, {bool? morning, bool? evening}) {
    _ensureNameExists(staffName);
    final existing = _entries.firstWhere(
        (e) => e.staffName == staffName && e.date.year == day.year && e.date.month == day.month && e.date.day == day.day,
        orElse: () => StaffAttendanceEntry(staffName: staffName, date: day));
    if (!_entries.contains(existing)) {
      _entries.add(existing);
    }
    existing.morningPresent = morning;
    existing.eveningPresent = evening;
    _saveAttendance(existing);
    notifyListeners();
  }

  Future<void> _saveAttendance(StaffAttendanceEntry e) async {
    try {
      final base = _userDoc();
      if (base == null) return;
      await base.collection('staff_attendance').doc(e.id).set(e.toJson());
    } catch (_) {}
  }

  Future<void> _deleteAttendance(StaffAttendanceEntry e) async {
    try {
      final base = _userDoc();
      if (base == null) return;
      await base.collection('staff_attendance').doc(e.id).delete();
    } catch (_) {}
  }

  Future<void> _saveSalaryRecord(String staffName, MonthlySalaryRecord rec) async {
    try {
      final base = _userDoc();
      if (base == null) return;
      final key = '${rec.year}-${rec.month.toString().padLeft(2, '0')}';
      await base.collection('staff_salary_records').doc('${staffName}_$key').set({
            'staffName': staffName,
            'year': rec.year,
            'month': rec.month,
            'totalSalary': rec.totalSalary,
            'paid': rec.paid,
            'paidAmount': rec.paidAmount,
            'deduction': rec.deduction,
            'paymentDate': rec.paymentDate?.toIso8601String(),
            'paymentMode': rec.paymentMode,
            'calendarEventId': rec.calendarEventId,
          });
    } catch (_) {}
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
  String? calendarEventId; // Google Calendar event id
  MonthlySalaryRecord({required this.year, required this.month, this.totalSalary = 0, this.paid = false, this.paidAmount = 0, this.deduction = 0, this.paymentDate, this.paymentMode, this.calendarEventId});
}
