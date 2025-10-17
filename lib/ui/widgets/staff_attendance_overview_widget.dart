import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'halfday_tile.dart';
import '../../providers/staff_attendance_provider.dart';

/// View-only variant of the staff attendance calendar used in Dashboard Overview.
/// This widget is intentionally separate from the interactive staff page widget
/// so structural changes in one do not affect the other.
class StaffAttendanceOverviewWidget extends StatefulWidget {
  const StaffAttendanceOverviewWidget({super.key});
  @override
  State<StaffAttendanceOverviewWidget> createState() => _StaffAttendanceOverviewWidgetState();
}

enum _AttStatus { present, absent, halfMorningOff, halfAfternoonOff, none }

class _StaffSimple { final String id; final String name; const _StaffSimple(this.id, this.name); }

class _SampleStore {
  final List<_StaffSimple> staff;
  final Map<String, Map<String, _AttStatus>> _data = {};
  _SampleStore(this.staff) {
    final now = DateTime.now();
    for (final s in staff) {
      _data[s.id] = {};
      final end = DateTime(now.year, now.month + 1, 0);
      final rnd = Random(s.id.hashCode ^ now.month);
      for (int d = 1; d <= end.day; d++) {
        final date = DateTime(now.year, now.month, d);
        if (date.isAfter(DateTime(now.year, now.month, now.day))) continue;
        final r = rnd.nextDouble();
        _AttStatus st;
        if (r < 0.65) st = _AttStatus.present;
        else if (r < 0.78) st = _AttStatus.halfAfternoonOff;
        else if (r < 0.91) st = _AttStatus.halfMorningOff;
        else st = _AttStatus.absent;
        _data[s.id]![key(date)] = st;
      }
    }
  }
  static String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  _AttStatus status(String staffId, DateTime date) => _data[staffId]?[key(date)] ?? _AttStatus.none;
  double presentDays(String staffId, int y, int m) {
    final end = DateTime(y, m + 1, 0); double sum = 0;
    for (int d = 1; d <= end.day; d++) {
      switch (status(staffId, DateTime(y, m, d))) {
        case _AttStatus.present: sum += 1; break;
        case _AttStatus.absent: break;
        case _AttStatus.halfAfternoonOff: sum += .5; break;
        case _AttStatus.halfMorningOff: sum += .5; break;
        case _AttStatus.none: break;
      }
    }
    return sum;
  }
  double absentDays(String staffId, int y, int m) {
    final end = DateTime(y, m + 1, 0); double sum = 0;
    for (int d = 1; d <= end.day; d++) {
      switch (status(staffId, DateTime(y, m, d))) {
        case _AttStatus.present: break;
        case _AttStatus.absent: sum += 1; break;
        case _AttStatus.halfAfternoonOff: sum += .5; break;
        case _AttStatus.halfMorningOff: sum += .5; break;
        case _AttStatus.none: break;
      }
    }
    return sum;
  }
}

class _StaffAttendanceOverviewWidgetState extends State<StaffAttendanceOverviewWidget> {
  final List<_StaffSimple> _staff = const [
    _StaffSimple('s1','Udaya'), _StaffSimple('s2','Keerthi'), _StaffSimple('s3','Madhan'),
  ];
  late final _SampleStore _store = _SampleStore(_staff);
  int _staffIdx = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _prevMonth() => setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _nextMonth() => setState(() => _month = DateTime(_month.year, _month.month + 1));
  Future<void> _pickMonth() async {
    final picked = await showDatePicker(context: context, initialDate: _month, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _month = DateTime(picked.year, picked.month));
  }
  String _ml(DateTime m) { const ms=['January','February','March','April','May','June','July','August','September','October','November','December']; return '${ms[m.month-1]} ${m.year}'; }

  List<DateTime> _days() { final f = DateTime(_month.year, _month.month, 1); final l = DateTime(_month.year, _month.month + 1, 0); return List.generate(l.day, (i) => DateTime(f.year, f.month, i+1)); }

