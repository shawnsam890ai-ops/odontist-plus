import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
// table_calendar removed from this page

import '../../providers/patient_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../models/patient.dart';
import '../../models/appointment.dart';
import '../pages/add_patient_page.dart';
import '../pages/patient_detail_page.dart';

class ManagePatientsModern extends StatelessWidget {
  const ManagePatientsModern({super.key});

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
  const ManagePatientsModernBody({super.key, this.embedded = false});
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

  // Calendar removed; helper not needed

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
            child: LayoutBuilder(builder: (context, c) {
              final narrow = c.maxWidth < 900;
              if (!narrow) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _buildPatientDirectory(filteredPatients)),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildScheduleSection(context, doctorProvider, todays, dayLabel)),
                  ],
                );
              }
              // Stack vertically on narrow widths and make content scrollable
              return SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPatientDirectory(filteredPatients, stacked: true),
                    const SizedBox(height: 16),
                    _buildScheduleSection(context, doctorProvider, todays, dayLabel, stacked: true),
                  ],
                ),
              );
            }),
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
  Widget _buildPatientDirectory(List<Patient> patients, {bool stacked = false}) {
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
          if (!stacked)
            Expanded(
              child: patients.isEmpty
                  ? const Center(child: Text('No patients'))
                  : ListView.separated(
                      itemCount: patients.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: _border),
                      itemBuilder: (_, i) => _buildPatientCard(patients[i]),
                    ),
            )
          else
            (patients.isEmpty
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No patients')))
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: patients.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: _border),
                    itemBuilder: (_, i) => _buildPatientCard(patients[i]),
                  )),
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
        // WhatsApp
        IconButton(
          tooltip: 'WhatsApp',
          iconSize: 22,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: (p.phone.trim().isEmpty) ? null : () => _openWhatsApp(p.phone),
          icon: SvgPicture.asset('assets/images/whatsapp.svg', width: 22, height: 22),
        ),
        // Call
        IconButton(
          tooltip: 'Call',
          iconSize: 22,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: (p.phone.trim().isEmpty) ? null : () => _callPhone(p.phone),
          icon: const Icon(Icons.phone, color: Color(0xFF20C4C4)),
        ),
        const SizedBox(width: 4),
        Container(width: 10, height: 10, decoration: BoxDecoration(color: active ? Colors.green : Colors.grey, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          tooltip: 'More',
          icon: Icon(Icons.more_vert, color: _secondary),
          onSelected: (v) async {
            if (v == 'delete') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete Patient?'),
                  content: Text('This will permanently delete "${p.name}" and all related sessions. This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirm == true) {
                await context.read<PatientProvider>().deletePatient(p.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted ${p.name}')));
                }
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'delete', child: Text('Delete Patient')),
          ],
        ),
      ]),
      onTap: () => Navigator.of(context).pushNamed(PatientDetailPage.routeName, arguments: {'patientId': p.id}),
    );
  }

  // Communication helpers
  Future<void> _callPhone(String? phone) async {
    try {
      if (phone == null || phone.trim().isEmpty) return;
      final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      final uri = Uri(scheme: 'tel', path: digits);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Call not supported on this device')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Call failed: $e')));
    }
  }

  Future<void> _openWhatsApp(String? phone) async {
    try {
      if (phone == null || phone.trim().isEmpty) return;
      final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final waUriNative = Uri.parse('whatsapp://send?phone=$digits');
      final waUriWeb = Uri.parse('https://wa.me/$digits');
      if (await canLaunchUrl(waUriNative)) {
        await launchUrl(waUriNative);
      } else if (await canLaunchUrl(waUriWeb)) {
        await launchUrl(waUriWeb, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp not available')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('WhatsApp open failed: $e')));
    }
  }

  String _nextApptLabel(Patient p) {
    // Placeholder: In absence of persistent appointments per patient, show last session or '-'
    if (p.sessions.isEmpty) return '-';
    final latest = p.sessions.map((s) => s.date).reduce((a, b) => a.isAfter(b) ? a : b);
    return DateFormat('MMM d, h:mm a').format(latest);
  }

  // Right column ---------------------------------------------
  Widget _buildScheduleSection(BuildContext context, DoctorProvider doctorProvider, List<Appointment> todays, String dayLabel, {bool stacked = false}) {
    // Apply doctor filter to today's appointments
    final filteredTodays = (_doctorId == null) ? todays : todays.where((a) => a.doctorId == _doctorId).toList();

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
        // Calendar removed - appointments list retained below
        const SizedBox(height: 6),
        const SizedBox(height: 12),
        if (!stacked)
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
                  Row(children: [
                    // Previous day button
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: _secondary),
                      onPressed: () => setState(() {
                        _selectedDay = (_selectedDay ?? DateTime.now()).subtract(const Duration(days: 1));
                      }),
                      tooltip: 'Previous day',
                    ),
                    // Date label - tappable to open calendar
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _selectedDay ?? now,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 2),
                          );
                          if (pickedDate != null) {
                            setState(() => _selectedDay = pickedDate);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: _primary),
                            const SizedBox(width: 8),
                            Text(
                              'Appointments for $dayLabel',
                              style: TextStyle(fontWeight: FontWeight.w700, color: _text),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Next day button
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: _secondary),
                      onPressed: () => setState(() {
                        _selectedDay = (_selectedDay ?? DateTime.now()).add(const Duration(days: 1));
                      }),
                      tooltip: 'Next day',
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddAppointmentDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Appointment'),
                      style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), textStyle: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredTodays.isEmpty
                        ? const Center(child: Text('No appointments'))
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: filteredTodays.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _buildAppointmentCard(context, filteredTodays[i]),
                          ),
                  ),
                ]),
              ),
            ),
          )
        else
          Card(
            color: Colors.white,
            surfaceTintColor: Colors.white,
            shadowColor: Colors.black.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  // Previous day button
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: _secondary),
                    onPressed: () => setState(() {
                      _selectedDay = (_selectedDay ?? DateTime.now()).subtract(const Duration(days: 1));
                    }),
                    tooltip: 'Previous day',
                  ),
                  // Date label - tappable to open calendar
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedDay ?? now,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 2),
                        );
                        if (pickedDate != null) {
                          setState(() => _selectedDay = pickedDate);
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: _primary),
                          const SizedBox(width: 8),
                          Text(
                            'Appointments for $dayLabel',
                            style: TextStyle(fontWeight: FontWeight.w700, color: _text),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Next day button
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: _secondary),
                    onPressed: () => setState(() {
                      _selectedDay = (_selectedDay ?? DateTime.now()).add(const Duration(days: 1));
                    }),
                    tooltip: 'Next day',
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddAppointmentDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Appointment'),
                    style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), textStyle: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 8),
                if (filteredTodays.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No appointments')))
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: filteredTodays.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _buildAppointmentCard(context, filteredTodays[i]),
                  ),
              ]),
            ),
          ),
      ],
    );
  }

  // -------- Add Appointment Dialog --------
  void _showAddAppointmentDialog(BuildContext context) {
    final patientProvider = context.read<PatientProvider>();
    final apptProvider = context.read<AppointmentProvider>();
    final doctorProvider = context.read<DoctorProvider>();
    final patients = patientProvider.patients;
    bool existing = true;
    String search = '';
    String? selectedPatientId;
    DateTime? date = _selectedDay ?? DateTime.now();
    TimeOfDay? time = TimeOfDay.now();
    final noteCtrl = TextEditingController();
    String? doctorId = _doctorId;

    Future<void> openPicker() async {
      final now = DateTime.now();
      final first = DateTime(now.year - 1, now.month, now.day);
      final last = DateTime(now.year + 2, now.month, now.day);
      final pickedDate = await showDatePicker(context: context, initialDate: date ?? now, firstDate: first, lastDate: last);
      if (pickedDate == null) return;
      final pickedTime = await showTimePicker(context: context, initialTime: time ?? TimeOfDay.now());
      if (pickedTime == null) return;
      date = pickedDate;
      time = pickedTime;
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setSt) {
        final filtered = search.trim().isEmpty
            ? patients
            : patients.where((p) => p.name.toLowerCase().contains(search.toLowerCase()) || p.displayNumber.toString() == search).toList();
        return AlertDialog(
          title: const Text('Add Appointment'),
          content: SizedBox(
            width: 520,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                ChoiceChip(label: const Text('Existing patient'), selected: existing, onSelected: (v) => setSt(() => existing = true)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('New patient'), selected: !existing, onSelected: (v) => setSt(() => existing = false)),
              ]),
              const SizedBox(height: 12),
              if (existing) ...[
                TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search by name or ID'),
                  onChanged: (v) => setSt(() => search = v.trim()),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedPatientId,
                  decoration: const InputDecoration(labelText: 'Select patient'),
                  items: filtered.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.displayNumber}. ${p.name}'))).toList(),
                  onChanged: (v) => setSt(() => selectedPatientId = v),
                ),
                const SizedBox(height: 12),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Navigator.of(context).pushNamed(AddPatientPage.routeName);
                    WidgetsBinding.instance.addPostFrameCallback((_) => _showAddAppointmentDialog(context));
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Open Add Patient form'),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String?>(
                value: doctorId,
                decoration: const InputDecoration(labelText: 'Doctor (optional)'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Any doctor')),
                  for (final d in doctorProvider.doctors) DropdownMenuItem<String?>(value: d.id, child: Text(d.name)),
                ],
                onChanged: (v) => setSt(() => doctorId = v),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async { await openPicker(); setSt(() {}); },
                    icon: const Icon(Icons.event),
                    label: Text(date == null || time == null ? 'Pick date & time' : '${date!.year}-${date!.month.toString().padLeft(2,'0')}-${date!.day.toString().padLeft(2,'0')}  ${time!.format(context)}'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Purpose of visit (note)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (existing && (selectedPatientId == null || date == null || time == null)) return;
                if (!existing) return;
                final dt = DateTime(date!.year, date!.month, date!.day, time!.hour, time!.minute);
                final doctorName = doctorId == null ? null : doctorProvider.byId(doctorId!)?.name;
                apptProvider.add(Appointment(patientId: selectedPatientId!, dateTime: dt, reason: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(), doctorId: doctorId, doctorName: doctorName));
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Save'),
            )
          ],
        );
      }),
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
          IconButton(
            tooltip: 'View Details',
            onPressed: () {
              final patient = context.read<PatientProvider>().byId(a.patientId);
              final patientLabel = patient != null ? '${patient.name} (${patient.displayNumber})' : a.patientId;
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Appointment Details'),
                  content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Time: $t'),
                    const SizedBox(height: 8),
                    Text('Doctor: ${a.doctorName ?? '-'}'),
                    const SizedBox(height: 8),
                    Text('Patient: $patientLabel'),
                    const SizedBox(height: 8),
                    Text('Reason: ${a.reason ?? '-'}'),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                  ],
                ),
              );
            },
            icon: Icon(Icons.visibility_outlined, color: _secondary)),
          IconButton(
            tooltip: 'Cancel',
            onPressed: () async {
              final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                title: const Text('Cancel appointment'),
                content: const Text('Are you sure you want to cancel this appointment?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
                ],
              ));
              if (confirm == true) {
                // remove via provider
                context.read<AppointmentProvider>().remove(a.id);
              }
            },
            icon: Icon(Icons.cancel_outlined, color: _secondary)),
        ]),
      ),
    );
  }
}
