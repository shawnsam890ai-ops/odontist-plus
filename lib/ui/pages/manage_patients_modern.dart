import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../providers/patient_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../models/patient.dart';
import '../../models/appointment.dart';
import '../pages/add_patient_page.dart';
import '../pages/patient_detail_page.dart';

class ManagePatientsModern extends StatelessWidget {
  const ManagePatientsModern({Key? key}) : super(key: key);

  static const routeName = '/manage-patients-modern';

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: ManagePatientsModernBody(),
    );
  }
}

class ManagePatientsModernBody extends StatefulWidget {
  const ManagePatientsModernBody({Key? key, this.embedded = false}) : super(key: key);
  final bool embedded;

  @override
  State<ManagePatientsModernBody> createState() => _ManagePatientsModernBodyState();
}

class _ManagePatientsModernBodyState extends State<ManagePatientsModernBody> {
  final Color _bg = const Color(0xFFF5F7FA);
  final Color _primary = const Color(0xFF28A745);
  final Color _text = const Color(0xFF333333);
  final Color _secondary = const Color(0xFF757575);
  final Color _border = const Color(0xFFEEEEEE);

  final TextEditingController _searchCtrl = TextEditingController();
  bool _filterActive = false;
  CalendarFormat _calFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  String? _doctorId;

