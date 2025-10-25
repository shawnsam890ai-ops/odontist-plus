import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'halfday_tile.dart';
import '../../providers/staff_attendance_provider.dart';

enum AttendanceStatus { present, absent, halfMorningOff, halfAfternoonOff, none }

class StaffMemberSimple {
  final String id;
  final String name;
  const StaffMemberSimple({required this.id, required this.name});
}

class _SampleAttendanceStore {
  final List<StaffMemberSimple> staff;
  // key: staffId -> yyyy-mm-dd -> status
  final Map<String, Map<String, AttendanceStatus>> _data = {};

  _SampleAttendanceStore(this.staff) {
    final now = DateTime.now();
    for (final s in staff) {
      _data[s.id] = {};
      // seed some demo data for the current month
  final end = DateTime(now.year, now.month + 1, 0);
      final rnd = Random(s.id.hashCode ^ now.month);
      for (int d = 1; d <= end.day; d++) {
        final date = DateTime(now.year, now.month, d);
        // only up to today we fill random states; future -> none
        if (date.isAfter(DateTime(now.year, now.month, now.day))) continue;
        final r = rnd.nextDouble();
        AttendanceStatus st;
        if (r < 0.65) {
          st = AttendanceStatus.present;
        } else if (r < 0.78) {
          st = AttendanceStatus.halfAfternoonOff; // morning present
        } else if (r < 0.91) {
          st = AttendanceStatus.halfMorningOff; // morning absent
        } else {
          st = AttendanceStatus.absent;
        }
        _data[s.id]![_key(date)] = st;
      }
    }
  }

  static String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  AttendanceStatus status(String staffId, DateTime date) {
    return _data[staffId]?[_key(date)] ?? AttendanceStatus.none;
  }

  double presentCount(String staffId, int year, int month) {
    final end = DateTime(year, month + 1, 0);
    double sum = 0;
    for (int d = 1; d <= end.day; d++) {
      final st = status(staffId, DateTime(year, month, d));
      switch (st) {
        case AttendanceStatus.present:
          sum += 1; break;
        case AttendanceStatus.absent:
          break;
        case AttendanceStatus.halfAfternoonOff:
          sum += 0.5; break;
        case AttendanceStatus.halfMorningOff:
          sum += 0.5; break;
        case AttendanceStatus.none:
          break;
      }
    }
    return sum;
  }

  double absentCount(String staffId, int year, int month) {
    final end = DateTime(year, month + 1, 0);
    double sum = 0;
    for (int d = 1; d <= end.day; d++) {
      final st = status(staffId, DateTime(year, month, d));
      switch (st) {
        case AttendanceStatus.present:
          break;
        case AttendanceStatus.absent:
          sum += 1; break;
        case AttendanceStatus.halfAfternoonOff:
          sum += 0.5; break;
        case AttendanceStatus.halfMorningOff:
          sum += 0.5; break;
        case AttendanceStatus.none:
          break;
      }
    }
    return sum;
  }
}

class StaffAttendanceWidget extends StatefulWidget {
  final bool showHeader;
  final String? selectedStaff;
  final bool showMonthToggle;
  const StaffAttendanceWidget({super.key, this.showHeader = true, this.selectedStaff, this.showMonthToggle = false});
  @override
  State<StaffAttendanceWidget> createState() => _StaffAttendanceWidgetState();
}

class _StaffAttendanceWidgetState extends State<StaffAttendanceWidget> {
  final List<StaffMemberSimple> _staff = const [
    StaffMemberSimple(id: 's1', name: 'Udaya'),
    StaffMemberSimple(id: 's2', name: 'Keerthi'),
    StaffMemberSimple(id: 's3', name: 'Madhan'),
  ];
  late final _SampleAttendanceStore _store = _SampleAttendanceStore(_staff);

