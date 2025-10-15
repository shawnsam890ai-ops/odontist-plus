import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/patient.dart';
import '../../models/treatment_session.dart';
import '../../providers/patient_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../models/appointment.dart' as appt;

class _ApptEntry {
  _ApptEntry(this.patient, this.time, this.complaint, this.doctor);
  final Patient patient;
  final DateTime time;
  final String? complaint;
  final String? doctor;
}

/// Compact Upcoming Schedule panel for the dashboard Overview.
/// Shows a selectable week strip and appointments (sessions or nextAppointments)
/// for the selected day.
class UpcomingSchedulePanel extends StatefulWidget {
  final EdgeInsetsGeometry padding;
  final bool showDoctorFilter;
  final bool showTitle;
  const UpcomingSchedulePanel({super.key, this.padding = const EdgeInsets.all(0), this.showDoctorFilter = false, this.showTitle = true});

  @override
  State<UpcomingSchedulePanel> createState() => _UpcomingSchedulePanelState();
}

class _UpcomingSchedulePanelState extends State<UpcomingSchedulePanel> {
  DateTime _selectedDay = DateTime.now();
  String? _doctorId;
  int _appointmentIndex = 0; // Track which appointment is currently displayed

  @override
  Widget build(BuildContext context) {
    final patientProvider = context.watch<PatientProvider>();
    final apptProvider = context.watch<AppointmentProvider>();
    final dayKey = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final entries = <_ApptEntry>[];
    // Appointments provider entries
    for (final appt.Appointment a in apptProvider.forDay(dayKey)) {
      if (_doctorId != null && a.doctorId != _doctorId) continue;
      final p = patientProvider.byId(a.patientId);
      if (p != null) entries.add(_ApptEntry(p, a.dateTime, a.reason, a.doctorName));
    }
    // Sessions and next appointments
    for (final Patient p in patientProvider.patients) {
      for (final TreatmentSession s in p.sessions) {
        final sd = DateTime(s.date.year, s.date.month, s.date.day);
        if (sd == dayKey) {
          entries.add(_ApptEntry(p, s.date, s.chiefComplaint?.complaints.isNotEmpty == true ? s.chiefComplaint!.complaints.first : null, null));
        }
        if (s.nextAppointment != null) {
          final na = s.nextAppointment!;
          final nd = DateTime(na.year, na.month, na.day);
          if (nd == dayKey) {
            entries.add(_ApptEntry(p, na, s.chiefComplaint?.complaints.isNotEmpty == true ? s.chiefComplaint!.complaints.first : null, null));
          }
        }
      }
    }
    entries.sort((a, b) => a.time.compareTo(b.time));

    return Padding(
      padding: widget.padding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
              widthFactor: 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _monthYearRow(),
              const SizedBox(height: 8),
              // Header now only shows the doctor filter (if enabled). Title is moved below the dates strip.
              if (widget.showDoctorFilter) _headerRow(),
              if (widget.showDoctorFilter) const SizedBox(height: 6),
              _sixDayStrip(),
              const SizedBox(height: 12),
              // Moved title: show after dates panel
              if (widget.showTitle)
                Text('Upcoming Schedule', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              if (widget.showTitle) const SizedBox(height: 8),
              // Divider separating the dates section and the next-appointments section
              const Divider(height: 1),
              const SizedBox(height: 12),
              Expanded(child: _appointmentsNavigator(entries)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthYearRow(){
    final m = _selectedDay;
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final monthLabel = '${months[m.month - 1]} ${m.year}';
    return Row(children: [
      Expanded(
        child: Text(
          monthLabel,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      TextButton(
        onPressed: () => setState(() => _selectedDay = DateTime.now()),
        child: const Text('Today'),
      ),
    ]);
  }

  Widget _headerRow() {
    // Header row only contains the doctor filter aligned to the right.
    final doctor = _filterRow(context.read<DoctorProvider>());
    return Row(
      children: [
        const Spacer(),
        if (widget.showDoctorFilter) Flexible(child: doctor),
      ],
    );
  }

  Widget _filterRow(DoctorProvider doctorProvider) {
    if (!widget.showDoctorFilter) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        const Text('Doctor:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String?>(
            value: _doctorId,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All')),
              for (final d in doctorProvider.doctors)
                DropdownMenuItem<String?>(value: d.id, child: Text(d.name)),
            ],
            onChanged: (v) => setState(() => _doctorId = v),
          ),
        ),
      ]),
    );
  }

  // First container: 6-date strip
  Widget _sixDayStrip() {
    final selected = _selectedDay;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    
    // Calculate start date: center today's date in the strip
    // Show 3 days before today and 2 days after (today in center)
    final start = todayKey.subtract(const Duration(days: 3));
    
    final days = List.generate(6, (i) {
      final d = start.add(Duration(days: i));
      return DateTime(d.year, d.month, d.day);
    });
    
    return SizedBox(
      height: 68,
      child: Row(children: [
        IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: () =>
                setState(() => _selectedDay = _selectedDay.subtract(const Duration(days: 6)))),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemBuilder: (_, i) {
              final d = days[i];
              final isSel = _sameDay(d, selected);
              final isToday = _sameDay(d, todayKey);
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedDay = d;
                  _appointmentIndex = 0; // Reset to first appointment when changing day
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                      width: 56,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isSel
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 1.1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_weekdayShort(d.weekday),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSel
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[600])),
                      const SizedBox(height: 4),
                      Container(
                            padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              : (isSel
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(.15)
                                  : Colors.grey.shade200),
                        ),
                        child: Text('${d.day}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isToday
                                    ? Colors.white
                                    : (isSel
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                        : Colors.black87))),
                      )
                    ],
                  ),
                ),
              );
            },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: days.length,
          ),
        ),
        IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: () =>
                setState(() => _selectedDay = _selectedDay.add(const Duration(days: 6)))),
      ]),
    );
  }

  // Appointment navigator with left/right buttons
  Widget _appointmentsNavigator(List<_ApptEntry> entries) {
    if (entries.isEmpty) return _emptyBar();
    
    // Ensure index is within bounds
    if (_appointmentIndex >= entries.length) {
      _appointmentIndex = 0;
    }
    
    final currentEntry = entries[_appointmentIndex];
    final isNow = _sameDay(DateTime.now(), currentEntry.time) &&
        DateTime.now().difference(currentEntry.time).inMinutes.abs() <= 30;
    
    return Row(
      children: [
        // Left navigation button - compact
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 20),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          onPressed: _appointmentIndex > 0
              ? () => setState(() => _appointmentIndex--)
              : null,
          tooltip: 'Previous appointment',
        ),
        // Current appointment card - maximized width
        Expanded(
          child: _barTile(currentEntry, isNow: isNow),
        ),
        // Right navigation button - compact
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 20),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          onPressed: _appointmentIndex < entries.length - 1
              ? () => setState(() => _appointmentIndex++)
              : null,
          tooltip: 'Next appointment',
        ),
      ],
    );
  }

  Widget _emptyBar() {
    return Center(
      child: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 0),
        decoration: _barDecoration(),
        child: Row(children: const [
          SizedBox(width: 12),
          Text('No appointments', style: TextStyle(color: Colors.grey)),
        ]),
      ),
    );
  }

  BoxDecoration _barDecoration({bool highlighted = false}) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
          color: highlighted
              ? cs.primary
              : Theme.of(context).dividerColor.withOpacity(.3),
          width: 1.1),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 4,
            offset: const Offset(0, 2))
      ],
    );
  }

  Widget _barTile(_ApptEntry e, {required bool isNow}) {
    final cs = Theme.of(context).colorScheme;
    // Convert to 12-hour format
    final hour = e.time.hour;
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    final time = '${hour12.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')} $period';
    
    return Container(
      height: 66,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: _barDecoration(highlighted: isNow),
      child: Row(children: [
        // Time chip on left
        const SizedBox(width: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
              color: isNow ? cs.primary : Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(8)),
          child: Text(time,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isNow ? Colors.white : Colors.black87)),
        ),
        const Spacer(),
        // Patient name with doctor name below in brackets (extreme right)
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(e.patient.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (e.doctor != null)
              Text('(${e.doctor!})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        const SizedBox(width: 4),
      ]),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  String _weekdayShort(int w) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[(w - 1) % 7];
  }
}
 
