import 'package:flutter/foundation.dart';
import '../models/doctor.dart';
import '../models/payment_rule.dart';
import '../models/payment_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'doctor_attendance_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DoctorProvider with ChangeNotifier {
  final Map<String, Doctor> _doctors = {};
  final List<PaymentEntry> _ledger = [];
  double _totalDoctor = 0;
  double _totalClinic = 0;
  bool _requireAttendance = false;

  // Firebase
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  bool _remoteListening = false;
  DoctorProvider({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  List<Doctor> get doctors => _doctors.values.toList(growable: false);
  List<PaymentEntry> get ledger => List.unmodifiable(_ledger);
  double get totalDoctor => _totalDoctor;
  double get totalClinic => _totalClinic;
  bool get requireAttendance => _requireAttendance;

  Doctor? byId(String id) => _doctors[id];
  Doctor? byName(String name) {
    String norm(String s) => s
        .toLowerCase()
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll(RegExp(r'^dr\s+'), '')
        .trim();
    final target = norm(name);
    for (final d in _doctors.values) {
      if (norm(d.name) == target) return d;
    }
    return null;
  }

  void addDoctor(Doctor d) {
    _doctors[d.id] = d;
    notifyListeners();
    _persist();
    _writeDoctorRemote(d);
  }

  void updateDoctor(String id, {String? name, DoctorRole? role, bool? active, String? photoPath, DoctorSex? sex, int? age, DateTime? dob, String? phone, String? address, String? registrationNumber, String? registeredState, EmploymentType? employmentType}) {
    final d = _doctors[id];
    if (d == null) return;
    if (name != null) d.name = name;
    if (role != null) d.role = role;
    if (active != null) d.active = active;
    if (photoPath != null) d.photoPath = photoPath;
    if (sex != null) d.sex = sex;
    if (age != null) d.age = age;
    if (dob != null) d.dob = dob;
    if (phone != null) d.phone = phone;
    if (address != null) d.address = address;
    if (registrationNumber != null) d.registrationNumber = registrationNumber;
    if (registeredState != null) d.registeredState = registeredState;
    if (employmentType != null) d.employmentType = employmentType;
    notifyListeners();
    _persist();
    _writeDoctorRemote(d);
  }

  void removeDoctor(String id) {
    _doctors.remove(id);
    notifyListeners();
    _persist();
    _deleteDoctorRemote(id);
  }

  void setRule(String doctorId, String procedureKey, PaymentRule rule) {
    final d = _doctors[doctorId];
    if (d == null) return;
    d.rules[procedureKey] = rule;
    notifyListeners();
    _persist();
    _writeDoctorRemote(d);
  }

  void removeRule(String doctorId, String procedureKey) {
    final d = _doctors[doctorId];
    if (d == null) return;
    d.rules.remove(procedureKey);
    notifyListeners();
    _persist();
    _writeDoctorRemote(d);
  }

  // Compute split based on a doctor's rule for procedure; fallback: all clinic.
  (double doctor, double clinic) allocate(String doctorId, String procedureKey, double chargeAmount) {
    final d = _doctors[doctorId];
    if (d == null) return (0, chargeAmount);
  // Chief Dental Surgeon gets routed to clinic entirely
  if (d.role == DoctorRole.chiefDentalSurgeon) return (0, chargeAmount);
    final rule = d.rules[procedureKey];
    if (rule == null) return (0, chargeAmount);
    return rule.split(chargeAmount);
  }

  // Recalculate totals from scratch based on current ledger
  void _recomputeTotals() {
    double d = 0, c = 0;
    for (final e in _ledger) {
      if (e.type == EntryType.payment) {
        d += e.doctorShare;
        c += e.clinicShare;
      }
    }
    _totalDoctor = d;
    _totalClinic = c;
  }

  // Attendance requirement toggle
  void setRequireAttendance(bool v) {
    _requireAttendance = v;
    notifyListeners();
    _persist();
    _writeSettingsRemote();
  }

  // Record a payment entry into ledger. Optionally check attendance
  String? recordPayment({
    required String doctorId,
    required String procedureKey,
    required double amountReceived,
    DateTime? date,
    String? patient,
    String? note,
    String? dedupeTag,
    DoctorAttendanceProvider? attendance,
  }) {
    final d = _doctors[doctorId];
    if (d == null) return 'Doctor not found';
    final when = date ?? DateTime.now();
    if (_requireAttendance && attendance != null) {
      final key = DateTime(when.year, when.month, when.day);
      final states = attendance.attendance[d.name];
      final present = states != null ? (states[key] ?? false) : false;
      if (!present) return 'Doctor is not marked present for ${key.toIso8601String().split('T').first}';
    }
    if (dedupeTag != null && _ledger.any((e) => e.note == dedupeTag)) {
      return null; // already recorded
    }
    final split = allocate(doctorId, procedureKey, amountReceived);
    final entry = PaymentEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      doctorId: doctorId,
      date: when,
      procedureKey: procedureKey,
      amountReceived: amountReceived,
      doctorShare: split.$1,
      clinicShare: split.$2,
      patient: patient,
      note: dedupeTag ?? note,
    );
    _ledger.add(entry);
    _recomputeTotals();
    notifyListeners();
    _persist();
    _writeLedgerRemote(entry);
    return null;
  }

  // Per-doctor summary -------------------------------------------------------
  ({double doctorEarned, double clinicEarned, double payouts, double outstanding}) summaryFor(String doctorId) {
    double doc = 0, clinic = 0, payouts = 0;
    for (final e in _ledger) {
      if (e.doctorId != doctorId) continue;
      if (e.type == EntryType.payout) {
        payouts += e.doctorShare;
      } else {
        doc += e.doctorShare;
        clinic += e.clinicShare;
      }
    }
    final outstanding = doc - payouts;
    return (doctorEarned: doc, clinicEarned: clinic, payouts: payouts, outstanding: outstanding);
  }

  // Record a payout against a doctor balance
  void recordPayout({required String doctorId, required double amount, DateTime? date, String? note}) {
    final when = date ?? DateTime.now();
    final entry = PaymentEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      doctorId: doctorId,
      date: when,
      procedureKey: 'payout',
      amountReceived: 0,
      doctorShare: amount,
      clinicShare: 0,
      patient: null,
      note: note,
      type: EntryType.payout,
    );
    _ledger.add(entry);
    // Recompute totals to keep consistency (payouts should not affect totals)
    _recomputeTotals();
    notifyListeners();
    _persist();
    _writeLedgerRemote(entry);
  }

  // Overload with payout mode
  void recordPayoutWithMode({required String doctorId, required double amount, DateTime? date, String? note, String? mode}) {
    final when = date ?? DateTime.now();
    final entry = PaymentEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      doctorId: doctorId,
      date: when,
      procedureKey: 'payout',
      amountReceived: 0,
      doctorShare: amount,
      clinicShare: 0,
      patient: null,
      note: note,
      mode: mode,
      type: EntryType.payout,
    );
    _ledger.add(entry);
    _recomputeTotals();
    notifyListeners();
    _persist();
    _writeLedgerRemote(entry);
  }

  // Delete a ledger entry by id
  void deleteLedgerEntry(String entryId) {
    final idx = _ledger.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
    _ledger.removeAt(idx);
    _recomputeTotals();
    notifyListeners();
    _persist();
    _deleteLedgerRemote(entryId);
  }

  // Ledger filters -----------------------------------------------------------
  List<PaymentEntry> filteredLedger({String? doctorId, String? procedureKey, DateTime? start, DateTime? end}) {
    return _ledger.where((e) {
      if (doctorId != null && e.doctorId != doctorId) return false;
      if (procedureKey != null && e.procedureKey != procedureKey) return false;
      if (start != null && e.date.isBefore(start)) return false;
      if (end != null && e.date.isAfter(end)) return false;
      return true;
    }).toList();
  }

  // Export CSV ---------------------------------------------------------------
  String exportCsv(List<PaymentEntry> entries) {
    final buf = StringBuffer('Date,Doctor,Type,Procedure,Amount,DoctorShare,ClinicShare,Patient,Note\n');
    for (final e in entries) {
      final d = byId(e.doctorId)?.name ?? e.doctorId;
      final dateStr = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
      final type = e.type.name;
      final row = [
        dateStr,
        _csvEscape(d),
        _csvEscape(type),
        _csvEscape(e.procedureKey),
        e.amountReceived.toStringAsFixed(0),
        e.doctorShare.toStringAsFixed(0),
        e.clinicShare.toStringAsFixed(0),
        _csvEscape(e.patient ?? ''),
        _csvEscape(e.note ?? ''),
      ].join(',');
      buf.writeln(row);
    }
    return buf.toString();
  }

  String _csvEscape(String s) {
    final needsQuotes = s.contains(',') || s.contains('"') || s.contains('\n');
    final escaped = s.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  // Persistence --------------------------------------------------------------
  static const _kDoctors = 'doctors_v2';
  static const _kLedger = 'ledger_v1';
  static const _kRequireAttendance = 'doc_require_attendance_v1';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _requireAttendance = prefs.getBool(_kRequireAttendance) ?? false;
    String? docStr = prefs.getString(_kDoctors);
    // Backward-compat: read v1 if v2 missing
    docStr ??= prefs.getString('doctors_v1');
    if (docStr != null && docStr.isNotEmpty) {
      final List<dynamic> list = List<dynamic>.from(jsonDecode(docStr));
      _doctors.clear();
      for (final m in list) {
        final map = Map<String, dynamic>.from(m as Map);
        // manual parse Doctor
        final id = map['id'] as String;
        final name = map['name'] as String;
        final roleIndex = map['role'] as int;
        final active = (map['active'] as bool? ) ?? true;
        final photoPath = map['photoPath'] as String?;
        // New optional profile fields (v2)
        DoctorSex sex = DoctorSex.male;
        final rawSex = map['sex'];
        if (rawSex is String) {
          switch (rawSex.toLowerCase()) {
            case 'female': sex = DoctorSex.female; break;
            case 'other': sex = DoctorSex.other; break;
            default: sex = DoctorSex.male; break;
          }
        } else if (rawSex is int) {
          sex = DoctorSex.values[(rawSex).clamp(0, DoctorSex.values.length-1)];
        }
        final int? age = (map['age'] is num) ? (map['age'] as num).toInt() : null;
        final DateTime? dob = map['dob'] is String ? DateTime.tryParse(map['dob'] as String) : null;
        final String? phone = map['phone'] as String?;
        final String? address = map['address'] as String?;
        final String? registrationNumber = map['registrationNumber'] as String?;
        final String? registeredState = map['registeredState'] as String?;
        EmploymentType employmentType = EmploymentType.consultant;
        final rawEmp = map['employmentType'];
        if (rawEmp is String) {
          switch (rawEmp.toLowerCase()) {
            case 'permanent': employmentType = EmploymentType.permanent; break;
            case 'consultant': employmentType = EmploymentType.consultant; break;
          }
        } else if (rawEmp is int) {
          employmentType = EmploymentType.values[(rawEmp).clamp(0, EmploymentType.values.length-1)];
        }
        final rawRules = Map<String, dynamic>.from(map['rules'] as Map);
        final rules = <String, PaymentRule>{};
        rawRules.forEach((k, v) {
          final mv = Map<String, dynamic>.from(v as Map);
          final mode = mv['mode'] as String;
          final value = (mv['value'] as num).toDouble();
          final price = mv['clinicPrice'] == null ? null : (mv['clinicPrice'] as num).toDouble();
          rules[k] = (mode == 'fixed') ? PaymentRule.fixed(value, clinicPrice: price) : PaymentRule.percent(value, clinicPrice: price);
        });
        _doctors[id] = Doctor(
          id: id,
          name: name,
          role: DoctorRole.values[roleIndex],
          rules: rules,
          active: active,
          photoPath: photoPath,
          sex: sex,
          age: age,
          dob: dob,
          phone: phone,
          address: address,
          registrationNumber: registrationNumber,
          registeredState: registeredState,
          employmentType: employmentType,
        );
      }
    }
    final ledStr = prefs.getString(_kLedger);
    _ledger.clear();
    _totalDoctor = 0;
    _totalClinic = 0;
    if (ledStr != null && ledStr.isNotEmpty) {
      final List<dynamic> list = List<dynamic>.from(jsonDecode(ledStr));
      for (final m in list) {
        final e = PaymentEntry.fromJson(Map<String, dynamic>.from(m as Map));
        _ledger.add(e);
      }
    }
    // Ensure payouts are excluded and totals are consistent on load
    _recomputeTotals();
    notifyListeners();

    // Attempt remote sync and live listeners
    await _syncWithRemote();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRequireAttendance, _requireAttendance);
    // Doctors
      final docsList = _doctors.values.map((d) => {
        'id': d.id,
        'name': d.name,
        'role': d.role.index,
        'active': d.active,
        'photoPath': d.photoPath,
        // New fields (v2)
        'sex': d.sex.name,
        'age': d.age,
        'dob': d.dob?.toIso8601String(),
        'phone': d.phone,
        'address': d.address,
        'registrationNumber': d.registrationNumber,
        'registeredState': d.registeredState,
        'employmentType': d.employmentType.name,
        'rules': d.rules.map((key, r) => MapEntry(key, {
          'mode': r.mode == PaymentMode.fixed ? 'fixed' : 'percent',
          'value': r.value,
          'clinicPrice': r.clinicPrice,
        })),
      });
    await prefs.setString(_kDoctors, jsonEncode(docsList.toList()));
    // Ledger
    final ledList = _ledger.map((e) => e.toJson()).toList();
    await prefs.setString(_kLedger, jsonEncode(ledList));
  }

  // ---------- Firebase helpers ----------
  String? _uid() => _auth.currentUser?.uid;

  Future<void> _syncWithRemote() async {
    if (_remoteListening) return;
    final uid = _uid();
    if (uid == null) return;
    try {
      // Load remote doctors and ledger
      final docsSnap = await _db.collection('users').doc(uid).collection('doctors').get();
      final ledSnap = await _db.collection('users').doc(uid).collection('doctor_ledger').get();

      final remoteDoctors = <Doctor>[];
      for (final d in docsSnap.docs) {
        final data = d.data();
        final rulesMap = Map<String, dynamic>.from((data['rules'] as Map?) ?? {});
        final rules = <String, PaymentRule>{};
        rulesMap.forEach((key, v) {
          final mv = Map<String, dynamic>.from(v as Map);
          final mode = (mv['mode'] as String?) ?? 'percent';
          final value = (mv['value'] as num).toDouble();
          final price = mv['clinicPrice'] == null ? null : (mv['clinicPrice'] as num).toDouble();
          rules[key] = mode == 'fixed' ? PaymentRule.fixed(value, clinicPrice: price) : PaymentRule.percent(value, clinicPrice: price);
        });
        // New optional fields
        DoctorSex sex = DoctorSex.male;
        final rawSex = data['sex'];
        if (rawSex is String) {
          switch (rawSex.toLowerCase()) { case 'female': sex = DoctorSex.female; break; case 'other': sex = DoctorSex.other; break; default: sex = DoctorSex.male; }
        } else if (rawSex is int) { sex = DoctorSex.values[(rawSex).clamp(0, DoctorSex.values.length-1)]; }
        EmploymentType emp = EmploymentType.consultant;
        final rawEmp = data['employmentType'];
        if (rawEmp is String) { emp = rawEmp.toLowerCase() == 'permanent' ? EmploymentType.permanent : EmploymentType.consultant; }
        else if (rawEmp is int) { emp = EmploymentType.values[(rawEmp).clamp(0, EmploymentType.values.length-1)]; }
        remoteDoctors.add(Doctor(
          id: (data['id'] as String?) ?? d.id,
          name: (data['name'] as String?) ?? 'Doctor',
          role: DoctorRole.values[(data['role'] as int?) ?? 0],
          active: (data['active'] as bool?) ?? true,
          photoPath: data['photoPath'] as String?,
          rules: rules,
          sex: sex,
          age: (data['age'] as num?)?.toInt(),
          dob: data['dob'] is String ? DateTime.tryParse(data['dob'] as String) : null,
          phone: data['phone'] as String?,
          address: data['address'] as String?,
          registrationNumber: data['registrationNumber'] as String?,
          registeredState: data['registeredState'] as String?,
          employmentType: emp,
        ));
      }

      final remoteLedger = <PaymentEntry>[];
      for (final e in ledSnap.docs) {
        remoteLedger.add(PaymentEntry.fromJson(e.data()));
      }

      final hasRemote = remoteDoctors.isNotEmpty || remoteLedger.isNotEmpty;
      final hasLocal = _doctors.isNotEmpty || _ledger.isNotEmpty;
      if (!hasRemote && hasLocal) {
        // Push local to remote (first sync scenario)
        for (final d in _doctors.values) {
          await _writeDoctorRemote(d);
        }
        for (final e in _ledger) {
          await _writeLedgerRemote(e);
        }
        await _writeSettingsRemote();
      } else if (hasRemote) {
        // Override local with remote
        _doctors
          ..clear()
          ..addEntries(remoteDoctors.map((d) => MapEntry(d.id, d)));
        _ledger
          ..clear()
          ..addAll(remoteLedger);
        _recomputeTotals();
        notifyListeners();
        await _persist();
      }

      // Start live listeners for real-time sync
      _db.collection('users').doc(uid).collection('doctors').snapshots().listen((snap) {
        _doctors.clear();
        for (final d in snap.docs) {
          final data = d.data();
          final rulesMap = Map<String, dynamic>.from((data['rules'] as Map?) ?? {});
          final rules = <String, PaymentRule>{};
          rulesMap.forEach((key, v) {
            final mv = Map<String, dynamic>.from(v as Map);
            final mode = (mv['mode'] as String?) ?? 'percent';
            final value = (mv['value'] as num).toDouble();
            final price = mv['clinicPrice'] == null ? null : (mv['clinicPrice'] as num).toDouble();
            rules[key] = mode == 'fixed' ? PaymentRule.fixed(value, clinicPrice: price) : PaymentRule.percent(value, clinicPrice: price);
          });
          DoctorSex sex = DoctorSex.male;
          final rawSex = data['sex'];
          if (rawSex is String) {
            switch (rawSex.toLowerCase()) { case 'female': sex = DoctorSex.female; break; case 'other': sex = DoctorSex.other; break; default: sex = DoctorSex.male; }
          } else if (rawSex is int) { sex = DoctorSex.values[(rawSex).clamp(0, DoctorSex.values.length-1)]; }
          EmploymentType emp = EmploymentType.consultant;
          final rawEmp = data['employmentType'];
          if (rawEmp is String) { emp = rawEmp.toLowerCase() == 'permanent' ? EmploymentType.permanent : EmploymentType.consultant; }
          else if (rawEmp is int) { emp = EmploymentType.values[(rawEmp).clamp(0, EmploymentType.values.length-1)]; }
          _doctors[(data['id'] as String?) ?? d.id] = Doctor(
            id: (data['id'] as String?) ?? d.id,
            name: (data['name'] as String?) ?? 'Doctor',
            role: DoctorRole.values[(data['role'] as int?) ?? 0],
            active: (data['active'] as bool?) ?? true,
            photoPath: data['photoPath'] as String?,
            rules: rules,
            sex: sex,
            age: (data['age'] as num?)?.toInt(),
            dob: data['dob'] is String ? DateTime.tryParse(data['dob'] as String) : null,
            phone: data['phone'] as String?,
            address: data['address'] as String?,
            registrationNumber: data['registrationNumber'] as String?,
            registeredState: data['registeredState'] as String?,
            employmentType: emp,
          );
        }
        notifyListeners();
        _persist();
      });

      _db.collection('users').doc(uid).collection('doctor_ledger').orderBy('date').snapshots().listen((snap) {
        _ledger
          ..clear()
          ..addAll(snap.docs.map((d) => PaymentEntry.fromJson(d.data())));
        _recomputeTotals();
        notifyListeners();
        _persist();
      });

      _remoteListening = true;
    } catch (_) {
      // Ignore sync errors; app will continue with local cache
    }
  }

  Future<void> _writeDoctorRemote(Doctor d) async {
    final uid = _uid();
    if (uid == null) return;
    try {
      final doc = {
        'id': d.id,
        'name': d.name,
        'role': d.role.index,
        'active': d.active,
        'photoPath': d.photoPath,
        'sex': d.sex.name,
        'age': d.age,
        'dob': d.dob?.toIso8601String(),
        'phone': d.phone,
        'address': d.address,
        'registrationNumber': d.registrationNumber,
        'registeredState': d.registeredState,
        'employmentType': d.employmentType.name,
    'rules': d.rules.map((k, r) => MapEntry(k, {
      'mode': r.mode == PaymentMode.fixed ? 'fixed' : 'percent',
      'value': r.value,
      'clinicPrice': r.clinicPrice,
    })),
      };
      await _db.collection('users').doc(uid).collection('doctors').doc(d.id).set(doc);
    } catch (_) {}
  }

  Future<void> _deleteDoctorRemote(String id) async {
    final uid = _uid();
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).collection('doctors').doc(id).delete();
    } catch (_) {}
  }

  Future<void> _writeLedgerRemote(PaymentEntry e) async {
    final uid = _uid();
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).collection('doctor_ledger').doc(e.id).set(e.toJson());
    } catch (_) {}
  }

  Future<void> _deleteLedgerRemote(String id) async {
    final uid = _uid();
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).collection('doctor_ledger').doc(id).delete();
    } catch (_) {}
  }

  Future<void> _writeSettingsRemote() async {
    final uid = _uid();
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).collection('settings').doc('doctor').set({
            'requireAttendance': _requireAttendance,
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  // Manual refresh callable from UI; performs a one-time fetch even if listeners are active
  Future<void> refresh() async {
    final uid = _uid();
    if (uid == null) return;
    try {
      final docsSnap = await _db.collection('users').doc(uid).collection('doctors').get();
      final ledSnap = await _db.collection('users').doc(uid).collection('doctor_ledger').get();

      final remoteDoctors = <Doctor>[];
      for (final d in docsSnap.docs) {
        final data = d.data();
        final rulesMap = Map<String, dynamic>.from((data['rules'] as Map?) ?? {});
        final rules = <String, PaymentRule>{};
        rulesMap.forEach((key, v) {
          final mv = Map<String, dynamic>.from(v as Map);
          final mode = (mv['mode'] as String?) ?? 'percent';
          final value = (mv['value'] as num).toDouble();
          final price = mv['clinicPrice'] == null ? null : (mv['clinicPrice'] as num).toDouble();
          rules[key] = mode == 'fixed' ? PaymentRule.fixed(value, clinicPrice: price) : PaymentRule.percent(value, clinicPrice: price);
        });
        DoctorSex sex = DoctorSex.male;
        final rawSex = data['sex'];
        if (rawSex is String) {
          switch (rawSex.toLowerCase()) { case 'female': sex = DoctorSex.female; break; case 'other': sex = DoctorSex.other; break; default: sex = DoctorSex.male; }
        } else if (rawSex is int) { sex = DoctorSex.values[(rawSex).clamp(0, DoctorSex.values.length-1)]; }
        EmploymentType emp = EmploymentType.consultant;
        final rawEmp = data['employmentType'];
        if (rawEmp is String) { emp = rawEmp.toLowerCase() == 'permanent' ? EmploymentType.permanent : EmploymentType.consultant; }
        else if (rawEmp is int) { emp = EmploymentType.values[(rawEmp).clamp(0, EmploymentType.values.length-1)]; }
        remoteDoctors.add(Doctor(
          id: (data['id'] as String?) ?? d.id,
          name: (data['name'] as String?) ?? 'Doctor',
          role: DoctorRole.values[(data['role'] as int?) ?? 0],
          active: (data['active'] as bool?) ?? true,
          photoPath: data['photoPath'] as String?,
          rules: rules,
          sex: sex,
          age: (data['age'] as num?)?.toInt(),
          dob: data['dob'] is String ? DateTime.tryParse(data['dob'] as String) : null,
          phone: data['phone'] as String?,
          address: data['address'] as String?,
          registrationNumber: data['registrationNumber'] as String?,
          registeredState: data['registeredState'] as String?,
          employmentType: emp,
        ));
      }

      final remoteLedger = <PaymentEntry>[];
      for (final e in ledSnap.docs) {
        remoteLedger.add(PaymentEntry.fromJson(e.data()));
      }

      _doctors
        ..clear()
        ..addEntries(remoteDoctors.map((d) => MapEntry(d.id, d)));
      _ledger
        ..clear()
        ..addAll(remoteLedger);
      _recomputeTotals();
      notifyListeners();
      await _persist();
    } catch (_) {}
  }
}
