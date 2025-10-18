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
          const SizedBox(height: 8),
          if (widget.showDoctorFilter) _doctorFilterRow(),
          if (widget.showDoctorFilter) const SizedBox(height: 6),
          _sevenDayStrip(),
          const SizedBox(height: 12),
          if (widget.showTitle)
            Text('Upcoming Schedule', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          if (widget.showTitle) const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Expanded(child: _appointmentsList(entries)),
        ],
      ),
    );
  }

      Widget _monthHeader() {
        final m = _selectedDay;
        const months = [
          'January','February','March','April','May','June','July','August','September','October','November','December'
        ];
        final monthLabel = '${months[m.month - 1]} ${m.year}';
        return Row(children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => setState(() => _selectedDay = DateTime(m.year, m.month - 1, m.day)),
            icon: const Icon(Icons.chevron_left, size: 20),
          ),
          Expanded(
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
          IconButton(
            tooltip: 'Next month',
            onPressed: () => setState(() => _selectedDay = DateTime(m.year, m.month + 1, m.day)),
            icon: const Icon(Icons.chevron_right, size: 20),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: TextButton(
              onPressed: () => setState(() => _selectedDay = DateTime.now()),
              child: const Text('Today', overflow: TextOverflow.ellipsis),
            ),
          ),
        ]);
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
        final start = center.subtract(const Duration(days: 3));
        final days = List.generate(7, (i) {
          final d = start.add(Duration(days: i));
          return DateTime(d.year, d.month, d.day);
        });
        return SizedBox(
          height: 68,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () => setState(() => _selectedDay = _selectedDay.subtract(const Duration(days: 7))),
            ),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemBuilder: (_, i) {
                  final d = days[i];
                  final isSel = _sameDay(d, selected);
                  final isToday = _sameDay(d, todayKey);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDay = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 56,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? Theme.of(context).colorScheme.primary.withOpacity(.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isSel ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 1.1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_weekdayShort(d.weekday),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey[600])),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isToday
                                  ? Theme.of(context).colorScheme.primary
                                  : (isSel ? Theme.of(context).colorScheme.primary.withOpacity(.15) : Colors.grey.shade200),
                            ),
                            child: Text('${d.day}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isToday ? Colors.white : (isSel ? Theme.of(context).colorScheme.primary : Colors.black87),
                                )),
                          ),
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
              onPressed: () => setState(() => _selectedDay = _selectedDay.add(const Duration(days: 7))),
            ),
          ]),
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
              // Right: Patient name (clickable to open patient detail)
              Flexible(
                flex: 5,
                fit: FlexFit.tight,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
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
                ),
              ),
            ],
          ),
        );
      }

      bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
      String _weekdayShort(int w) {
        const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return labels[(w - 1) % 7];
      }
  }