  @override
  Widget build(BuildContext context) {
    StaffAttendanceProvider? prov; try { prov = context.watch<StaffAttendanceProvider>(); } catch (_) { prov = null; }
    final bool hasStaff = prov != null && prov.staffNames.isNotEmpty;
  final List<String> staffNames = hasStaff ? prov.staffNames : const <String>[];

    // If no staff have been added, show an empty state rather than sample data
    if (!hasStaff) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('Staff Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              SizedBox(height: 12),
              Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Text('Add staff to view attendance', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
              )),
            ],
          ),
        ),
      );
    }

    // We have staff in provider, pick the current staff name based on index
    String staffName = staffNames[_staffIdx.clamp(0, staffNames.length-1)];

  final days = _days();
  const double cellHeight = 40, cellWidth = 56, spacing = 4;
  final double gridWidth = cellWidth*7 + spacing*6;
  // Compute intrinsic grid height for this month
  final int firstWeekday = DateTime(_month.year, _month.month, 1).weekday; // Mon=1
  final int leading = (firstWeekday + 6) % 7;
  final int lastDay = DateTime(_month.year, _month.month + 1, 0).day;
  final int totalCells = leading + lastDay;
  final int rows = (totalCells / 7).ceil();
  final double gridHeight = rows * cellHeight + (rows - 1) * spacing;
    double present = 0, absent = 0;
  if (prov.staffNames.contains(staffName)) {
      present = prov.presentCount(staffName, _month.year, _month.month) / 2.0;
      absent = prov.absentCount(staffName, _month.year, _month.month) / 2.0;
    } else {
      // Shouldn't happen with hasStaff check, but keep safe defaults
      present = 0;
      absent = 0;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Staff Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(onPressed: () { if (staffNames.isNotEmpty) setState(() { _staffIdx = (_staffIdx - 1 + staffNames.length) % staffNames.length; }); }, icon: const Icon(Icons.chevron_left)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF8B27E2), borderRadius: BorderRadius.circular(20), boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 6, offset: const Offset(0,2))
              ]),
              child: Text(staffName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            IconButton(onPressed: () { if (staffNames.isNotEmpty) setState(() { _staffIdx = (_staffIdx + 1) % staffNames.length; }); }, icon: const Icon(Icons.chevron_right)),
          ]),
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: gridWidth,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
                GestureDetector(
                  onTap: _pickMonth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_ml(_month), style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(width: 6), const Icon(Icons.calendar_today, size: 16),
                    ]),
                  ),
                ),
                IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
              ]),
            ),
          ),
          Center(
            child: SizedBox(
              width: gridWidth,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _legendBox(const Color(0xFF8B27E2), 'Present'), const SizedBox(width: 12), _legendBox(const Color(0xFFD9B6FF), 'Absent'), const SizedBox(width: 12), _legendSplit(),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          // Week header
          Center(child: SizedBox(width: gridWidth, child: Row(children: [
            for (int i=0;i<7;i++) ...[
              SizedBox(
                width: cellWidth,
                child: Center(child: Text(const ['M','T','W','T','F','S','S'][i], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              ),
              if (i<6) const SizedBox(width: spacing),
            ]
          ]))),
          const SizedBox(height: 6),
          // Calendar grid (view-only): fixed to intrinsic height; parent scrolls if needed.
          SizedBox(
            height: gridHeight,
            child: _buildCalendarViewOnly(days, staffName, gridWidth: gridWidth, cellWidth: cellWidth, cellHeight: cellHeight, spacing: spacing, prov: prov),
          ),
          const SizedBox(height: 8),
          Text('Total Present: ${present.toStringAsFixed(present % 1 == 0 ? 0 : 1)} days,  Total Absent: ${absent.toStringAsFixed(absent % 1 == 0 ? 0 : 1)} days',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _buildCalendarViewOnly(List<DateTime> days, String staffName, {required double gridWidth, required double cellWidth, required double cellHeight, required double spacing, StaffAttendanceProvider? prov}) {
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday; // Mon=1
    final leading = (firstWeekday + 6) % 7; // blanks before 1st
    final lastDay = DateTime(_month.year, _month.month + 1, 0).day;
    final totalCells = leading + lastDay;
    final rows = (totalCells / 7).ceil();

    return Center(
      child: SizedBox(
        width: gridWidth,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: cellWidth / cellHeight,
          ),
          itemCount: rows * 7,
          itemBuilder: (context, index) {
            final dayNum = index - leading + 1;
            if (dayNum < 1 || dayNum > lastDay) return const SizedBox.shrink();
            final date = DateTime(_month.year, _month.month, dayNum);

            bool? morning, evening;
            if (prov != null && prov.staffNames.contains(staffName)) {
              final split = prov.stateForSplit(staffName, date);
              morning = split[0]; evening = split[1];
            } else {
              final s = _staff.firstWhere((x)=>x.name==staffName, orElse:()=>_staff.first);
              final st = _store.status(s.id, date);
              switch (st) {
                case _AttStatus.present: morning = true; evening = true; break;
                case _AttStatus.absent: morning = false; evening = false; break;
                case _AttStatus.halfAfternoonOff: morning = true; evening = false; break;
                case _AttStatus.halfMorningOff: morning = false; evening = true; break;
                case _AttStatus.none: morning = null; evening = null; break;
              }
            }

            final isFutureInCurrentMonth = _month.year == DateTime.now().year && _month.month == DateTime.now().month && date.isAfter(DateTime.now());
            final bgColorNone = isFutureInCurrentMonth ? const Color(0xFFE5E5E5) : Colors.grey.shade200;

            return Center(
              child: SizedBox(
                width: cellWidth, height: cellHeight,
                child: Stack(alignment: Alignment.center, children: [
                  HalfDayTile(morning: morning, evening: evening, width: cellWidth, height: cellHeight, size: cellHeight, radius: 12, presentColor: const Color(0xFF8B27E2), absentColor: const Color(0xFFD9B6FF), noneColor: bgColorNone),
                  Text('$dayNum', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black87)),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _legendBox(Color color, String label) => Row(children: [
    Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 12)),
  ]);

  Widget _legendSplit() => Row(children: [
    SizedBox(
      width: 20, height: 14,
      child: Row(children: [
        Expanded(child: Container(decoration: const BoxDecoration(color: Color(0xFFD9B6FF), borderRadius: BorderRadius.only(topLeft: Radius.circular(3), bottomLeft: Radius.circular(3))))),
        Expanded(child: Container(decoration: const BoxDecoration(color: Color(0xFF8B27E2), borderRadius: BorderRadius.only(topRight: Radius.circular(3), bottomRight: Radius.circular(3))))),
      ]),
    ),
    const SizedBox(width: 6),
    const Text('Half Day', style: TextStyle(fontSize: 12)),
  ]);
}
