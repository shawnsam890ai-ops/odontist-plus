import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/patient.dart';
import '../../models/treatment_session.dart';
import '../../core/enums.dart';
import '../../providers/patient_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../models/appointment.dart' as appt;
import '../pages/patient_detail_page.dart';

class _ApptEntry {
  _ApptEntry(this.patient, this.time, this.complaint, this.doctor, {this.apptId});
  final Patient patient;
  final DateTime time;
  final String? complaint;
  final String? doctor;
  final String? apptId;
}

/// Compact Upcoming Schedule widget for the dashboard Overview tile.
/// Independent from UpcomingSchedulePanel to avoid cross-contamination.
/// Shows a 4-day calendar strip and appointments for the selected day.
class UpcomingScheduleCompact extends StatefulWidget {
  final EdgeInsetsGeometry padding;

  const UpcomingScheduleCompact({
    super.key,
    this.padding = const EdgeInsets.all(0),
  });

  @override
  State<UpcomingScheduleCompact> createState() => _UpcomingScheduleCompactState();
}

class _UpcomingScheduleCompactState extends State<UpcomingScheduleCompact> {
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final patientProvider = context.watch<PatientProvider>();
    final apptProvider = context.watch<AppointmentProvider>();
    final dayKey = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final entries = <_ApptEntry>[];