  int _staffIdx = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  // navigation handlers are inlined where used
  void _prevMonth() => setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _nextMonth() => setState(() => _month = DateTime(_month.year, _month.month + 1));

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.day,
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month));
    }
  }

  String _monthLabel(DateTime m) {
    const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    return '${months[m.month - 1]} ${m.year}';
  }

  List<DateTime> _daysInMonth() {
    final first = DateTime(_month.year, _month.month, 1);
    final last = DateTime(_month.year, _month.month + 1, 0);
    return List.generate(last.day, (i) => DateTime(first.year, first.month, i + 1));
  }

  @override
  Widget build(BuildContext context) {
    // Prefer provider-backed data when available
    StaffAttendanceProvider? prov;
    try {
      prov = context.watch<StaffAttendanceProvider>();
    } catch (_) {
      prov = null;
    }

    final staffList = prov != null && prov.staffNames.isNotEmpty ? prov.staffNames : _staff.map((s) => s.name).toList();

    // If a selectedStaff prop is provided use that; otherwise use index
    String staffName;
    if (widget.selectedStaff != null && staffList.contains(widget.selectedStaff)) {
      staffName = widget.selectedStaff!;
      _staffIdx = staffList.indexOf(staffName);
    } else if (staffList.isNotEmpty) {
      staffName = staffList[_staffIdx.clamp(0, staffList.length - 1)];
    } else {
      staffName = _staff[_staffIdx].name;
    }

  final days = _daysInMonth();
  // Base calendar layout parameters (will adapt to available width)
  const double cellHeight = 40.0; // desired height
  const double desiredCellWidth = 56.0;  // desired width (will shrink on narrow screens)
  const double spacing = 4.0;     // spacing between day tiles
  // gridWidth and cellWidth will be finalized by LayoutBuilder below
  double gridWidth = desiredCellWidth * 7 + spacing * 6;
  double cellWidth = desiredCellWidth;
    double present = 0, absent = 0;
    if (prov != null && prov.staffNames.contains(staffName)) {
      present = prov.presentCount(staffName, _month.year, _month.month) / 2.0;
      absent = prov.absentCount(staffName, _month.year, _month.month) / 2.0;
    } else {
      final s = _staff.firstWhere((x) => x.name == staffName, orElse: () => _staff.isNotEmpty ? _staff.first : StaffMemberSimple(id: 'x', name: staffName));
      present = _store.presentCount(s.id, _month.year, _month.month);
      absent = _store.absentCount(s.id, _month.year, _month.month);
    }


    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LayoutBuilder(builder: (context, constraints) {
          // If the card's available width is smaller than our desired grid, shrink cell width to fit
          final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : gridWidth;
          if (maxW < gridWidth) {
            gridWidth = maxW;
            cellWidth = (gridWidth - spacing * 6) / 7;
          }

          return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Optional header (when embedding inside a larger staff page, hide to avoid duplicate controls)
            if (widget.showHeader) ...[
              // Header
              Row(children: [
                const Text('Staff Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                // Staff toggle at top-right with arrows and pill
                IconButton(onPressed: () { if (staffList.isNotEmpty) setState(() { _staffIdx = (_staffIdx - 1 + staffList.length) % staffList.length; }); }, icon: const Icon(Icons.chevron_left)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF8B27E2), borderRadius: BorderRadius.circular(20), boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 6, offset: const Offset(0,2))
                  ]),
                  child: Text(staffName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                IconButton(onPressed: () { if (staffList.isNotEmpty) setState(() { _staffIdx = (_staffIdx + 1) % staffList.length; }); }, icon: const Icon(Icons.chevron_right)),
              ]),
              const SizedBox(height: 8),
            ],
            // Month toggle row centered to the grid width, with legend in its own row
            if (widget.showHeader || widget.showMonthToggle) ...[
              Center(
                child: SizedBox(
                  width: gridWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
                      GestureDetector(
                        onTap: _pickMonth,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_monthLabel(_month), style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 6),
                              const Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ),
                      ),
                      IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
                    ],
                  ),
                ),
              ),
              if (widget.showHeader) ...[
                const SizedBox(height: 6),
                Center(
                  child: SizedBox(
                    width: gridWidth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _legendBox(const Color(0xFF8B27E2), 'Present'),
                        const SizedBox(width: 12),
                        _legendBox(const Color(0xFFD9B6FF), 'Absent'),
                        const SizedBox(width: 12),
                        _legendSplit(),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
            // Weekday headers (Mon .. Sun) aligned to grid width and cell size
            Center(
              child: SizedBox(
                width: gridWidth,
                child: Row(children: [
                  for (int i = 0; i < 7; i++) ...[
                    SizedBox(
                      width: cellWidth,
                      child: Center(child: Text(const ['M','T','W','T','F','S','S'][i], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    ),
                    if (i < 6) SizedBox(width: spacing),
                  ]
                ]),
              ),
            ),
            const SizedBox(height: 6),
            // Calendar grid
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
        child: prov != null && prov.staffNames.contains(staffName)
          ? _buildCalendarProvider(days, staffName, gridWidth: gridWidth, cellWidth: cellWidth, cellHeight: cellHeight, spacing: spacing, key: ValueKey('prov-${_month.year}-${_month.month}-$staffName'))
          : _buildCalendar(days, _staff.firstWhere((s) => s.name == staffName, orElse: () => _staff.first).id, gridWidth: gridWidth, cellWidth: cellWidth, cellHeight: cellHeight, spacing: spacing, key: ValueKey('${_month.year}-${_month.month}-${staffName}')),
              ),
            ),
            const SizedBox(height: 8),
            // Summary
            Text('Total Present: ${present.toStringAsFixed(present % 1 == 0 ? 0 : 1)} days,  Total Absent: ${absent.toStringAsFixed(absent % 1 == 0 ? 0 : 1)} days',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        );
          }),
      ),
    );
  }

  // Calendar builder that talks to StaffAttendanceProvider
  Widget _buildCalendarProvider(List<DateTime> days, String staffName, {Key? key, required double gridWidth, required double cellWidth, required double cellHeight, required double spacing}) {
    final prov = Provider.of<StaffAttendanceProvider>(context, listen: false);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday; // Mon=1
    final leading = (firstWeekday + 6) % 7;
    final lastDay = DateTime(_month.year, _month.month + 1, 0).day;
    final totalCells = leading + lastDay;
    final rows = (totalCells / 7).ceil();

    return Center(
      child: SizedBox(
        width: gridWidth,
        child: GridView.builder(
          key: key,
          physics: const BouncingScrollPhysics(),
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
        final split = prov.stateForSplit(staffName, date);
        final morning = split[0];
        final evening = split[1];
        final isFutureInCurrentMonth = _month.year == DateTime.now().year && _month.month == DateTime.now().month && date.isAfter(DateTime.now());
        final bgColorNone = isFutureInCurrentMonth ? const Color(0xFFE5E5E5) : Colors.grey.shade200;

            return Center(
              child: SizedBox(
                width: cellWidth, height: cellHeight,
                child: GestureDetector(
              onTap: () {
                prov.cycle(staffName, date);
                setState(() {});
              },
              child: Stack(alignment: Alignment.center, children: [
                HalfDayTile(morning: morning, evening: evening, width: cellWidth, height: cellHeight, size: cellHeight, radius: 12, presentColor: const Color(0xFF8B27E2), absentColor: const Color(0xFFD9B6FF), noneColor: bgColorNone),
                Text('$dayNum', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black87)),
              ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCalendar(List<DateTime> days, String staffId, {Key? key, required double gridWidth, required double cellWidth, required double cellHeight, required double spacing}) {
    // Compute leading blanks so that the first date lands on its weekday column (Mon=1..Sun=7)
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday; // Mon=1
    final leading = (firstWeekday + 6) % 7; // number of blanks before day 1, with Monday as first column
    final lastDay = DateTime(_month.year, _month.month + 1, 0).day;
    final totalCells = leading + lastDay;
    final rows = (totalCells / 7).ceil();

    return Center(
      child: SizedBox(
        width: gridWidth,
        child: GridView.builder(
          key: key,
          physics: const BouncingScrollPhysics(),
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
        if (dayNum < 1 || dayNum > lastDay) {
          return const SizedBox.shrink();
        }
        final date = DateTime(_month.year, _month.month, dayNum);
        final status = _store.status(staffId, date);
        // Map status to morning/evening booleans for HalfDayTile
        bool? morning, evening;
        switch (status) {
          case AttendanceStatus.present:
            morning = true; evening = true; break;
          case AttendanceStatus.absent:
            morning = false; evening = false; break;
          case AttendanceStatus.halfAfternoonOff: // morning present, afternoon absent
            morning = true; evening = false; break;
          case AttendanceStatus.halfMorningOff: // morning absent, afternoon present
            morning = false; evening = true; break;
          case AttendanceStatus.none:
            morning = null; evening = null; break;
        }

        final isFutureInCurrentMonth = _month.year == DateTime.now().year && _month.month == DateTime.now().month && date.isAfter(DateTime.now());
        final bgColorNone = isFutureInCurrentMonth ? const Color(0xFFE5E5E5) : Colors.grey.shade200;

            return Center(
              child: SizedBox(
                width: cellWidth, height: cellHeight,
                child: Stack(alignment: Alignment.center, children: [
              HalfDayTile(
                morning: morning,
                evening: evening,
                width: cellWidth,
                height: cellHeight,
                size: cellHeight,
                radius: 12,
                presentColor: const Color(0xFF8B27E2),
                absentColor: const Color(0xFFD9B6FF),
                noneColor: bgColorNone,
              ),
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
        Expanded(child: Container(decoration: BoxDecoration(color: const Color(0xFFD9B6FF), borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), bottomLeft: Radius.circular(3))))),
        Expanded(child: Container(decoration: BoxDecoration(color: const Color(0xFF8B27E2), borderRadius: const BorderRadius.only(topRight: Radius.circular(3), bottomRight: Radius.circular(3))))),
      ]),
    ),
    const SizedBox(width: 6),
    const Text('Half Day', style: TextStyle(fontSize: 12)),
  ]);
}

// Removed _Wd helper; headers are laid out with fixed-size boxes aligned to the grid
