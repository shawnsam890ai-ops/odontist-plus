import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/patient.dart';
import '../../models/treatment_session.dart';
import '../../core/enums.dart';
import '../../providers/patient_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../models/appointment.dart' as appt;
import '../pages/patient_detail_page.dart';

class _StatusItem {
  final String label;
  final appt.AppointmentStatus? value;
  const _StatusItem(this.label, this.value);
}

class _ApptEntry {
  _ApptEntry(this.patient, this.time, this.complaint, this.doctor, {this.apptId, this.status});
  final Patient patient;
  final DateTime time;
  final String? complaint;
  final String? doctor;
  final String? apptId; // present only for provider-backed appointments
  final appt.AppointmentStatus? status;
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
  // Status filter: null -> All
  appt.AppointmentStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final patientProvider = context.watch<PatientProvider>();
    final apptProvider = context.watch<AppointmentProvider>();
    final dayKey = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final entries = <_ApptEntry>[];
    // Appointments provider entries
    var apptsForDay = apptProvider.forDay(dayKey);
    if (_statusFilter != null) {
      apptsForDay = apptsForDay.where((a) => a.status == _statusFilter).toList();
    }
    for (final appt.Appointment a in apptsForDay) {
      if (_doctorId != null && a.doctorId != _doctorId) continue;
      final p = patientProvider.byId(a.patientId);
      if (p != null) entries.add(_ApptEntry(p, a.dateTime, a.reason, a.doctorName, apptId: a.id, status: a.status));
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
            final purpose = _purposeForNextAppointment(s) ??
                (s.chiefComplaint?.complaints.isNotEmpty == true ? s.chiefComplaint!.complaints.first : null);
            entries.add(_ApptEntry(p, na, purpose, null));
          }
        }
      }
    }
    entries.sort((a, b) => a.time.compareTo(b.time));

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _monthHeader(),
          const SizedBox(height: 4),
          if (widget.showDoctorFilter) _doctorFilterRow(),
          if (widget.showDoctorFilter) const SizedBox(height: 4),
          _sevenDayStrip(),
          const SizedBox(height: 8),
          _statusFilters(),
          const SizedBox(height: 8),
          if (widget.showTitle)
            Text('Upcoming Schedule', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          if (widget.showTitle) const SizedBox(height: 6),
          const Divider(height: 0.5),
          const SizedBox(height: 8),
          Expanded(child: _appointmentsList(entries)),
        ],
      ),
    );
  }

      Widget _statusFilters() {
        final List<_StatusItem> items = [
          _StatusItem('All', null),
          _StatusItem('Scheduled', appt.AppointmentStatus.scheduled),
          _StatusItem('Attended', appt.AppointmentStatus.attended),
          _StatusItem('Missed', appt.AppointmentStatus.missed),
        ];
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final it in items) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(it.label),
                  selected: _statusFilter == it.value,
                  onSelected: (_) => setState(() => _statusFilter = it.value),
                ),
              ),
            ],
          ]),
        );
      }

      

      Widget _monthHeader() {
        final m = _selectedDay;
        const months = [
          'January','February','March','April','May','June','July','August','September','October','November','December'
        ];
        final monthLabel = '${months[m.month - 1]} ${m.year}';
        return LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth.isFinite && constraints.maxWidth < 380;
            final arrowSize = narrow ? 32.0 : 36.0;
            return Row(
              children: [
                // Left area: previous chevron
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      constraints: BoxConstraints.tightFor(width: arrowSize, height: arrowSize),
                      padding: EdgeInsets.zero,
                      tooltip: 'Previous month',
                      onPressed: () => setState(() => _selectedDay = DateTime(m.year, m.month - 1, m.day)),
                      icon: const Icon(Icons.chevron_left, size: 20),
                    ),
                  ),
                ),
                // Center area: month label (true centered)
                Expanded(
                  flex: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDay,
                        firstDate: DateTime(now.year - 3),
                        lastDate: DateTime(now.year + 3),
                      );
                      if (picked != null) setState(() => _selectedDay = picked);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        monthLabel,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                // Right area: Today (icon on narrow) + next chevron
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (narrow)
                        IconButton(
                          constraints: BoxConstraints.tightFor(width: arrowSize, height: arrowSize),
                          padding: EdgeInsets.zero,
                          tooltip: 'Today',
                          onPressed: () => setState(() => _selectedDay = DateTime.now()),
                          icon: const Icon(Icons.calendar_today_outlined, size: 18),
                        )
                      else
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => setState(() => _selectedDay = DateTime.now()),
                          child: const Text('Today', overflow: TextOverflow.ellipsis),
                        ),
                      IconButton(
                        constraints: BoxConstraints.tightFor(width: arrowSize, height: arrowSize),
                        padding: EdgeInsets.zero,
                        tooltip: 'Next month',
                        onPressed: () => setState(() => _selectedDay = DateTime(m.year, m.month + 1, m.day)),
                        icon: const Icon(Icons.chevron_right, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      }

      String? _purposeForNextAppointment(TreatmentSession s) {
        switch (s.type) {
          case TreatmentType.orthodontic:
            return 'Ortho Treatment';
          case TreatmentType.rootCanal:
            return _planSummary(s.rootCanalPlans);
          case TreatmentType.prosthodontic:
            return _planSummary(s.prosthodonticPlans);
          case TreatmentType.general:
          case TreatmentType.labWork:
            return null;
        }
      }

      String? _planSummary(List<ToothPlanEntry> plans) {
        if (plans.isEmpty) return null;
        final parts = <String>[];
        for (final e in plans.take(2)) {
          final tooth = (e.toothNumber.isNotEmpty) ? '${e.toothNumber}: ' : '';
          parts.add('$tooth${e.plan}');
        }
        var s = parts.join(', ');
        if (plans.length > 2) s += ' …';
        return s;
      }

      Widget _doctorFilterRow() {
        final doctorProvider = context.read<DoctorProvider>();
        return Row(children: [
          const Spacer(),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String?>(
              value: _doctorId,
              decoration: const InputDecoration(labelText: 'Doctor'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All doctors')),
                for (final d in doctorProvider.doctors)
                  DropdownMenuItem<String?>(value: d.id, child: Text(d.name)),
              ],
              onChanged: (v) => setState(() => _doctorId = v),
            ),
          ),
        ]);
      }

      Widget _sevenDayStrip() {
        final selected = _selectedDay;
        final today = DateTime.now();
        final todayKey = DateTime(today.year, today.month, today.day);
        final center = DateTime(selected.year, selected.month, selected.day);
        // Show 5-day window centered on selected day
        final start = center.subtract(const Duration(days: 2));
        final days = List.generate(5, (i) {
          final d = start.add(Duration(days: i));
          return DateTime(d.year, d.month, d.day);
        });
        return LayoutBuilder(
          builder: (context, constraints) {
            // Adaptive sizing to avoid overflow on narrow tiles
            const count = 5;
            final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
            // More aggressive compacting for narrow widths
            final narrow = maxW < 420;
            final arrowW = narrow ? 20.0 : 28.0;
            final gap = narrow ? 2.0 : 5.0;
            final minChip = 24.0;
            final maxChip = 44.0;
            // Aggressive safety margin to avoid right-edge overflow
            const extraMargin = 32.0;
            final avail = maxW - (arrowW * 2) - extraMargin;
            double chipW = (avail - gap * (count - 1)) / count;
            // If calculation yields too-large chips (due to negative avail), clamp down
            if (chipW.isNaN || chipW.isInfinite) chipW = minChip;
            chipW = chipW.clamp(minChip, maxChip);
            final stripH = narrow ? 48.0 : 56.0;
            return SizedBox(
              height: stripH,
              child: Row(children: [
                SizedBox(
                  width: arrowW,
                  child: IconButton(
                    constraints: BoxConstraints.tightFor(width: arrowW, height: 36),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: () => setState(() => _selectedDay = _selectedDay.subtract(const Duration(days: 5))),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < days.length; i++) ...[
                            _dayChip(days[i], selected, todayKey, chipW),
                            if (i != days.length - 1) SizedBox(width: gap),
                          ]
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: arrowW,
                  child: IconButton(
                    constraints: BoxConstraints.tightFor(width: arrowW, height: 36),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: () => setState(() => _selectedDay = _selectedDay.add(const Duration(days: 5))),
                  ),
                ),
              ]),
            );
          },
        );
      }

      Widget _dayChip(DateTime d, DateTime selected, DateTime todayKey, [double width = 56]) {
        final isSel = _sameDay(d, selected);
        final isToday = _sameDay(d, todayKey);
        final compact = width <= 40;
        return GestureDetector(
          onTap: () => setState(() => _selectedDay = d),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: width,
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
            decoration: BoxDecoration(
              color: isSel ? Theme.of(context).colorScheme.primary.withOpacity(.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSel ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 1.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _weekdayShort(d.weekday),
                  style: TextStyle(
                    fontSize: compact ? 9 : 10,
                    fontWeight: FontWeight.w600,
                    color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey[600],
                  ),
                ),
                SizedBox(height: compact ? 2 : 3),
                Container(
                  padding: EdgeInsets.all(compact ? 5 : 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday
                        ? Theme.of(context).colorScheme.primary
                        : (isSel ? Theme.of(context).colorScheme.primary.withOpacity(.15) : Colors.grey.shade200),
                  ),
                  child: Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.w600,
                      color: isToday ? Colors.white : (isSel ? Theme.of(context).colorScheme.primary : Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      Widget _appointmentsList(List<_ApptEntry> entries) {
        if (entries.isEmpty) return _emptyBar();
        return ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _appointmentCard(entries[i]),
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
          border: Border.all(color: highlighted ? cs.primary : Theme.of(context).dividerColor.withOpacity(.3), width: 1.1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 4, offset: const Offset(0, 2))
          ],
        );
      }

      Widget _appointmentCard(_ApptEntry e) {
        // 12-hr format
        final hour = e.time.hour;
        final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final period = hour >= 12 ? 'PM' : 'AM';
        final time = '${hour12.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')} $period';
        final isAttended = e.status == appt.AppointmentStatus.attended;
        final isMissed = e.status == appt.AppointmentStatus.missed;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.25)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 6, offset: const Offset(0, 2))
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Left: Time and doctor in brackets (flexible, no fixed width)
              Flexible(
                flex: 3,
                fit: FlexFit.tight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      time,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    if (e.doctor != null && e.doctor!.trim().isNotEmpty)
                      Text(
                        '(${e.doctor})',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    if (isAttended || isMissed)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAttended ? Colors.green.withOpacity(.12) : Colors.red.withOpacity(.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: (isAttended ? Colors.green : Colors.red).withOpacity(.4)),
                            ),
                            child: Text(
                              isAttended ? 'Attended' : 'Missed',
                              style: TextStyle(fontSize: 11, color: isAttended ? Colors.green[800] : Colors.red[700], fontWeight: FontWeight.w600),
                            ),
                          ),
                        ]),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Middle: Reason / complaint
              Flexible(
                flex: 5,
                fit: FlexFit.tight,
                child: Text(
                  e.complaint ?? '-',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              // Right: Patient name (clickable) and actions for provider appointments
              Flexible(
                flex: 6,
                fit: FlexFit.tight,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pushNamed(
                          PatientDetailPage.routeName,
                          arguments: {'patientId': e.patient.id},
                        ),
                        child: Text(
                          e.patient.name,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                      if (e.apptId != null) ...[
                        const SizedBox(width: 8),
                        _apptActions(e),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }

      Widget _apptActions(_ApptEntry e) {
        final appts = context.read<AppointmentProvider>();
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Tooltip(
            message: 'Mark attended',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: () => appts.markAttended(e.apptId!),
              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
            ),
          ),
          Tooltip(
            message: 'Mark missed',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: () => appts.markMissed(e.apptId!),
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
            ),
          ),
          Tooltip(
            message: 'Reschedule',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: () => _rescheduleAppt(e.apptId!, e.time),
              icon: const Icon(Icons.schedule, color: Colors.blueGrey),
            ),
          ),
          Tooltip(
            message: 'Delete appointment',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: () => _confirmDeleteAppt(e.apptId!),
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
            ),
          ),
        ]);
      }

      Future<void> _rescheduleAppt(String apptId, DateTime current) async {
        DateTime? date = current;
        TimeOfDay? time = TimeOfDay(hour: current.hour, minute: current.minute);
        final now = DateTime.now();
        final pickedDate = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 2));
        if (pickedDate == null) return;
  final pickedTime = await showTimePicker(context: context, initialTime: time);
        if (pickedTime == null) return;
        final dt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        context.read<AppointmentProvider>().reschedule(apptId, dt);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment rescheduled')));
        }
      }

      Future<void> _confirmDeleteAppt(String apptId) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete appointment?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
            ],
          ),
        );
        if (ok == true) {
          context.read<AppointmentProvider>().remove(apptId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment deleted')));
          }
        }
      }

      bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
      String _weekdayShort(int w) {
        const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return labels[(w - 1) % 7];
      }
  }