    // Appointments provider entries
    for (final appt.Appointment a in apptProvider.forDay(dayKey)) {
      final p = patientProvider.byId(a.patientId);
      if (p != null) entries.add(_ApptEntry(p, a.dateTime, a.reason, a.doctorName, apptId: a.id));
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
          const SizedBox(height: 16),
          _fourDayStrip(),
          const SizedBox(height: 20),
          Expanded(child: _appointmentsList(entries)),
        ],
      ),
    );
  }

  Widget _monthHeader() {
    final m = _selectedDay;
    const monthsShort = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthLabel = '${monthsShort[m.month - 1]} ${m.year}';
    return LayoutBuilder(
      builder: (context, constraints) {
  final narrow = constraints.maxWidth < 380;
  final arrowSize = narrow ? 24.0 : 28.0;
        final maxW = constraints.maxWidth;
        return ClipRect(
          child: Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: maxW.isFinite ? (maxW - 1) : null,
              child: Row(
          children: [
            // Left: previous chevron
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  constraints: BoxConstraints.tightFor(width: arrowSize, height: arrowSize),
                  padding: EdgeInsets.zero,
                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  tooltip: 'Previous month',
                  onPressed: () => setState(() => _selectedDay = DateTime(m.year, m.month - 1, m.day)),
                  icon: const Icon(Icons.chevron_left, size: 18),
                ),
              ),
            ),
            // Center: month label
            Expanded(
              flex: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
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
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.0),
                  ),
                  child: Text(
                    monthLabel,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                  ),
                ),
              ),
            ),
            // Right: today + next chevron
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    constraints: BoxConstraints.tightFor(width: arrowSize, height: arrowSize),
                    padding: EdgeInsets.zero,
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                    tooltip: 'Today',
                    onPressed: () => setState(() => _selectedDay = DateTime.now()),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  ),
                  IconButton(
                    constraints: BoxConstraints.tightFor(width: arrowSize, height: arrowSize),
                    padding: EdgeInsets.zero,
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                    tooltip: 'Next month',
                    onPressed: () => setState(() => _selectedDay = DateTime(m.year, m.month + 1, m.day)),
                    icon: const Icon(Icons.chevron_right, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
            ),
          ),
        );
      },
    );
  }

  // Removed selected date chip for a cleaner layout, as requested.

  Widget _fourDayStrip() {
    final selected = _selectedDay;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final center = DateTime(selected.year, selected.month, selected.day);
    // For even counts (4), start one day before selected to include selected within range
    final start = center.subtract(const Duration(days: 1));
    final days = List.generate(4, (i) {
      final d = start.add(Duration(days: i));
      return DateTime(d.year, d.month, d.day);
    });

    return LayoutBuilder(
      builder: (context, constraints) {
  const stripH = 72.0; // increased for extra breathing room
  const arrowW = 18.0;
  const gap = 0.0; // reduce gaps to avoid overflow
  const count = 4;
  const minChip = 22.0;
    const maxChip = 48.0;
    const padL = 1.0;
  const padR = 1.0;
  const safeEpsilon = 2.0; // extra safety to avoid 1px overflow

        return Padding(
          padding: const EdgeInsets.only(right: 1.0),
          child: SizedBox(
          height: stripH,
          child: Row(children: [
            SizedBox(
              width: arrowW,
              child: IconButton(
                constraints: const BoxConstraints.tightFor(width: arrowW, height: 30),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_left, size: 14),
                onPressed: () => setState(() => _selectedDay = _selectedDay.subtract(const Duration(days: 4))),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: padL, right: padR),
                child: LayoutBuilder(
                  builder: (context, centerC) {
                    final centerW = centerC.maxWidth.isFinite ? centerC.maxWidth : 0.0;
                    double chipW = ((centerW - gap * (count - 1) - safeEpsilon) / count).floorToDouble();
                    chipW = chipW.clamp(minChip, maxChip);
                    // Extra guard: ensure the total content width never exceeds available width
                    final maxAllowed = centerW - safeEpsilon;
                    while ((chipW * count + gap * (count - 1)) > maxAllowed && chipW > minChip) {
                      chipW -= 1;
                    }
                    return ClipRect(
                      child: SizedBox(
                        width: (centerW - 1).clamp(0.0, centerW),
                        child: Row(children: [
                          for (int i = 0; i < days.length; i++) Expanded(
                            child: Center(child: _dayChip(days[i], selected, todayKey, chipW)),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(
              width: arrowW,
              child: IconButton(
                constraints: const BoxConstraints.tightFor(width: arrowW, height: 30),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_right, size: 14),
                onPressed: () => setState(() => _selectedDay = _selectedDay.add(const Duration(days: 4))),
              ),
            ),
          ]),
        ));
      },
    );
  }

  Widget _dayChip(DateTime d, DateTime selected, DateTime todayKey, [double width = 40]) {
    final isSel = _sameDay(d, selected);
    final isToday = _sameDay(d, todayKey);
    return GestureDetector(
      onTap: () => setState(() => _selectedDay = d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
        decoration: BoxDecoration(
          color: isSel ? Theme.of(context).colorScheme.primary.withOpacity(.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSel ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 0.8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _weekdayShort(d.weekday),
              style: TextStyle(
                fontSize: width <= 24 ? 9 : 11,
                fontWeight: FontWeight.w600,
                color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey[600],
              ),
            ),
            // Small line under the weekday
            Container(
              margin: EdgeInsets.only(top: width <= 24 ? 2 : 4, bottom: width <= 24 ? 2 : 4),
              height: 2,
              width: width * 0.5,
              decoration: BoxDecoration(
                color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Rounded rectangular box for the date number
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: width <= 24 ? 6 : 8,
                vertical: width <= 24 ? 2 : 4,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isToday
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade200,
                border: isSel
                    ? Border.all(color: Theme.of(context).colorScheme.primary, width: 0.8)
                    : null,
              ),
              child: Text(
                '${d.day}',
                style: TextStyle(
                  fontSize: width <= 24 ? 10 : 12,
                  fontWeight: FontWeight.w700,
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
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) => _appointmentCard(entries[i]),
    );
  }

  Widget _emptyBar() {
    return Center(
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 0),
        decoration: _barDecoration(),
        child: const Row(children: [
          SizedBox(width: 12),
          Text('No appointments', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      ),
    );
  }

  BoxDecoration _barDecoration({bool highlighted = false}) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: highlighted ? cs.primary : Theme.of(context).dividerColor.withOpacity(.3), width: 0.8),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(.02), blurRadius: 3, offset: const Offset(0, 1))
      ],
    );
  }

  Widget _appointmentCard(_ApptEntry e) {
    final hour = e.time.hour;
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    final time = '${hour12.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')} $period';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.02), blurRadius: 4, offset: const Offset(0, 1))
        ],
      ),
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          // Left: Time
          Flexible(
            flex: 2,
            fit: FlexFit.tight,
            child: Text(
              time,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
          const SizedBox(width: 6),
          // Middle: Complaint
          Flexible(
            flex: 4,
            fit: FlexFit.tight,
            child: Text(
              e.complaint ?? '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 6),
          // Right: Patient name (clickable) + actions (if provider-backed)
          Flexible(
            flex: 3,
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
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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

  // View-only mode: delete/reschedule actions are intentionally removed.

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

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  String _weekdayShort(int w) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[(w - 1) % 7];
  }
}
