import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/patient.dart';
import '../../models/treatment_session.dart';
import '../../providers/patient_provider.dart';

/// Compact Upcoming Schedule panel for the dashboard Overview.
/// Shows a selectable week strip and appointments (sessions or nextAppointments)
/// for the selected day.
class UpcomingSchedulePanel extends StatefulWidget {
  final EdgeInsetsGeometry padding;
  const UpcomingSchedulePanel({super.key, this.padding = const EdgeInsets.all(0)});

  @override
  State<UpcomingSchedulePanel> createState() => _UpcomingSchedulePanelState();
}

class _UpcomingSchedulePanelState extends State<UpcomingSchedulePanel> {
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final patientProvider = context.watch<PatientProvider>();
    final dayKey = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final entries = <_ApptEntry>[];
    for (final Patient p in patientProvider.patients) {
      for (final TreatmentSession s in p.sessions) {
        final sd = DateTime(s.date.year, s.date.month, s.date.day);
        if (sd == dayKey) {
          entries.add(_ApptEntry(p, s.date, s.chiefComplaint?.complaints.isNotEmpty == true ? s.chiefComplaint!.complaints.first : null));
        }
        if (s.nextAppointment != null) {
          final na = s.nextAppointment!;
          final nd = DateTime(na.year, na.month, na.day);
          if (nd == dayKey) {
            entries.add(_ApptEntry(p, na, s.chiefComplaint?.complaints.isNotEmpty == true ? s.chiefComplaint!.complaints.first : null));
          }
        }
      }
    }
    entries.sort((a,b)=> a.time.compareTo(b.time));

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(),
          const SizedBox(height: 8),
          _weekStrip(),
          const SizedBox(height: 8),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No appointments'))
                : ListView.builder(
                    itemCount: entries.length,
                    padding: const EdgeInsets.only(top: 4),
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      final now = DateTime.now();
                      final isNow = now.difference(e.time).inMinutes.abs() <= 30 && _sameDay(now, e.time);
                      return _appointmentTile(e, isNow: isNow);
                    },
                  ),
          )
        ],
      ),
    );
  }

  Widget _headerRow() {
    final m = _selectedDay;
    const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    final monthLabel = '${months[m.month-1]} ${m.year}';
    return LayoutBuilder(builder: (context, c) {
      final tight = c.maxWidth < 300;
      final title = Flexible(
        child: Text('Upcoming Schedule',
            maxLines: 1,
            overflow: TextOverflow.visible, // Show full title
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
      final monthText = Text(monthLabel,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey));
      final todayBtn = TextButton(
        onPressed: () => setState(() => _selectedDay = DateTime.now()),
        child: const Text('Today'),
      );
      if (tight) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Row(children: [title, const SizedBox(width: 8), todayBtn]), monthText],
        );
      }
      return Row(children: [
        title,
        const Spacer(),
        monthText,
        const SizedBox(width: 6),
        todayBtn,
      ]);
    });
  }

  Widget _weekStrip(){
    final selected = _selectedDay;
    final weekday = selected.weekday; // 1=Mon..7=Sun
    final sunday = selected.subtract(Duration(days: (weekday)%7));
    final days = List.generate(7, (i){ final d = sunday.add(Duration(days: i)); return DateTime(d.year,d.month,d.day); });
    final today = DateTime.now();
    return SizedBox(
      height: 68,
      child: Row(children: [
        IconButton(icon: const Icon(Icons.chevron_left,size:20), onPressed: ()=> setState(()=> _selectedDay = _selectedDay.subtract(const Duration(days:7)) )),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal:4),
            itemBuilder: (_, i){
              final d = days[i];
              final isSel = _sameDay(d, selected);
              final isToday = _sameDay(d, today);
              return GestureDetector(
                onTap: ()=> setState(()=> _selectedDay = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 48,
                  margin: const EdgeInsets.symmetric(vertical:6),
                  decoration: BoxDecoration(
                    color: isSel ? Theme.of(context).colorScheme.primary.withOpacity(.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSel ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 1.2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_weekdayShort(d.weekday), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey[600])),
                      const SizedBox(height:4),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isToday ? Theme.of(context).colorScheme.primary : (isSel ? Theme.of(context).colorScheme.primary.withOpacity(.15) : Colors.grey.shade200),
                        ),
                        child: Text('${d.day}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isToday ? Colors.white : (isSel ? Theme.of(context).colorScheme.primary : Colors.black87))),
                      )
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width:6),
            itemCount: days.length,
          ),
        ),
        IconButton(icon: const Icon(Icons.chevron_right,size:20), onPressed: ()=> setState(()=> _selectedDay = _selectedDay.add(const Duration(days:7)) )),
      ]),
    );
  }

  Widget _appointmentTile(_ApptEntry e, {required bool isNow}) {
    final time = '${e.time.hour.toString().padLeft(2,'0')}:${e.time.minute.toString().padLeft(2,'0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isNow ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor.withOpacity(.3), width: 1.1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 4, offset: const Offset(0,2))],
        ),
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12,10,10,10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal:8, vertical:4),
                decoration: BoxDecoration(
                  color: isNow ? Theme.of(context).colorScheme.primary : Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(time, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isNow ? Colors.white : Colors.black87)),
              ),
              if (e.complaint != null && e.complaint!.isNotEmpty) ...[
                const SizedBox(height: 6),
                SizedBox(width: 70, child: Text(e.complaint!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey)))
              ]
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right:12),
              child: Text(e.patient.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          )
        ]),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year==b.year && a.month==b.month && a.day==b.day;
  String _weekdayShort(int w){ const labels=['Mon','Tue','Wed','Thu','Fri','Sat','Sun']; return labels[(w-1)%7]; }
}

class _ApptEntry { _ApptEntry(this.patient, this.time, this.complaint); final Patient patient; final DateTime time; final String? complaint; }