  @override
  void initState() {
    super.initState();
    // Ensure data is loaded if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatientProvider>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patients = context.watch<PatientProvider>().patients;
    final doctorProvider = context.watch<DoctorProvider>();
    final apptProvider = context.watch<AppointmentProvider>();

    final filteredPatients = patients.where((p) {
      final matchesSearch = _searchCtrl.text.trim().isEmpty ||
          p.name.toLowerCase().contains(_searchCtrl.text.trim().toLowerCase()) ||
          p.displayNumber.toString().contains(_searchCtrl.text.trim());
      final isActive = p.sessions.isNotEmpty; // heuristic for demo
      return matchesSearch && (!_filterActive || isActive);
    }).toList();

    final day = _selectedDay ?? DateTime.now();
    final todays = apptProvider.forDay(day)..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final dayLabel = DateFormat('MMM d').format(day);

    final content = Padding(
      padding: EdgeInsets.all(widget.embedded ? 0 : 24.0),
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildStatsCard(context, patients.length, patients.where((p) => p.sessions.isNotEmpty).length),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _buildPatientDirectory(filteredPatients)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildScheduleSection(context, doctorProvider, todays, dayLabel)),
              ],
            ),
          )
        ],
      ),
    );

    if (widget.embedded) {
      // When embedded inside Dashboard, avoid additional SafeArea/background.
      return content;
    }
    return SafeArea(child: Container(color: _bg, child: content));
  }

  // Header ---------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Text('Manage Patients', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _text)),
        const Spacer(),
        IconButton(onPressed: () {}, icon: Icon(Icons.notifications_none, color: _secondary)),
        const SizedBox(width: 8),
        CircleAvatar(radius: 16, backgroundColor: Colors.white, child: Icon(Icons.person, size: 18, color: _secondary)),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.of(context).pushNamed(AddPatientPage.routeName),
          icon: const Icon(Icons.add),
          label: const Text('Add New Patient'),
        ),
      ],
    );
  }

  // Stats ----------------------------------------------------
  Widget _buildStatsCard(BuildContext context, int total, int active) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(child: _statTile('Total Patients', total.toString())),
          VerticalDivider(width: 1, color: _border, thickness: 1, indent: 6, endIndent: 6),
          Expanded(child: _statTile('Active Patients', active.toString())),
        ]),
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: _secondary)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _text)),
      ]),
    );
  }

  // Left column ----------------------------------------------
  Widget _buildPatientDirectory(List<Patient> patients) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Search
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search patients…',
              hintStyle: TextStyle(color: _secondary),
              prefixIcon: Icon(Icons.search, color: _secondary),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: _primary)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // Filters
          Row(children: [
            FilterChip(
              label: Text('All Patients', style: TextStyle(color: !_filterActive ? Colors.white : _secondary)),
              selected: !_filterActive,
              onSelected: (v) => setState(() => _filterActive = false),
              selectedColor: _primary,
              checkmarkColor: Colors.white,
              backgroundColor: Colors.white,
              side: BorderSide(color: _border),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text('Active', style: TextStyle(color: _filterActive ? Colors.white : _secondary)),
              selected: _filterActive,
              onSelected: (v) => setState(() => _filterActive = true),
              selectedColor: _primary,
              checkmarkColor: Colors.white,
              backgroundColor: Colors.white,
              side: BorderSide(color: _border),
            ),
            const Spacer(),
            Text('${patients.length} results', style: TextStyle(color: _secondary)),
          ]),
          const SizedBox(height: 12),
          // List
          Expanded(
            child: patients.isEmpty
                ? const Center(child: Text('No patients'))
                : ListView.separated(
                    itemCount: patients.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: _border),
                    itemBuilder: (_, i) => _buildPatientCard(patients[i]),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _buildPatientCard(Patient p) {
    final active = p.sessions.isNotEmpty;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      leading: CircleAvatar(backgroundColor: _primary.withOpacity(0.12), child: Icon(Icons.person, color: _secondary)),
      title: Text(p.name, style: TextStyle(fontWeight: FontWeight.w700, color: _text)),
      subtitle: Text('MRN: ${p.displayNumber.toString().padLeft(4, '0')} • Next Appt: ${_nextApptLabel(p)}', style: TextStyle(color: _secondary)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: active ? Colors.green : Colors.grey, shape: BoxShape.circle)),
        IconButton(icon: Icon(Icons.more_vert, color: _secondary), onPressed: () {}),
      ]),
      onTap: () => Navigator.of(context).pushNamed(PatientDetailPage.routeName, arguments: {'patientId': p.id}),
    );
  }

  String _nextApptLabel(Patient p) {
    // Placeholder: In absence of persistent appointments per patient, show last session or '-'
    if (p.sessions.isEmpty) return '-';
    final latest = p.sessions.map((s) => s.date).reduce((a, b) => a.isAfter(b) ? a : b);
    return DateFormat('MMM d, h:mm a').format(latest);
  }

  // Right column ---------------------------------------------
  Widget _buildScheduleSection(BuildContext context, DoctorProvider doctorProvider, List<Appointment> todays, String dayLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Doctor filter
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.black.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(children: [
              Text('Doctor:', style: TextStyle(color: _text)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _doctorId,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(borderSide: BorderSide.none),
                    prefixIconColor: _secondary,
                    labelStyle: TextStyle(color: _secondary),
                  ),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text('All', style: TextStyle(color: _secondary))),
                    for (final d in doctorProvider.doctors) DropdownMenuItem<String?>(value: d.id, child: Text(d.name, style: TextStyle(color: _text))),
                  ],
                  onChanged: (v) => setState(() => _doctorId = v),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // Calendar
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.black.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TableCalendar(
                firstDay: DateTime.utc(2020,1,1),
                lastDay: DateTime.utc(2035,12,31),
                focusedDay: _focusedDay,
                calendarFormat: _calFormat,
                selectedDayPredicate: (d) => _selectedDay != null && isSameDay(d, _selectedDay),
                onDaySelected: (selected, focused) => setState(() { _selectedDay = selected; _focusedDay = focused; }),
                onFormatChanged: (fmt) => setState(() => _calFormat = fmt),
                headerStyle: HeaderStyle(formatButtonVisible: true, titleCentered: true, titleTextStyle: TextStyle(color: _text)),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(color: _primary.withOpacity(.15), shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: _primary, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: Text('Today', style: TextStyle(color: _primary, fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            color: Colors.white,
            surfaceTintColor: Colors.white,
            shadowColor: Colors.black.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Appointments for $dayLabel', style: TextStyle(fontWeight: FontWeight.w700, color: _text)),
                const SizedBox(height: 8),
                Expanded(
                  child: todays.isEmpty
                      ? const Center(child: Text('No appointments'))
                      : ListView.separated(
                          itemCount: todays.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8),
                          itemBuilder: (_, i) => _buildAppointmentCard(context, todays[i]),
                        ),
                )
              ]),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildAppointmentCard(BuildContext context, Appointment a) {
    final t = TimeOfDay.fromDateTime(a.dateTime).format(context);
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(children: [
          Container(
            width: 64,
            height: 36,
            decoration: BoxDecoration(color: _primary.withOpacity(.08), borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text(t, style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.doctorName == null ? 'Consultation' : a.doctorName!, style: TextStyle(fontWeight: FontWeight.w600, color: _text)),
              Text(a.reason ?? '-', style: TextStyle(color: _secondary)),
            ]),
          ),
          IconButton(tooltip: 'View Details', onPressed: () {}, icon: Icon(Icons.visibility_outlined, color: _secondary)),
          IconButton(tooltip: 'Cancel', onPressed: () {}, icon: Icon(Icons.cancel_outlined, color: _secondary)),
        ]),
      ),
    );
  }
}
