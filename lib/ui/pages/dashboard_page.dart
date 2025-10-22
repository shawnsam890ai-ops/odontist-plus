import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:ui' show FontFeature;
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/patient_provider.dart';
import '../../providers/revenue_provider.dart';
import '../../models/treatment_session.dart';
import '../../core/enums.dart';
import '../../providers/inventory_provider.dart';
import '../../models/inventory_item.dart';
import '../../providers/staff_attendance_provider.dart';
// Removed Doctors on duty feature; related providers no longer needed here.
import '../../providers/medicine_provider.dart';
import '../../providers/options_provider.dart';
import '../../models/medicine.dart';
import '../../providers/utility_provider.dart';
import '../../models/bill_entry.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show MissingPluginException;
import 'dart:io' show File;
import '../../models/revenue_entry.dart';
// Removed fl_chart and revenue_entry imports after chart removal
import '../../providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/cases_overview_chart.dart';
import '../widgets/revenue_trend_card.dart';
import '../widgets/patient_overview_card.dart';
import '../widgets/upcoming_schedule_panel.dart';
import '../widgets/upcoming_schedule_compact.dart';
import '../widgets/upcoming_appointment_widget.dart';
import '../widgets/app_logo.dart';
import '../widgets/staff_attendance_overview_widget.dart';
import 'attendance_view.dart';
import '../widgets/halfday_tile.dart';
import 'doctors_payments_section.dart';
import '../../providers/lab_registry_provider.dart';
import 'manage_patients_modern.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../models/appointment.dart' as appt;
import 'add_patient_page.dart';
import '../../providers/theme_provider.dart';
import '../../models/lab_vendor.dart';

/// Dashboard main page with side navigation and section placeholders.
class DashboardPage extends StatefulWidget {
  static const routeName = '/dashboard';
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

enum DashboardSection {
  overview('Overview', Icons.dashboard_outlined),
  managePatients('Manage Patients', Icons.people_alt_outlined),
  appointments('Appointments', Icons.event_available),
  revenue('Revenue', Icons.currency_rupee),
  staffAttendance('Staff Attendance', Icons.badge_outlined),
  doctorsAttendance('Doctors Attendance', Icons.medical_services_outlined),
  inventory('Inventory', Icons.inventory_2_outlined),
  utility('Utility', Icons.miscellaneous_services_outlined),
  labs('Labs', Icons.biotech_outlined),
  medicines('Medicines', Icons.medication_outlined),
  settings('Settings', Icons.settings_outlined),
  aiInsights('AI Insights', Icons.auto_awesome);

  final String label;
  final IconData icon;
  const DashboardSection(this.label, this.icon);
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardSection _section = DashboardSection.staffAttendance; // default to Staff view
  // Always full-screen; provide a bottom-centered menu with a hide toggle
  bool _menuHidden = false;
  final ScrollController _menuScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _menuScroll.addListener(() {
      // rebuild to show/hide left chevron based on position
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _menuScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  return WillPopScope(
    onWillPop: () async {
      // Back button: first go to Overview; if already there, allow pop
      if (_section != DashboardSection.overview) {
        setState(() => _section = DashboardSection.overview);
        return false;
      }
      return true;
    },
    child: Scaffold(
      appBar: null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(decoration: _backgroundDecoration(context)),
          // Optional dim overlay to improve readability on busy/dark backgrounds
          Builder(builder: (context) {
            final dim = context.watch<ThemeProvider>().backgroundDim;
            return IgnorePointer(
              ignoring: true,
              child: Container(color: Colors.black.withOpacity(dim)),
            );
          }),
          SafeArea(
            child: Stack(children: [
              // Main content without side menu
              Positioned.fill(child: _buildSectionContent()),
              // Bottom centered horizontal menu
              if (!_menuHidden) _buildBottomMenu(context),
              // Toggle button to hide/show the menu
              Positioned(
                right: 12,
                bottom: 12 + MediaQuery.of(context).padding.bottom,
                child: FloatingActionButton.small(
                  heroTag: 'toggleMenu',
                  elevation: 2,
                  onPressed: () => setState(() => _menuHidden = !_menuHidden),
                  child: Icon(_menuHidden ? Icons.expand_less : Icons.expand_more),
                ),
              ),
            ]),
          ),
        ],
      ),
    ),
  );
  }

  BoxDecoration _backgroundDecoration(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final path = themeProv.backgroundImagePath;
    if (path != null && path.isNotEmpty) {
      final asset = path.startsWith('asset:') ? path.substring('asset:'.length) : path;
      return BoxDecoration(
        image: DecorationImage(image: AssetImage(asset), fit: BoxFit.cover),
      );
    }
    // default gradient background
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE0F7FA), Color(0xFFE8F5E9)],
      ),
    );
  }

  Widget _buildSideMenu() {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 68,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 18, offset: const Offset(0, 8)),
          BoxShadow(color: cs.primary.withOpacity(.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: cs.outlineVariant.withOpacity(.25)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        children: [
          for (final s in DashboardSection.values)
            _SideMenuItem(
              section: s,
              selected: s == _section,
              expanded: false,
              onTap: () => setState(() => _section = s),
            ),
        ],
      ),
    );
  }

  // Removed old icon-only item; replaced by _SideMenuItem
  

  Widget _buildSectionContent() {
    switch (_section) {
      case DashboardSection.overview:
        return _overviewSection();
      case DashboardSection.managePatients:
        return _managePatientsSection();
      case DashboardSection.appointments:
        return _appointmentsSection();
      case DashboardSection.revenue:
        return _revenueSection();
      case DashboardSection.staffAttendance:
        return _staffAttendanceSection();
      case DashboardSection.doctorsAttendance:
        return _doctorsAttendanceSection();
      case DashboardSection.inventory:
        return _inventorySection();
      case DashboardSection.utility:
        return _utilitySection();
      case DashboardSection.labs:
        return _labsSection();
      case DashboardSection.medicines:
        return _medicinesSection();
      case DashboardSection.settings:
        return _settingsSection();
      case DashboardSection.aiInsights:
        return _aiInsightsSection();
    }
  }

  // Bottom horizontal menu centered; icons inside circular outline and highlighted when selected
  Widget _buildBottomMenu(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final maxWidth = media.size.width;
    final shellWidth = maxWidth.clamp(0, 560).toDouble();
  final barHeight = 80.0; // ensures 56px icon + 20px padding fits without overflow

    return Positioned(
      left: (maxWidth - shellWidth) / 2,
      right: (maxWidth - shellWidth) / 2,
      bottom: 12,
      child: Stack(children: [
        // Shell container with horizontal scroll
        Container(
          height: barHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 18, offset: const Offset(0, 8)),
            ],
            border: Border.all(color: cs.outlineVariant.withOpacity(.25)),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              controller: _menuScroll,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                children: [
                  for (final s in DashboardSection.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _BottomIconButton(
                        icon: s.icon,
                        label: s.label,
                        selected: _section == s,
                        showLabel: false,
                        onTap: () => setState(() => _section = s),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Right-side scroll toggle button
        Positioned(
          right: 6,
          top: (barHeight - 40) / 2,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                final pos = _menuScroll.position;
                final target = (pos.pixels + 220).clamp(0.0, pos.maxScrollExtent);
                _menuScroll.animateTo(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
              },
              child: Ink(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.primary.withOpacity(.4)),
                ),
                child: Icon(Icons.chevron_right, color: cs.primary),
              ),
            ),
          ),
        ),
        // Left reveal button when scrolled
        if (_menuScroll.hasClients && _menuScroll.offset > 0)
          Positioned(
            left: 6,
            top: (barHeight - 40) / 2,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  final pos = _menuScroll.position;
                  final target = (pos.pixels - 220).clamp(0.0, pos.maxScrollExtent);
                  _menuScroll.animateTo(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                },
                child: Ink(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant.withOpacity(.4)),
                  ),
                  child: Icon(Icons.chevron_left, color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _aiInsightsSection() {
    final patientProvider = context.watch<PatientProvider>();
    // Aggregate last 30 days across all patients
    final since = DateTime.now().subtract(const Duration(days: 30));
    int rct = 0, extraction = 0, fillings = 0, ortho = 0, prostho = 0;
    for (final p in patientProvider.patients) {
      for (final s in p.sessions) {
        if (s.date.isBefore(since)) continue;
        switch (s.type) {
          case TreatmentType.rootCanal:
            rct++;
            break;
          case TreatmentType.orthodontic:
            ortho++;
            break;
          case TreatmentType.prosthodontic:
            prostho++;
            break;
          case TreatmentType.general:
            if (s.treatmentDoneOptions.any((t) => t.toLowerCase().contains('extraction'))) extraction++;
            if (s.treatmentDoneOptions.any((t) => t.toLowerCase().contains('filling'))) fillings++;
            break;
          case TreatmentType.labWork:
            break;
        }
      }
    }

    String tip;
    if (rct + extraction + fillings == 0 && ortho + prostho == 0) {
      tip = 'Quiet month so far. Consider outreach or recall reminders to re-activate patients.';
    } else if (extraction > rct) {
      tip = 'High extractions vs RCTs. Review case selection and patient counseling for tooth preservation.';
    } else if (fillings > rct && fillings > extraction) {
      tip = 'Strong preventive/restorative trend. Consider promoting scaling/oral hygiene packages.';
    } else if (ortho + prostho > 0) {
      tip = 'Specialty cases on the rise. Ensure lab coordination and appointment spacing are optimized.';
    } else {
      tip = 'Balanced caseload. Keep monitoring inventory and appointment load to avoid bottlenecks.';
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AI Insights', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _metricCard('Root Canals', rct, Icons.route_outlined, Colors.indigo),
            _metricCard('Extractions', extraction, Icons.remove_circle_outline, Colors.redAccent),
            _metricCard('Fillings', fillings, Icons.incomplete_circle_outlined, Colors.teal),
            _metricCard('Orthodontic', ortho, Icons.straighten, Colors.orange),
            _metricCard('Prosthodontic', prostho, Icons.brush_outlined, Colors.purple),
          ]),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(children: [
                const Icon(Icons.lightbulb, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(child: Text(tip, style: Theme.of(context).textTheme.bodyLarge)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _metricCard(String title, int count, IconData icon, Color color) {
    return SizedBox(
      width: 240,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('$count in last 30 days', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ]),
        ),
      ),
    );
  }

  // ================= Appointments =================
  Widget _appointmentsSection() {
    // Reuse the upcoming schedule panel and provide an Add Appointment action
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Expanded(child: Text('Appointments', style: Theme.of(context).textTheme.headlineSmall)),
            FilledButton.icon(
              onPressed: () => _openAddAppointmentDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Appointment'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: const UpcomingSchedulePanel(
            padding: EdgeInsets.fromLTRB(0, 8, 0, 12),
            showDoctorFilter: true,
            showTitle: true,
          ),
        ),
      ]),
    );
  }

  // Add Appointment dialog reused by Appointments section
  void _openAddAppointmentDialog(BuildContext context) {
    final patientProvider = context.read<PatientProvider>();
    final apptProvider = context.read<AppointmentProvider>();
    final doctorProvider = context.read<DoctorProvider>();
    final patients = patientProvider.patients;
    bool existing = true;
    String search = '';
    String? selectedPatientId;
    DateTime? date = DateTime.now();
    TimeOfDay? time = TimeOfDay.now();
    final noteCtrl = TextEditingController();
    String? doctorId;

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
                    WidgetsBinding.instance.addPostFrameCallback((_) => _openAddAppointmentDialog(context));
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
            FilledButton(
              onPressed: () {
                if (existing && (selectedPatientId == null || date == null || time == null)) return;
                if (!existing) return;
                final dt = DateTime(date!.year, date!.month, date!.day, time!.hour, time!.minute);
                final doctorName = doctorId == null ? null : doctorProvider.byId(doctorId!)?.name;
                apptProvider.add(appt.Appointment(patientId: selectedPatientId!, dateTime: dt, reason: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(), doctorId: doctorId, doctorName: doctorName));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment created')));
              },
              child: const Text('Save'),
            )
          ],
        );
      }),
    );
  }

  // ================= Overview =================
  Widget _overviewSection() {
  final patientProvider = context.watch<PatientProvider>();
  final revenueProvider = context.watch<RevenueProvider>();
  final inventoryProvider = context.watch<InventoryProvider>();
    final today = DateTime.now();
    double todaysRevenue = revenueProvider.entries
        .where((e) => e.date.year == today.year && e.date.month == today.month && e.date.day == today.day)
        .fold(0.0, (p, e) => p + e.amount);
    double monthlyRevenue = revenueProvider.entries
        .where((e) => e.date.year == today.year && e.date.month == today.month)
        .fold(0.0, (p, e) => p + e.amount);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1100;
          final rightColWidth = wide ? 320.0 : 0.0; // narrower right rail per request
          final gaps = 16.0;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title only; removed Customize button and mode
          Align(alignment: Alignment.centerLeft, child: Text('Overview', style: Theme.of(context).textTheme.headlineSmall)),
          const SizedBox(height: 16),
          if (!wide) ...[
            // Non-wide: use existing stacked layout with compact panels
            _buildMetricsGrid(todaysRevenue, monthlyRevenue, patientProvider, inventoryProvider, revenueProvider),
            const SizedBox(height: 12),
            // Upcoming Schedule and Cases Overview side by side
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 1,
                child: _LargePanel(
                  title: '',
                  child: SizedBox(
                    height: 260,
                    child: const UpcomingScheduleCompact(
                      padding: EdgeInsets.fromLTRB(0, 4, 0, 8),
                    ),
                  ),
                ).withRadius(12),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _LargePanel(
                  title: 'Upcoming Appointment',
                  child: const SizedBox(
                    height: 220,
                    child: UpcomingAppointmentWidget(
                      padding: EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
              _LargePanel(
              title: '',
              child: const SizedBox(height: 420, child: StaffAttendanceOverviewWidget()),
            ),
          ] else ...[
            // Wide: two columns; right column is vertical Upcoming Schedule
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Left column
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Vertically stacked metrics
                  _buildMetricsColumn(todaysRevenue, monthlyRevenue, patientProvider, inventoryProvider, revenueProvider),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: _LargePanel(
                        title: 'Cases Overview',
                        child: SizedBox(
                          height: 240,
                          child: const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Center(
                              child: CasesOverviewChart(
                                data: {
                                  'Root Canal': 18,
                                  'Orthodontic': 12,
                                  'Prosthodontic': 9,
                                  'Filling': 30,
                                },
                                showTitle: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LargePanel(
                        title: '',
                        child: const SizedBox(height: 420, child: StaffAttendanceOverviewWidget()),
                      ),
                    ),
                  ]),
                ]),
              ),
              SizedBox(width: gaps),
              // Right column (vertical Upcoming Schedule)
              SizedBox(
                width: rightColWidth,
                child: _LargePanel(
                  title: '',
                  child: SizedBox(
                    height: 560,
                    child: const UpcomingScheduleCompact(
                      padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
                    ),
                  ),
                ).withRadius(20),
              ),
            ]),
          ],
        ]);
        }),
      ),
    );
  }

  // Removed legacy standard top row with adjustable split; simplified overview is used instead.

  Widget _buildMetricsGrid(double todaysRevenue, double monthlyRevenue, PatientProvider patientProvider, InventoryProvider inventoryProvider, RevenueProvider revenueProvider) {
    String _shortNumber(double v) {
      if (v.abs() >= 100000) {
        // show in lakhs (1L = 100000)
        final val = (v / 100000).toStringAsFixed(v % 100000 == 0 ? 0 : 1);
        return '${val}L';
      }
      if (v.abs() >= 1000) {
        final val = (v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1);
        return '${val}k';
      }
      return v.toStringAsFixed(0);
    }
    final items = [
      // Inventory only; render using PatientOverviewCard-style with an asset avatar.
      (
        title: 'Inventory',
        value: inventoryProvider.totalInventoryValue,
        subtitle: 'Value',
        icon: Icons.inventory_2
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      // Revenue trend card becomes a responsive main tile; other metrics remain fixed width.
      // Keep revenue at a fixed small tile, but make patient card wider.
      const double revenueWidth = 210.0;
      const double _patientAspect = 1.1; // PatientOverviewCard aspectRatio
    // Patient width: slightly reduced responsive tile (clamped to reasonable range)
    final double patientWidth = (c.maxWidth < 420)
      ? c.maxWidth
      : (c.maxWidth * 0.32).clamp(240.0, 360.0);
    // PatientOverviewCard internally clamps width to its maxWidth (180), so
    // derive the effective patient width and height and use that for revenue height
    final double effectivePatientW = patientWidth.clamp(110.0, 180.0);
    final double patientHeight = (effectivePatientW / _patientAspect).clamp(110.0, 400.0);
  final double revenueHeight = patientHeight + 8.0;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          // Make revenue tile match patient tile width for visual balance
          SizedBox(
            height: revenueHeight,
            width: patientWidth,
            child: RevenueTrendCard(
              months: 6,
              overlayImage: const AssetImage('assets/images/revenue_icon.png'),
            ),
          ),
          // Patients card (auto scalable, make it rectangular/wider)
          SizedBox(
            width: patientWidth,
            child: const _PatientOverviewCardWrapper(
              // No subtitle to avoid wrapping text like 'Total'
              subtitle: null,
            ),
          ),
          for (int i = 0; i < items.length; i++)
            // For inventory we prefer the richer patient-like layout with avatar.
            SizedBox(
              width: patientWidth,
              child: (items[i].title == 'Inventory')
                  ? PatientOverviewCard(
                      avatar: const AssetImage('assets/images/inventory_icon.png'),
                      title: 'Inventory',
                      subtitle: 'Value',
                      numericLabel: _shortNumber(items[i].value),
                    )
                  : _DashMetricCard(
                      title: items[i].title,
                      value: items[i].value,
                      subtitle: items[i].subtitle,
                      icon: items[i].icon,
                      appearDelayMs: 60 * (i + 2),
                    ),
            ),
        ],
      );
    });
  }

  // Vertical metrics stack for wide layout
  Widget _buildMetricsColumn(double todaysRevenue, double monthlyRevenue, PatientProvider patientProvider, InventoryProvider inventoryProvider, RevenueProvider revenueProvider) {
    String _shortNumberLocal(double v) {
      if (v.abs() >= 100000) {
        final val = (v / 100000).toStringAsFixed(v % 100000 == 0 ? 0 : 1);
        return '${val}L';
      }
      if (v.abs() >= 1000) {
        final val = (v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1);
        return '${val}k';
      }
      return v.toStringAsFixed(0);
    }
    final entries = [
      ('Today', todaysRevenue, 'Revenue', Icons.today, todaysRevenue >= 0 ? Colors.green : Colors.red),
      // Patients replaced by PatientOverviewCard below
      ('Inventory', inventoryProvider.totalInventoryValue, 'Value', Icons.inventory_2, null),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 320,
          height: 170,
          child: const _PatientOverviewCardWrapper(
            subtitle: null,
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < entries.length; i++) ...[
          SizedBox(
            width: 320,
            height: 170,
            child: entries[i].$1 == 'Inventory'
                ? PatientOverviewCard(
                    avatar: const AssetImage('assets/images/inventory_icon.png'),
                    title: 'Inventory',
                    subtitle: 'Value',
                    numericLabel: _shortNumberLocal(entries[i].$2),
                  )
                : _DashMetricCard(
                    title: entries[i].$1,
                    value: entries[i].$2,
                    subtitle: entries[i].$3,
                    icon: entries[i].$4,
                    valueColor: entries[i].$5,
                    appearDelayMs: 60 * i,
                  ),
          ),
          if (i != entries.length - 1) const SizedBox(height: 12),
        ]
      ],
    );
  }

  // Removed legacy customizable canvas implementation.
  

  // ============== Manage Patients ==============
  Widget _managePatientsSection() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: ManagePatientsModernBody(embedded: true),
    );
  }

  // ================= Revenue =================
  Widget _revenueSection() {
    final revenueProvider = context.watch<RevenueProvider>();
    final today = DateTime.now();
    double todaysRevenue = revenueProvider.entries
        .where((e) => e.date.year == today.year && e.date.month == today.month && e.date.day == today.day)
        .fold(0.0, (p, e) => p + e.amount);
    double monthlyRevenue = revenueProvider.entries
        .where((e) => e.date.year == today.year && e.date.month == today.month)
        .fold(0.0, (p, e) => p + e.amount);
    String _shortNumber(double v) {
      if (v.abs() >= 100000) {
        final val = (v / 100000).toStringAsFixed(v % 100000 == 0 ? 0 : 1);
        return '${val}L';
      }
      if (v.abs() >= 1000) {
        final val = (v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1);
        return '${val}k';
      }
      return v.toStringAsFixed(0);
    }
    final todaysStr = '₹${_shortNumber(todaysRevenue)}';
    final monthlyStr = '₹${_shortNumber(monthlyRevenue)}';
    final totalStr = '₹${_shortNumber(revenueProvider.total)}';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Revenue', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Wrap(spacing: 16, runSpacing: 16, children: [
         _DashCard(title: "Today's Revenue", value: todaysStr, icon: Icons.today, width: 220, valueColor: todaysRevenue >= 0 ? Colors.green : Colors.red, overlayImage: const AssetImage('assets/images/money_bag.png'), minHeight: 130),
         _DashCard(title: 'Monthly Revenue', value: monthlyStr, icon: Icons.calendar_month, width: 220, valueColor: monthlyRevenue >= 0 ? Colors.green : Colors.red, overlayImage: const AssetImage('assets/images/coin_gear.png'), minHeight: 130),
         _DashCard(title: 'Total Revenue', value: totalStr, icon: Icons.account_balance_wallet, width: 220, valueColor: revenueProvider.total >= 0 ? Colors.green : Colors.red, overlayImage: const AssetImage('assets/images/envelope_cash.png'), minHeight: 130),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: _RevenueListPanel(),
          ),
        )
      ]),
    );
  }

  // Add Clinic section removed

  // ============== Staff Attendance ==============
  Widget _staffAttendanceSection() {
    return const MonthlyAttendanceView();
  }

  // ============== Doctors Attendance ==============
  Widget _doctorsAttendanceSection() {
    // Use the new doctors payments section (includes list, rules, calculator)
    return const DoctorsPaymentsSection();
  }

  // ============== Inventory ==============
  Widget _inventorySection() {
    final inventoryProvider = context.watch<InventoryProvider>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Clinic Inventory', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Row(children: [
          ElevatedButton.icon(onPressed: () => _showAddInventoryDialog(), icon: const Icon(Icons.add), label: const Text('Add Item')),
          const SizedBox(width: 12),
          Text('Total Inv: ₹${inventoryProvider.totalInventoryValue.toStringAsFixed(0)}')
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: Column(
              children: [
                const ListTile(title: Text('Inventory Items')),
                const Divider(height: 1),
                Expanded(
                  child: inventoryProvider.items.isEmpty
                      ? const Center(child: Text('No items'))
                      : ListView.builder(
                          itemCount: inventoryProvider.items.length,
                          itemBuilder: (c, i) {
                            final item = inventoryProvider.items[i];
                            return ListTile(
                              title: Text(item.name),
                              subtitle: Text('Qty: ${item.quantity}  Unit: ₹${item.unitCost.toStringAsFixed(0)}  Total: ₹${item.total.toStringAsFixed(0)}'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') _showEditInventoryDialog(item.id, item.name, item.quantity, item.unitCost);
                                  if (v == 'delete') inventoryProvider.removeItem(item.id);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            );
                          },
                        ),
                )
              ],
            ),
          ),
        )
      ]),
    );
  }

  // ============== Utility ==============
  Widget _utilitySection() {
    final util = context.watch<UtilityProvider>();
    // ensure data is loaded
    if (!util.isLoaded) {
      util.ensureLoaded();
    }
    final services = util.services;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text('Utility & Bills', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Row(children: [
          ElevatedButton.icon(onPressed: _showAddUtilityDialog, icon: const Icon(Icons.add), label: const Text('Add Utility')),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(onPressed: _showAddBillDialog, icon: const Icon(Icons.shopping_cart_checkout), label: const Text('Add Bill')),
          const SizedBox(width: 12),
          Text('Services: ${services.length}')
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: services.isEmpty
                ? const Center(child: Text('No utilities added'))
                : ListView.separated(
                    itemCount: services.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final s = services[i];
                      return ExpansionTile(
                        title: Text(s.name),
                        subtitle: s.regNumber == null || s.regNumber!.isEmpty ? null : Text('Reg/ID: ${s.regNumber}'),
                        trailing: Switch(value: s.active, onChanged: (v) => context.read<UtilityProvider>().updateService(s.id, active: v)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonalIcon(
                                  onPressed: () => _showAddUtilityPaymentDialog(s.id),
                                  icon: const Icon(Icons.receipt_long),
                                  label: const Text('Add Payment'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _utilityPaymentsList(s.id),
                            ]),
                          )
                        ],
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 16),
        // Payments history panel (scrollable, filterable, exportable)
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: _UtilityPaymentsHistoryPanel(),
          ),
        ),
        const SizedBox(height: 16),
        // Bills history
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: _BillsHistoryPanel(),
          ),
        ),
      ]),
    );
  }

  Widget _utilityPaymentsList(String serviceId) {
    final util = context.watch<UtilityProvider>();
    final list = util.payments.where((p) => p.serviceId == serviceId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (list.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('No payments'));
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = list[i];
        final dateStr = '${p.date.year}-${p.date.month.toString().padLeft(2, '0')}-${p.date.day.toString().padLeft(2, '0')}';
        return ListTile(
          title: Text('₹${p.amount.toStringAsFixed(0)} • ${p.mode ?? '—'}'),
          subtitle: Text('Date: $dateStr${p.receiptPath != null ? '  •  Receipt: ${p.receiptPath}' : ''}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Checkbox(
              value: p.paid,
              onChanged: (v) => context.read<UtilityProvider>().updatePaymentPaid(p.id, v ?? false),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Delete payment',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => context.read<UtilityProvider>().deletePayment(p.id),
            )
          ]),
        );
      },
    );
  }

  void _showAddUtilityDialog() {
    final nameCtrl = TextEditingController();
    final regCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Utility'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Service name (e.g., Electricity)')),
            const SizedBox(height: 8),
            TextField(controller: regCtrl, decoration: const InputDecoration(labelText: 'Reg number / ID number (optional)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await context.read<UtilityProvider>().addService(name, regNumber: regCtrl.text.trim().isEmpty ? null : regCtrl.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  void _showAddUtilityPaymentDialog(String serviceId) {
    final amountCtrl = TextEditingController(text: '0');
    final modeCtrl = ValueNotifier<String>('Cash');
    final receiptCtrl = TextEditingController();
    DateTime date = DateTime.now();
    bool paid = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('Add Utility Payment'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Text('Select date:'),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 1));
                    if (picked != null) setSt(() => date = picked);
                  },
                  child: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
                )
              ]),
              const SizedBox(height: 8),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Payment amount')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: modeCtrl.value,
                decoration: const InputDecoration(labelText: 'Mode of transaction'),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(value: 'Card', child: Text('Card')),
                  DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                ],
                onChanged: (v) => modeCtrl.value = v ?? 'Cash',
              ),
              const SizedBox(height: 8),
              Row(children: [
                Checkbox(
                  value: paid,
                  onChanged: (v) => setSt(() => paid = v ?? false),
                ),
                const SizedBox(width: 8),
                const Text('Mark paid'),
              ]),
              const SizedBox(height: 8),
              TextField(controller: receiptCtrl, decoration: const InputDecoration(labelText: 'Attach receipt (path or note)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0;
                if (amt <= 0) return;
                await context.read<UtilityProvider>().addPayment(
                      serviceId,
                      date: date,
                      amount: amt,
                      mode: modeCtrl.value,
                      paid: paid,
                      receiptPath: receiptCtrl.text.trim().isEmpty ? null : receiptCtrl.text.trim(),
                    );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            )
          ],
        ),
      ),
    );
  }

  void _showAddBillDialog() {
    final itemCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '0');
  final receiptCtrl = TextEditingController();
    DateTime date = DateTime.now();
    String category = 'Consumables';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('Add Bill'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Text('Purchase date:'),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 1));
                    if (picked != null) setSt(() => date = picked);
                  },
                  child: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
                )
              ]),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'Consumables', child: Text('Consumables')),
                  DropdownMenuItem(value: 'Equipment', child: Text('Equipment')),
                  DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setSt(() => category = v ?? 'Consumables'),
              ),
              const SizedBox(height: 8),
              TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'Item name / purpose')),
              const SizedBox(height: 8),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost of purchase')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: receiptCtrl, decoration: const InputDecoration(labelText: 'Receipt (path or note)'))),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Pick file',
                  icon: const Icon(Icons.attach_file),
                  onPressed: () async {
                    final res = await FilePicker.platform.pickFiles(withReadStream: false);
                    if (res != null && res.files.isNotEmpty) {
                      final path = res.files.single.path;
                      if (path != null) {
                        setSt(() => receiptCtrl.text = path);
                      }
                    }
                  },
                ),
                if (receiptCtrl.text.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Open receipt',
                    icon: const Icon(Icons.visibility),
                    onPressed: () async {
                      final path = receiptCtrl.text;
                      await openReceiptWithFallback(context, path);
                    },
                  )
                ]
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = itemCtrl.text.trim();
                final amt = double.tryParse(amountCtrl.text) ?? 0;
                if (name.isEmpty || amt <= 0) return;
                await context.read<UtilityProvider>().addBill(date: date, itemName: name, amount: amt, receiptPath: receiptCtrl.text.trim().isEmpty ? null : receiptCtrl.text.trim(), category: category);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            )
          ],
        ),
      ),
    );
  }

  // ============== Labs (Registry) ==============
  Widget _labsSection() {
    final labsProvider = context.watch<LabRegistryProvider>();
    final labs = labsProvider.labs;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Labs', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Row(children: [
          ElevatedButton.icon(onPressed: _showAddLabDialog, icon: const Icon(Icons.add_business), label: const Text('Add Lab')),
          const SizedBox(width: 12),
          Text('Registered: ${labs.length}')
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: labs.isEmpty
                ? const Center(child: Text('No labs registered'))
                : ListView.separated(
                    itemCount: labs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final lab = labs[i];
                      final String? _phone = (lab.labPhone != null && lab.labPhone!.trim().isNotEmpty)
                          ? lab.labPhone!.trim()
                          : ((lab.staffPhone != null && lab.staffPhone!.trim().isNotEmpty) ? lab.staffPhone!.trim() : null);
                      return ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: Text(lab.name),
                        subtitle: lab.address.isNotEmpty ? Text(lab.address) : null,
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (_phone != null) ...[
                            Tooltip(
                              message: 'WhatsApp',
                              child: IconButton(
                                icon: Icon(Icons.chat, color: const Color(0xFF25D366)),
                                onPressed: () => _launchWhatsApp(_phone),
                              ),
                            ),
                            Tooltip(
                              message: 'Call',
                              child: IconButton(
                                icon: const Icon(Icons.call_outlined),
                                onPressed: () => _launchCall(_phone),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          IconButton(
                            icon: const Icon(Icons.add),
                            tooltip: 'Add product',
                            onPressed: () => _showAddLabProductDialog(lab.id),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                _showEditLabDialog(lab);
                              } else if (v == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete Lab?'),
                                    content: Text('Delete "${lab.name}" and all its products?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await context.read<LabRegistryProvider>().deleteLab(lab.id);
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit Lab')),
                              PopupMenuItem(value: 'delete', child: Text('Delete Lab')),
                            ],
                          ),
                        ]),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (lab.products.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text('No products'),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: lab.products.length,
                                  itemBuilder: (_, j) {
                                    final p = lab.products[j];
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(p.name),
                                      subtitle: Text('₹${p.rate.toStringAsFixed(0)}'),
                                      trailing: PopupMenuButton<String>(
                                        onSelected: (v) {
                                          if (v == 'edit') _showEditLabProductDialog(lab.id, p.id, p.name, p.rate);
                                          if (v == 'delete') context.read<LabRegistryProvider>().deleteProduct(lab.id, p.id);
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              const SizedBox(height: 8),
                            ]),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }

  // ============== Medicines ==============
  Widget _medicinesSection() {
    final medProv = context.watch<MedicineProvider>();
    final meds = medProv.medicines;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Medicines', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Row(children: [
          ElevatedButton.icon(onPressed: _showAddMedicineDialog, icon: const Icon(Icons.add), label: const Text('Add Medicine')),
          const SizedBox(width: 12),
          Text('Total: ${meds.length}')
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: meds.isEmpty
                ? const Center(child: Text('No medicines added'))
                : ListView.separated(
                    itemCount: meds.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final m = meds[i];
                      final profit = m.mrp - m.storeAmount;
                      return ListTile(
                        title: Text(m.name),
                        subtitle: Text('Store: ₹${m.storeAmount.toStringAsFixed(0)}   •   MRP: ₹${m.mrp.toStringAsFixed(0)}   •   Profit/strip: ₹${profit.toStringAsFixed(0)}   •   Units/strip: ${m.unitsPerStrip}   •   Strips: ${m.stripsAvailable}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await _showEditMedicineDialog(m);
                            } else if (v == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete Medicine?'),
                                  content: Text('Delete "${m.name}"? This cannot be undone.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirm == true) await context.read<MedicineProvider>().deleteMedicine(m.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }

  void _showAddMedicineDialog() {
    final nameCtrl = TextEditingController();
    final storeCtrl = TextEditingController(text: '0');
    final mrpCtrl = TextEditingController(text: '0');
  final stripsCtrl = TextEditingController(text: '0');
  final unitsCtrl = TextEditingController(text: '10');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Medicine'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Medicine name')),
            const SizedBox(height: 8),
            TextField(controller: storeCtrl, decoration: const InputDecoration(labelText: 'Store amount (cost per strip)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: mrpCtrl, decoration: const InputDecoration(labelText: 'MRP (selling price per strip)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: stripsCtrl, decoration: const InputDecoration(labelText: 'No. of strips available'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: unitsCtrl, decoration: const InputDecoration(labelText: 'Units per strip (tabs/ml)'), keyboardType: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final store = double.tryParse(storeCtrl.text.trim()) ?? 0;
              final mrp = double.tryParse(mrpCtrl.text.trim()) ?? 0;
              final strips = int.tryParse(stripsCtrl.text.trim()) ?? 0;
              if (name.isEmpty) return;
              // Save in inventory
              final ups = int.tryParse(unitsCtrl.text.trim()) ?? 10;
              await context.read<MedicineProvider>().addMedicine(name: name, storeAmount: store, mrp: mrp, strips: strips, unitsPerStrip: ups);
              // Also add to selectable medicine options (avoids picker not showing new meds)
              await context.read<OptionsProvider>().addValue('medicines', name);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditMedicineDialog(Medicine m) async {
    final nameCtrl = TextEditingController(text: m.name);
    final storeCtrl = TextEditingController(text: m.storeAmount.toStringAsFixed(0));
    final mrpCtrl = TextEditingController(text: m.mrp.toStringAsFixed(0));
    final stripsCtrl = TextEditingController(text: m.stripsAvailable.toString());
    final unitsCtrl = TextEditingController(text: m.unitsPerStrip.toString());
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Medicine'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Medicine name')),
            const SizedBox(height: 8),
            TextField(controller: storeCtrl, decoration: const InputDecoration(labelText: 'Store amount (cost per strip)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: mrpCtrl, decoration: const InputDecoration(labelText: 'MRP (selling price per strip)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: stripsCtrl, decoration: const InputDecoration(labelText: 'No. of strips available'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: unitsCtrl, decoration: const InputDecoration(labelText: 'Units per strip (tabs/ml)'), keyboardType: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final store = double.tryParse(storeCtrl.text.trim()) ?? m.storeAmount;
              final mrp = double.tryParse(mrpCtrl.text.trim()) ?? m.mrp;
              final strips = int.tryParse(stripsCtrl.text.trim()) ?? m.stripsAvailable;
              final ups = int.tryParse(unitsCtrl.text.trim()) ?? m.unitsPerStrip;
              await context.read<MedicineProvider>().updateMedicine(
                    m.id,
                    name: name,
                    storeAmount: store,
                    mrp: mrp,
                    strips: strips,
                    unitsPerStrip: ups,
                  );
              // Ensure pickers include renamed medicine if name changed
              if (name != m.name) {
                await context.read<OptionsProvider>().addValue('medicines', name);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ========= Labs Dialogs =========
  void _showAddLabDialog() {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final labPhoneCtrl = TextEditingController();
    final staffNameCtrl = TextEditingController();
    final staffPhoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Register Lab'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Lab name')),
            const SizedBox(height: 8),
            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Lab address')),
            const SizedBox(height: 8),
            _PhoneField(
              controller: labPhoneCtrl,
              label: 'Lab phone (WhatsApp/Call)',
              onWhatsApp: () => _launchWhatsApp(labPhoneCtrl.text),
              onCall: () => _launchCall(labPhoneCtrl.text),
            ),
            const SizedBox(height: 8),
            TextField(controller: staffNameCtrl, decoration: const InputDecoration(labelText: 'Staff contact name')),
            const SizedBox(height: 8),
            _PhoneField(
              controller: staffPhoneCtrl,
              label: 'Staff phone',
              onWhatsApp: () => _launchWhatsApp(staffPhoneCtrl.text),
              onCall: () => _launchCall(staffPhoneCtrl.text),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await context.read<LabRegistryProvider>().addLab(
                    name,
                    addrCtrl.text.trim(),
                    labPhone: labPhoneCtrl.text.trim().isEmpty ? null : labPhoneCtrl.text.trim(),
                    staffName: staffNameCtrl.text.trim().isEmpty ? null : staffNameCtrl.text.trim(),
                    staffPhone: staffPhoneCtrl.text.trim().isEmpty ? null : staffPhoneCtrl.text.trim(),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  void _showEditLabDialog(LabVendor lab) {
    final nameCtrl = TextEditingController(text: lab.name);
    final addrCtrl = TextEditingController(text: lab.address);
    final labPhoneCtrl = TextEditingController(text: lab.labPhone ?? '');
    final staffNameCtrl = TextEditingController(text: lab.staffName ?? '');
    final staffPhoneCtrl = TextEditingController(text: lab.staffPhone ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Lab'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Lab name')),
            const SizedBox(height: 8),
            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Lab address')),
            const SizedBox(height: 8),
            _PhoneField(
              controller: labPhoneCtrl,
              label: 'Lab phone (WhatsApp/Call)',
              onWhatsApp: () => _launchWhatsApp(labPhoneCtrl.text),
              onCall: () => _launchCall(labPhoneCtrl.text),
            ),
            const SizedBox(height: 8),
            TextField(controller: staffNameCtrl, decoration: const InputDecoration(labelText: 'Staff contact name')),
            const SizedBox(height: 8),
            _PhoneField(
              controller: staffPhoneCtrl,
              label: 'Staff phone',
              onWhatsApp: () => _launchWhatsApp(staffPhoneCtrl.text),
              onCall: () => _launchCall(staffPhoneCtrl.text),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await context.read<LabRegistryProvider>().updateLab(
                    lab.id,
                    name: nameCtrl.text.trim(),
                    address: addrCtrl.text.trim(),
                    labPhone: labPhoneCtrl.text.trim().isEmpty ? null : labPhoneCtrl.text.trim(),
                    staffName: staffNameCtrl.text.trim().isEmpty ? null : staffNameCtrl.text.trim(),
                    staffPhone: staffPhoneCtrl.text.trim().isEmpty ? null : staffPhoneCtrl.text.trim(),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsApp(String rawNumber) async {
    final number = _normalizePhone(rawNumber, forWhatsApp: true);
    if (number.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchCall(String rawNumber) async {
    final number = _normalizePhone(rawNumber);
    if (number.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _normalizePhone(String input, {bool forWhatsApp = false}) {
    // Keep digits and leading +, strip spaces/dashes/others
    final digits = input.replaceAll(RegExp(r'[^+0-9]'), '');
    if (digits.isEmpty) return '';
    if (forWhatsApp) {
      // wa.me expects international format without +
      return digits.startsWith('+') ? digits.substring(1) : digits;
    }
    return digits;
  }

  void _showAddLabProductDialog(String labId) {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Lab Product'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product name (e.g., PFM Crown)')),
            const SizedBox(height: 8),
            TextField(controller: rateCtrl, decoration: const InputDecoration(labelText: 'Rate'), keyboardType: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final rate = double.tryParse(rateCtrl.text) ?? 0;
              if (name.isEmpty || rate <= 0) return;
              await context.read<LabRegistryProvider>().addProduct(labId, name, rate);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditLabProductDialog(String labId, String productId, String name, double rate) {
    final nameCtrl = TextEditingController(text: name);
    final rateCtrl = TextEditingController(text: rate.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Lab Product'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product name')),
            const SizedBox(height: 8),
            TextField(controller: rateCtrl, decoration: const InputDecoration(labelText: 'Rate'), keyboardType: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newRate = double.tryParse(rateCtrl.text) ?? rate;
              await context.read<LabRegistryProvider>().updateProduct(labId, productId, name: nameCtrl.text.trim(), rate: newRate);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ============== Settings ==============
  Widget _settingsSection() {
    final themeProv = context.watch<ThemeProvider>();
    // When forceWhiteText is ON, show white foreground for texts/icons in the
    // Settings section (which is laid on the background image), while keeping
    // text inside surfaced containers elsewhere black via their own theming.
    final useWhite = themeProv.forceWhiteText;
    final baseTheme = Theme.of(context);
    final cs = baseTheme.colorScheme;
    final whiteTextTheme = baseTheme.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
      decorationColor: Colors.white70,
    );
    // Override ChipTheme so that chip labels remain dark on their surface.
    final chipTheme = baseTheme.chipTheme.copyWith(
      labelStyle: TextStyle(color: cs.onSurface),
    );
    return Theme(
      data: useWhite ? baseTheme.copyWith(textTheme: whiteTextTheme, chipTheme: chipTheme) : baseTheme,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: useWhite ? Colors.white : null),
        child: IconTheme(
          data: IconTheme.of(context).copyWith(color: useWhite ? Colors.white70 : null),
          child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        const Text('General configuration placeholders will appear here.'),
        const SizedBox(height: 12),
        Text('Theme', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _themeChoiceChip('Green', ThemePreset.green, themeProv),
          _themeChoiceChip('Purple', ThemePreset.purple, themeProv),
          _themeChoiceChip('Red', ThemePreset.red, themeProv),
          ActionChip(
            label: const Text('Custom…'),
            avatar: const Icon(Icons.color_lens_outlined),
            onPressed: () => _showCustomThemeDialog(themeProv),
          ),
        ]),
        const SizedBox(height: 24),
        // Printing (Rx) header/footer images
        Text('Printing', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _rxImagePreview(themeProv.rxHeaderPath),
            const SizedBox(width: 8),
            Expanded(child: Text('Rx header image: ${themeProv.hasRxHeader ? (themeProv.rxHeaderPath!.startsWith('asset:') ? themeProv.rxHeaderPath!.substring(6) : themeProv.rxHeaderPath) : 'Not set'}', overflow: TextOverflow.ellipsis)),
            TextButton.icon(
              onPressed: () => _showRxImagePicker(isHeader: true, themeProv: themeProv),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Change'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: themeProv.hasRxHeader ? () => themeProv.setRxHeaderImagePath(null) : null,
              icon: const Icon(Icons.restore),
              label: const Text('Clear'),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _rxImagePreview(themeProv.rxFooterPath),
            const SizedBox(width: 8),
            Expanded(child: Text('Rx footer image: ${themeProv.hasRxFooter ? (themeProv.rxFooterPath!.startsWith('asset:') ? themeProv.rxFooterPath!.substring(6) : themeProv.rxFooterPath) : 'Not set'}', overflow: TextOverflow.ellipsis)),
            TextButton.icon(
              onPressed: () => _showRxImagePicker(isHeader: false, themeProv: themeProv),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Change'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: themeProv.hasRxFooter ? () => themeProv.setRxFooterImagePath(null) : null,
              icon: const Icon(Icons.restore),
              label: const Text('Clear'),
            ),
          ]),
        ]),
        const SizedBox(height: 24),
        // Background image controls
        Text('Background', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text(themeProv.isDefaultBackground ? 'Default background selected' : 'Preset background selected'),
          ),
          TextButton.icon(
            onPressed: () => _showBackgroundPicker(themeProv),
            icon: const Icon(Icons.image_outlined),
            label: const Text('Change'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => themeProv.setBackgroundImageAsset(ThemeProvider.defaultBackgroundAsset),
            icon: const Icon(Icons.restore),
            label: const Text('Reset to default'),
          ),
        ]),
        const SizedBox(height: 24),
        // Contrast controls
        Text('Contrast', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('Force white text (useful for dark backgrounds)')),
          Switch(
            value: themeProv.forceWhiteText,
            onChanged: (v) => themeProv.setForceWhiteText(v),
          ),
        ]),
        const SizedBox(height: 24),
        Wrap(spacing: 12, runSpacing: 12, children: [
          const Chip(label: Text('Theme: Light/Dark')),
          const Chip(label: Text('Backup: Not Configured')),
          if (context.watch<AuthProvider>().isAdmin)
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pushNamed('/admin-users'),
              child: const Text('Manage Users (Admin)'),
            ),
        ])
        ,
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.person_outline),
            const SizedBox(width: 8),
            Expanded(child: Text(context.watch<AuthProvider>().user?.email ?? '')),
            TextButton.icon(
              onPressed: () async {
                await context.read<AuthProvider>().signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            )
          ],
        )
      ]),
          ),
        ),
      ),
    );
  }

  void _showBackgroundPicker(ThemeProvider themeProv) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Choose Background'),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Preset images'),
              const SizedBox(height: 8),
              Builder(
                builder: (_) {
                  final presets = ThemeProvider.allowedBackgroundAssets;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((p) => _bgThumb(p, themeProv)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _rxImagePreview(String? path) {
    final size = const Size(56, 36);
    if (path == null || path.isEmpty) {
      return Container(width: size.width, height: size.height, color: Colors.black12, alignment: Alignment.center, child: const Icon(Icons.image_not_supported, size: 18));
    }
    if (path.startsWith('asset:')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(path.substring(6), width: size.width, height: size.height, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: size.width, height: size.height, color: Colors.black12, alignment: Alignment.center, child: const Icon(Icons.broken_image, size: 18))),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(File(path), width: size.width, height: size.height, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: size.width, height: size.height, color: Colors.black12, alignment: Alignment.center, child: const Icon(Icons.broken_image, size: 18))),
    );
  }

  void _showRxImagePicker({required bool isHeader, required ThemeProvider themeProv}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isHeader ? 'Choose Rx Header' : 'Choose Rx Footer'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Preset images (assets)')
              , const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  'assets/images/clinic_header.jpg',
                  'assets/images/clinic_footer.jpg',
                ].map((a) => InkWell(
                  onTap: () async {
                    if (isHeader) {
                      await themeProv.setRxHeaderImageAsset(a);
                    } else {
                      await themeProv.setRxFooterImageAsset(a);
                    }
                    if (mounted) Navigator.pop(context);
                  },
                  child: _bgThumb(a, themeProv),
                )).toList(),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Text('Or pick from your files'),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final res = await FilePicker.platform.pickFiles(type: FileType.image, withReadStream: false);
                    final p = res?.files.single.path;
                    if (p != null) {
                      if (isHeader) {
                        await themeProv.setRxHeaderImagePath(p);
                      } else {
                        await themeProv.setRxFooterImagePath(p);
                      }
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.upload),
                  label: const Text('Pick image file'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _bgThumb(String asset, ThemeProvider themeProv) {
    final selected = themeProv.backgroundImagePath == 'asset:$asset';
    return InkWell(
      onTap: () async {
        await themeProv.setBackgroundImageAsset(asset);
        if (mounted) Navigator.pop(context);
      },
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              asset,
              width: 90,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                width: 90,
                height: 60,
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          if (selected)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _themeChoiceChip(String label, ThemePreset preset, ThemeProvider themeProv) {
    final selected = themeProv.preset == preset;
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      // Chip has a surface-like container; keep its text dark for readability
      label: Text(label, style: TextStyle(color: cs.onSurface)),
      selected: selected,
      onSelected: (_) => themeProv.setPreset(preset),
    );
  }

  void _showCustomThemeDialog(ThemeProvider themeProv) {
    String _toRgbHex(Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    final hexCtrl = TextEditingController(text: _toRgbHex(themeProv.customPrimary));
    final hexLightCtrl = TextEditingController(text: _toRgbHex(themeProv.customPrimaryContainer));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Custom Theme Color'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(alignment: Alignment.centerLeft, child: Text('Primary color (HEX)')),
            const SizedBox(height: 8),
            TextField(
              controller: hexCtrl,
              decoration: const InputDecoration(
                prefixText: '',
                hintText: '#8B27E2',
              ),
            ),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('Light/Container color (HEX)')),
            const SizedBox(height: 8),
            TextField(
              controller: hexLightCtrl,
              decoration: const InputDecoration(
                prefixText: '',
                hintText: '#D9B6FF',
              ),
            ),
            const SizedBox(height: 8),
            Text('Tip: icopurple = #8B27E2, light = #D9B6FF', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Preview:'),
              const SizedBox(width: 8),
              _colorSwatch(hexCtrl.text),
              const SizedBox(width: 6),
              _colorSwatch(hexLightCtrl.text),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final color = _parseHexColor(hexCtrl.text.trim());
              final light = _parseHexColor(hexLightCtrl.text.trim());
              if (color != null) {
                themeProv.setCustomColors(color, primaryContainer: light);
                Navigator.pop(context);
              }
            },
            child: const Text('Apply'),
          )
        ],
      ),
    );
  }

  Color? _parseHexColor(String input) {
    var v = input.toUpperCase().replaceAll('#', '').replaceAll('0X', '');
    if (v.length == 6) v = 'FF$v';
    if (v.length != 8) return null;
    final intVal = int.tryParse(v, radix: 16);
    if (intVal == null) return null;
    return Color(intVal);
  }

  Widget _colorSwatch(String hex) {
    final c = _parseHexColor(hex);
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: c ?? Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black12),
      ),
    );
  }

  // ========= Inventory Dialog Helpers =========
  void _showAddInventoryDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '0');
    final costCtrl = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Inventory Item'),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
            TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Unit Cost'), keyboardType: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final qty = int.tryParse(qtyCtrl.text) ?? 0;
              final cost = double.tryParse(costCtrl.text) ?? 0;
              context.read<InventoryProvider>().addItem(InventoryItem(name: name, quantity: qty, unitCost: cost));
              Navigator.pop(context);
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  void _showEditInventoryDialog(String id, String name, int quantity, double unitCost) {
    final nameCtrl = TextEditingController(text: name);
    final qtyCtrl = TextEditingController(text: quantity.toString());
    final costCtrl = TextEditingController(text: unitCost.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Inventory Item'),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
            TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Unit Cost'), keyboardType: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final n = nameCtrl.text.trim();
              if (n.isEmpty) return;
              final q = int.tryParse(qtyCtrl.text) ?? quantity;
              final cVal = double.tryParse(costCtrl.text) ?? unitCost;
              context.read<InventoryProvider>().updateItem(id, quantity: q, unitCost: cVal, name: n);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  // removed legacy Lab Cost dialogs (moved to Labs registry UI)

  // ========= Reusable Dashboard Widgets =========
}

class _SideMenuItem extends StatefulWidget {
  final DashboardSection section;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;
  const _SideMenuItem({required this.section, required this.selected, required this.expanded, required this.onTap});
  @override
  State<_SideMenuItem> createState() => _SideMenuItemState();
}

class _SideMenuItemState extends State<_SideMenuItem> with SingleTickerProviderStateMixin {
  bool _hover = false;
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = widget.selected;
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hover = true);
        _ctrl.forward();
      },
      onExit: (_) {
        setState(() => _hover = false);
        _ctrl.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primary.withOpacity(.12) : (_hover ? cs.surfaceVariant.withOpacity(.35) : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? cs.primary.withOpacity(.35) : Colors.transparent),
          ),
          child: Row(
            children: [
              Tooltip(
                message: widget.section.label,
                waitDuration: const Duration(milliseconds: 250),
                child: ScaleTransition(
                  scale: _scale,
                  child: Icon(widget.section.icon, color: selected ? cs.primary : cs.onSurfaceVariant),
                ),
              ),
              if (widget.expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.section.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: selected ? cs.primary : null),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final List<Widget>? rightActions;
  const _TopBar({this.rightActions});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeProv = context.watch<ThemeProvider>();
    final darkBar = themeProv.forceWhiteText; // when true, prefer a dark appbar background
    final appts = context.watch<AppointmentProvider>();
    final due = appts.dueNow(graceMinutes: 10);
    final upcoming = appts.upcomingWithin(withinMinutes: 60);
    final hasAlerts = due.isNotEmpty || upcoming.isNotEmpty;
    return AppBar(
      elevation: 0,
      backgroundColor: darkBar ? Colors.black.withOpacity(0.45) : cs.surface,
      title: Row(children: [
        const AppLogo(size: 28),
        const SizedBox(width: 10),
        Text(
          'Odontist Plus',
          style: GoogleFonts.cinzel(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: darkBar ? Colors.white : null,
          ),
        ),
      ]),
      actions: [
        // Notification bell
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Stack(children: [
            IconButton(
              tooltip: 'Appointments',
              onPressed: () => _showApptSheet(context),
              icon: const Icon(Icons.notifications_none),
            ),
            if (hasAlerts)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                ),
              ),
          ]),
        ),
        if (rightActions != null) ...rightActions!,
      ],
    );
  }

  void _showApptSheet(BuildContext context) {
    final appts = context.read<AppointmentProvider>();
    final patients = context.read<PatientProvider>();
    final due = appts.dueNow(graceMinutes: 10);
    final upcoming = appts.upcomingWithin(withinMinutes: 60);
    final missed = appts.missed();

    String fmt(DateTime t) {
      final h = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
      final p = t.hour >= 12 ? 'PM' : 'AM';
      return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $p';
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                children: [
                  Text('Due now', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (due.isEmpty) const Text('No appointments due now')
                  else ...due.map((a) {
                    final p = patients.byId(a.patientId);
                    return ListTile(
                      leading: const Icon(Icons.alarm),
                      title: Text('${p?.name ?? 'Patient'} • ${fmt(a.dateTime)}'),
                      subtitle: Text(a.reason ?? ''),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(tooltip: 'Attended', icon: const Icon(Icons.check_circle_outline, color: Colors.green), onPressed: () { context.read<AppointmentProvider>().markAttended(a.id); }),
                        IconButton(tooltip: 'Missed', icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent), onPressed: () { context.read<AppointmentProvider>().markMissed(a.id); }),
                        IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () { context.read<AppointmentProvider>().remove(a.id); }),
                      ]),
                    );
                  }),
                  const Divider(height: 24),
                  Text('Upcoming (next 60 min)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (upcoming.isEmpty) const Text('No upcoming appointments')
                  else ...upcoming.map((a) {
                    final p = patients.byId(a.patientId);
                    return ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text('${p?.name ?? 'Patient'} • ${fmt(a.dateTime)}'),
                      subtitle: Text(a.reason ?? ''),
                    );
                  }),
                  const Divider(height: 24),
                  Text('Missed', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (missed.isEmpty) const Text('No missed appointments')
                  else ...missed.map((a) {
                    final p = patients.byId(a.patientId);
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text('${p?.name ?? 'Patient'} • ${fmt(a.dateTime)}'),
                      subtitle: Text(a.reason ?? ''),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: 'Reschedule',
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () async {
                          Navigator.pop(context);
                          // reuse reschedule flow
                          final current = a.dateTime;
                          DateTime? d = current;
                          TimeOfDay? t = TimeOfDay(hour: current.hour, minute: current.minute);
                          final now = DateTime.now();
                          final pd = await showDatePicker(context: context, initialDate: d, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 2));
                          if (pd == null) return;
                          final pt = await showTimePicker(context: context, initialTime: t);
                          if (pt == null) return;
                          final dt = DateTime(pd.year, pd.month, pd.day, pt.hour, pt.minute);
                          context.read<AppointmentProvider>().reschedule(a.id, dt);
                          },
                        ),
                        IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () { context.read<AppointmentProvider>().remove(a.id); }),
                      ]),
                    );
                  }),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _BottomIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showLabel;
  const _BottomIconButton({required this.icon, required this.label, required this.selected, required this.onTap, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: selected ? cs.primary.withOpacity(0.08) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: selected ? cs.primary : cs.outlineVariant.withOpacity(.6)),
              ),
              child: Icon(icon, color: color),
            ),
            if (showLabel) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: 68,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ================= Revenue & Expenses Panel =================
class _RevenueListPanel extends StatefulWidget {
  @override
  State<_RevenueListPanel> createState() => _RevenueListPanelState();
}

class _RevenueListPanelState extends State<_RevenueListPanel> {
  @override
  void initState() {
    super.initState();
    // Make sure dependent providers are loaded so we can map patientId -> name
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatientProvider>().ensureLoaded();
      context.read<RevenueProvider>().ensureLoaded();
    });
  }
  String _filter = 'all'; // all | income | expense
  DateTime? _from;
  DateTime? _to;
  String _periodMode = 'last12'; // last12 | month | year | range
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RevenueProvider>();
    var list = provider.entries.toList();
    // Apply time window based on period selection
    DateTime now = DateTime.now();
    DateTime start;
    DateTime end;
    switch (_periodMode) {
      case 'month':
        start = DateTime(_year, _month, 1);
        end = DateTime(_year, _month + 1, 1).subtract(const Duration(days: 1));
        break;
      case 'year':
        start = DateTime(_year, 1, 1);
        end = DateTime(_year, 12, 31);
        break;
      case 'range':
        start = _from ?? DateTime(now.year, now.month, 1);
        end = _to ?? DateTime(now.year, now.month + 1, 0);
        break;
      case 'last12':
      default:
        final d = DateTime(now.year, now.month, 1);
        start = DateTime(d.year, d.month - 11, 1);
        end = DateTime(d.year, d.month + 1, 0);
        break;
    }
    list = list.where((e) => !e.date.isBefore(start) && !e.date.isAfter(end)).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    if (_filter == 'income') {
      list = list.where((e) => e.amount > 0).toList();
    } else if (_filter == 'expense') {
      list = list.where((e) => e.amount < 0).toList();
    }
    final total = list.fold<double>(0, (p, e) => p + e.amount);
    final color = total >= 0 ? Colors.green : Colors.red;

  // Watch PatientProvider as well to rebuild when names load
  context.watch<PatientProvider>();
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Revenue & Expenses', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'income', child: Text('Income')),
                    DropdownMenuItem(value: 'expense', child: Text('Expenses')),
                  ],
                  onChanged: (v) => setState(() => _filter = v ?? 'all'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              // Period mode selector
              DropdownButton<String>(
                value: _periodMode,
                items: const [
                  DropdownMenuItem(value: 'last12', child: Text('Last 12 months')),
                  DropdownMenuItem(value: 'month', child: Text('Single month')),
                  DropdownMenuItem(value: 'year', child: Text('Single year')),
                  DropdownMenuItem(value: 'range', child: Text('Custom range')),
                ],
                onChanged: (v) => setState(() => _periodMode = v ?? 'last12'),
              ),
              if (_periodMode == 'month') ...[
                _monthPicker(), _yearPicker()
              ] else if (_periodMode == 'year') ...[
                _yearPicker()
              ] else if (_periodMode == 'range') ...[
                _fromPicker(), _toPicker()
              ],
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => _exportPdf(list, start: start, end: end),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export PDF'),
              )
              ,
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear all revenue entries?'),
                      content: const Text('This will permanently delete all revenue and expense entries.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear all')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await context.read<RevenueProvider>().clearAll();
                  }
                },
                icon: const Icon(Icons.delete_forever),
                label: const Text('Clear all'),
              )
            ])
          ],
        ),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Filtered total: ₹${total.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      ),
      const Divider(height: 1),
      Expanded(
        child: list.isEmpty
            ? const Center(child: Text('No entries'))
              : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = list[i];
                  final dateStr = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
                  final amtColor = e.amount >= 0 ? Colors.green : Colors.red;
                  final displayDesc = _prettyRevenueDescription(context, e);
                  return ListTile(
                    dense: true,
                    title: Text(displayDesc, maxLines: 1, overflow: TextOverflow.ellipsis),
                    // Show only date; hide internal UUIDs
                    subtitle: Text(dateStr),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${e.amount >= 0 ? '+' : ''}₹${e.amount.toStringAsFixed(0)}',
                          style: TextStyle(color: amtColor, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Delete entry',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete entry?'),
                                content: Text('Delete this ${e.amount >= 0 ? 'income' : 'expense'} entry from $dateStr (₹${e.amount.toStringAsFixed(0)})?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await context.read<RevenueProvider>().removeById(e.id);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry deleted')));
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  String _prettyRevenueDescription(BuildContext context, RevenueEntry e) {
    // Medicine profit entries → show "<Patient Name> (<ID>) - medicine"
    if (e.description.startsWith('Medicine profit:')) {
      final p = context.read<PatientProvider>().byId(e.patientId);
      if (p != null) return '${p.name} (${p.displayNumber}) - medicine';
      return e.description;
    }
    // Ledger clinic revenue entries include a tag like rx:<sessionId>:<subId>
    const prefix = 'Clinic revenue (ledger): ';
    if (e.description.startsWith(prefix)) {
      final tag = e.description.substring(prefix.length);
      final sessionId = _extractSessionId(tag);
      if (sessionId != null) {
        final patient = context.read<PatientProvider>().byId(e.patientId);
        if (patient != null) {
          final s = patient.sessions.where((s) => s.id == sessionId).cast<TreatmentSession?>().firstOrNull ??
              (patient.sessions.isNotEmpty ? patient.sessions.first : null);
          if (s != null) {
            final purpose = _sessionPurpose(s);
            return '${patient.name} (${patient.displayNumber}) - $purpose';
          }
        }
      }
    }
    return e.description;
  }

  String? _extractSessionId(String tag) {
    // tag format: rx:<sessionId>:<...>
    final idx = tag.indexOf('rx:');
    if (idx == -1) return null;
    final rest = tag.substring(idx + 3);
    final parts = rest.split(':');
    if (parts.isEmpty) return null;
    return parts.first;
  }

  String _sessionPurpose(TreatmentSession s) {
    switch (s.type) {
      case TreatmentType.general:
        // Prefer treatments done; fallback to first chief complaint
        if (s.treatmentsDone.isNotEmpty) {
          return _doneSummary(s.treatmentsDone);
        }
        final cc = s.chiefComplaint?.complaints;
        return (cc != null && cc.isNotEmpty) ? cc.first : 'General visit';
      case TreatmentType.orthodontic:
        return 'Orthodontic treatment';
      case TreatmentType.rootCanal:
        final sum = _planSummary(s.rootCanalPlans);
        return sum ?? 'Root canal treatment';
      case TreatmentType.prosthodontic:
        final sum = _planSummary(s.prosthodonticPlans);
        return sum ?? 'Prosthodontic treatment';
      case TreatmentType.labWork:
        return 'Lab work';
    }
  }

  String _doneSummary(List<ToothTreatmentDoneEntry> done) {
    final items = <String>[];
    for (final d in done.take(2)) {
      final tooth = d.toothNumber.isNotEmpty ? '${d.toothNumber}: ' : '';
      items.add('$tooth${d.treatment}');
    }
    var s = items.join(', ');
    if (done.length > 2) s += ' …';
    return s.isEmpty ? 'General treatment' : s;
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

  Widget _monthPicker() {
    return DropdownButton<int>(
      value: _month,
      items: [for (int m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(_monthName(m)))],
      onChanged: (v) => setState(() => _month = v ?? _month),
    );
  }
  Widget _yearPicker() {
    final now = DateTime.now().year;
    return DropdownButton<int>(
      value: _year,
      items: [for (int y = now - 10; y <= now; y++) DropdownMenuItem(value: y, child: Text('$y'))],
      onChanged: (v) => setState(() => _year = v ?? _year),
    );
  }
  Widget _fromPicker() {
    return OutlinedButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final d = await showDatePicker(context: context, initialDate: _from ?? now, firstDate: DateTime(now.year - 10), lastDate: DateTime(now.year + 1));
        if (d != null) setState(() => _from = d);
      },
      icon: const Icon(Icons.date_range),
      label: Text(_from == null ? 'From' : '${_from!.year}-${_from!.month.toString().padLeft(2, '0')}-${_from!.day.toString().padLeft(2, '0')}'),
    );
  }
  Widget _toPicker() {
    return OutlinedButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final d = await showDatePicker(context: context, initialDate: _to ?? now, firstDate: DateTime(now.year - 10), lastDate: DateTime(now.year + 1));
        if (d != null) setState(() => _to = d);
      },
      icon: const Icon(Icons.event),
      label: Text(_to == null ? 'To' : '${_to!.year}-${_to!.month.toString().padLeft(2, '0')}-${_to!.day.toString().padLeft(2, '0')}'),
    );
  }

  String _monthName(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[(m - 1) % 12];
  }

  Future<void> _exportPdf(List<RevenueEntry> list, {required DateTime start, required DateTime end}) async {
    // Basic PDF export using printing + pw (already imported in file)
  final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) {
          final title = 'Revenue & Expenses ${start.year}-${start.month.toString().padLeft(2, '0')} to ${end.year}-${end.month.toString().padLeft(2, '0')}';
          return [
            pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['Date','Description','Amount'],
              data: [
                for (final e in list)
                  [
                    '${e.date.year}-${e.date.month.toString().padLeft(2,'0')}-${e.date.day.toString().padLeft(2,'0')}',
                    e.description,
                    '${e.amount >= 0 ? '+' : ''}₹${e.amount.toStringAsFixed(0)}',
                  ]
              ],
            )
          ];
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  // Animated revenue chart card
}

// Removed revenue chart card (simplified revenue view per request)

// Attendance overview widget (read-only calendar) used in overview section
class _AttendanceOverviewWidget extends StatefulWidget {
  @override
  State<_AttendanceOverviewWidget> createState() => _AttendanceOverviewWidgetState();
}

class _AttendanceOverviewWidgetState extends State<_AttendanceOverviewWidget> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _staff;




  String _monthLabel(DateTime m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[m.month - 1]} ${m.year}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StaffAttendanceProvider>();
    return LayoutBuilder(builder: (context, c) {
      // We'll scale down the inner content if height is constrained to avoid overflow.
      final maxH = c.maxHeight.isFinite ? c.maxHeight : double.infinity;
      // Build original content first
      final built = _buildCore(provider);
      // Measure an estimated natural height (calendar height depends on weeks; we approximate by intrinsic).
      // Simpler: wrap in FittedBox vertically if not enough space.
      if (maxH != double.infinity) {
        // We attempt a rough height by using a LayoutBuilder again inside (not perfect but acceptable for scaling trigger)
        // Instead of complex measurement, we rely on Overflow only when less than threshold, apply Transform.scale.
        // For reliability provide a SingleChildScrollView fallback if extremely small.
        return OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          maxWidth: c.maxWidth,
          child: built,
        );
      }
      return built;
    });
  }

  Widget _buildCore(StaffAttendanceProvider provider) {
    return LayoutBuilder(builder: (context, constraints) {
      final staffNames = provider.staffNames;
      if (_staff == null && staffNames.isNotEmpty) _staff = staffNames.first;
      final selected = _staff;
      
      // Calculate available height for content
      final availableHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 400.0;
      final availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
      
      // Scale content to fit available space
      final content = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title removed to avoid duplication with outer panel
            // Staff selector with horizontal scroll
            SizedBox(
              height: 40,
              child: staffNames.isEmpty 
                ? const Text('No staff added')
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: staffNames.map((s) {
                        final sel = s == selected;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s, style: const TextStyle(fontSize: 12)),
                            selected: sel,
                            onSelected: (_) => setState(() => _staff = s),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
            ),
            const SizedBox(height: 8),
            if (selected == null)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Add staff to view attendance'),
              )
            else ...[
              _weekdayHeaderCompact(),
              const SizedBox(height: 4),
              _compactCalendar(provider, selected),
              const SizedBox(height: 6),
              // Compact month navigation
              SizedBox(
                height: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Previous Month',
                      icon: const Icon(Icons.chevron_left, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _monthLabel(_month),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Next Month',
                      icon: const Icon(Icons.chevron_right, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _legendRow(),
            ],
          ],
        ),
      );
      
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: availableWidth.clamp(240, 560),
          height: availableHeight,
          child: content,
        ),
      );
    });
  }

  Widget _legendBox(Color c, String label)=> Row(mainAxisSize: MainAxisSize.min,children:[
    Container(width:14,height:14,decoration: BoxDecoration(color: c,borderRadius: BorderRadius.circular(3))),
    const SizedBox(width:4),
    Text(label, style: const TextStyle(fontSize: 11))
  ]);

  Widget _legendRow(){
    return Wrap(spacing: 10, children: [
      _legendBox(Colors.green.shade400,'Present'),
      _legendBox(Colors.red.shade400,'Absent'),
      _legendBox(Colors.grey.shade200,'None'),
    ]);
  }

  Widget _compactCalendar(StaffAttendanceProvider provider, String staff){
    // Dynamically size cells based on available panel width/height to avoid overflow.
    return LayoutBuilder(builder: (context, c) {
      // Target min & max sizes
      const double minCell = 16;
      const double maxCell = 30;
      const double baseGap = 2;
      final year = _month.year;
      final month = _month.month;
      final first = DateTime(year, month, 1);
      final offset = (first.weekday + 6) % 7; // Monday=0
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final totalSlots = offset + daysInMonth;
      final weeks = (totalSlots / 7).ceil();

      // Available height minus header + nav + legend approximations (we only care when constrained)
      final availH = c.maxHeight.isFinite ? c.maxHeight : double.infinity;
      double cellFromHeight;
      if (availH.isFinite) {
        final reservedTop = 80.0; // chips + weekday row approximate
        final reservedBottom = 70.0; // nav + legend approx
        final usable = (availH - reservedTop - reservedBottom).clamp(60, 600);
        cellFromHeight = (usable / weeks) - baseGap;
      } else {
        cellFromHeight = maxCell;
      }
      final availW = c.maxWidth.isFinite ? c.maxWidth : 400;
      final cellFromWidth = (availW / 7) - baseGap * .8;
      double cell = [cellFromHeight, cellFromWidth, maxCell].reduce((a,b)=> a < b ? a : b); // choose the smallest among height/width and cap
      cell = cell.clamp(minCell, maxCell);
      final gap = (cell <= 18) ? 1.0 : baseGap;
      final fontSize = cell * 0.38 + 4; // scale text
      final dayFont = fontSize.clamp(8, 14);

      int day = 1;
      List<Widget> rows = [];
      for (int w = 0; w < weeks; w++) {
        List<Widget> cells = [];
        for (int d = 0; d < 7; d++) {
          final slot = w * 7 + d;
          Widget inner;
          if (slot < offset || day > daysInMonth) {
            inner = const SizedBox.shrink();
          } else {
            final date = DateTime(year, month, day);
            final split = provider.stateForSplit(staff, date);
            final morning = split[0];
            final evening = split[1];
            final status = (morning == true && evening == true)
                ? 'Present'
                : (morning == false && evening == false)
                    ? 'Absent'
                    : 'Half-day';
            inner = Tooltip(
              message: status,
              waitDuration: const Duration(milliseconds: 250),
              child: Center(
                child: SizedBox(
                  width: cell,
                  height: cell,
                  child: Stack(alignment: Alignment.center, children: [
                    HalfDayTile(morning: morning, evening: evening, size: cell, radius: cell * 0.15, noneColor: Colors.grey.shade200),
                    Text('$day', style: TextStyle(fontSize: dayFont.toDouble(), fontWeight: FontWeight.w600, color: (morning == false && evening == false) ? Colors.white : Colors.black87)),
                  ]),
                ),
              ),
            );
            day++;
          }
          cells.add(SizedBox(width: cell, height: cell, child: inner));
        }
        rows.add(Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (int i=0;i<cells.length;i++) Padding(padding: EdgeInsets.only(right: i==6?0:gap), child: cells[i])],
        ));
        if (w != weeks-1) rows.add(SizedBox(height: gap));
      }
      return rows.isEmpty ? const SizedBox() : SizedBox(
        height: weeks * cell + (weeks-1) * gap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: rows),
      );
    });
  }
  Widget _weekdayHeaderCompact(){
    return LayoutBuilder(builder: (context, c) {
      const double maxCell = 26;
      const double minCell = 16;
      final cell = ((c.maxWidth / 7) - 2).clamp(minCell, maxCell);
      final gap = cell <= 18 ? 1.0 : 2.0;
    const labels = ['M','T','W','T','F','S','S'];
      return SizedBox(
        height: cell,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i=0;i<labels.length;i++) Padding(
              padding: EdgeInsets.only(right: i==labels.length-1?0:gap),
              child: SizedBox(
                width: cell,
                height: cell,
                child: Center(child: Text(labels[i], style: TextStyle(fontSize: cell * 0.42 + 4, fontWeight: FontWeight.bold))),
              ),
            )
          ],
        ),
      );
    });
  }
}

class _DashCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final double width;
  final Color? valueColor;
  final ImageProvider? overlayImage;
  final double minHeight;

  _DashCard({required this.title, required this.value, required this.icon, this.width = 180, this.valueColor, this.overlayImage, this.minHeight = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: LayoutBuilder(builder: (context, c) {
        final effectiveH = c.hasBoundedHeight && c.maxHeight.isFinite ? c.maxHeight : minHeight;
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight, minWidth: c.maxWidth),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  width: effectiveH * 0.62,
                  height: effectiveH * 0.62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 8, offset: const Offset(0,2))],
                  ),
                  child: overlayImage != null
                      ? ClipOval(
                          child: Image(
                            image: overlayImage!,
                            fit: BoxFit.cover,
                            // If the image fails to load (missing asset), show the default revenue icon or an Icon.
                            errorBuilder: (context, error, stackTrace) {
                              // try fallback asset
                              return ClipOval(
                                child: Image.asset(
                                  'assets/images/revenue_icon.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary.withOpacity(.08)),
                                    child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: effectiveH * 0.28),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary.withOpacity(.08)),
                          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: effectiveH * 0.28),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: effectiveH * 0.10, color: Colors.black87)),
                    const SizedBox(height: 8),
                    Text(value, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: minHeight * 0.16,)),
                  ]),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

class _DashMetricCard extends StatefulWidget {
  final String title;
  final double value;
  final String? subtitle;
  final IconData icon;
  final int appearDelayMs;
  final Color? valueColor;
  const _DashMetricCard({Key? key, required this.title, required this.value, required this.icon, this.subtitle, this.appearDelayMs = 0, this.valueColor}) : super(key: key);

  @override
  State<_DashMetricCard> createState() => _DashMetricCardState();
}

class _DashMetricCardState extends State<_DashMetricCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _countAnim;
  bool _hovered = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _countAnim = Tween<double>(begin: 0, end: widget.value).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    if (widget.appearDelayMs > 0) {
      Future.delayed(Duration(milliseconds: widget.appearDelayMs), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _DashMetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _countAnim = Tween<double>(begin: _countAnim.value, end: widget.value).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accentColor = cs.primary;
    final surface = cs.surface;
    final translate = _pressed ? Offset(0, 0) : (_hovered ? const Offset(0, -2) : Offset.zero);
    final scale = _pressed ? 0.98 : (_hovered ? 1.02 : 1.0);
    final effScale = _pressed ? 0.94 : (_hovered ? 1.04 : 1.0);
    final iconSize = 20.0 * effScale;
    String _shortNumber(double v) {
      if (v.abs() >= 100000) {
        final val = (v / 100000).toStringAsFixed(v % 100000 == 0 ? 0 : 1);
        return '${val}L';
      }
      if (v.abs() >= 1000) {
        final val = (v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1);
        return '${val}k';
      }
      return v.toStringAsFixed(0);
    }
    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()
        ..translate(translate.dx, translate.dy)
        ..scale(scale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [surface, surface.withOpacity(.96)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 12, offset: const Offset(0, 6)),
          BoxShadow(color: cs.primary.withOpacity(.03), blurRadius: 4, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: cs.outlineVariant.withOpacity(.22)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40 * effScale,
            height: 40 * effScale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [accentColor.withOpacity(.25), accentColor.withOpacity(.08)]),
              border: Border.all(color: accentColor.withOpacity(.35)),
            ),
            child: Icon(widget.icon, color: accentColor, size: iconSize),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: _countAnim,
            builder: (_, __) {
              final v = _countAnim.value;
              final isInt = widget.title == 'Patients';
              final text = isInt ? v.toInt().toString() : '₹${_shortNumber(v)}';
              // Smaller numeric font that scales with effective height
              final numStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: widget.valueColor ?? accentColor, fontSize: 18 * (effScale));
              return FittedBox(
                alignment: Alignment.center,
                child: Text(text, style: numStyle),
              );
            },
          ),
          const SizedBox(height: 4),
          Align(alignment: Alignment.center, child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 2),
            Align(alignment: Alignment.center, child: Text(widget.subtitle!, style: TextStyle(fontSize: 10, color: Colors.grey.shade600))),
          ]
        ],
      ),
    );
    // Use fixed sized metric tiles for consistency.
    card = SizedBox(width: 160, height: 160, child: card);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: card,
      ),
    );
  }
}

// Wrapper widget for patient overview using person icon as placeholder
class _PatientOverviewCardWrapper extends StatelessWidget {
  final String? subtitle;
  const _PatientOverviewCardWrapper({this.subtitle});

  @override
  Widget build(BuildContext context) {
    // Use null avatar to trigger icon fallback in PatientOverviewCard
    return PatientOverviewCard(
  avatar: const AssetImage('assets/images/patient_avatar.png'),  // Change from null
  subtitle: subtitle,
);
  }
}

class _LargePanel extends StatefulWidget {
  final String title;
  final Widget child;
  const _LargePanel({required this.title, required this.child});

  @override
  State<_LargePanel> createState() => _LargePanelState();
}

class _LargePanelState extends State<_LargePanel> {
  bool _hovered = false;
  bool _pressed = false;
  double _tiltX = 0; // rotation around X (looking up/down)
  double _tiltY = 0; // rotation around Y (looking left/right)

  void _updateTilt(PointerHoverEvent e) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final pos = box.globalToLocal(e.position);
    // Normalize to -1..1 around center
    final dx = (pos.dx / size.width) * 2 - 1; // left -1, right +1
    final dy = (pos.dy / size.height) * 2 - 1; // top -1, bottom +1
    // Limit and invert dy for natural tilt
    const maxTilt = 0.08; // radians (~4.5 deg)
    setState(() {
      _tiltY = (dx.clamp(-1.0, 1.0)) * maxTilt;
      _tiltX = (-dy.clamp(-1.0, 1.0)) * maxTilt;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surface = cs.surface;
    final translateY = _pressed ? 0.0 : (_hovered ? -2.0 : 0.0);
    final shadowOpacity = _pressed ? .02 : (_hovered ? .14 : .06);
    final Matrix4 mtx = Matrix4.identity()
      ..setEntry(3, 2, 0.0015) // perspective
      ..rotateX(_pressed ? 0 : _tiltX)
      ..rotateY(_pressed ? 0 : _tiltY)
      ..translate(0.0, translateY);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() { _hovered = false; _pressed = false; _tiltX = 0; _tiltY = 0; }),
      onHover: _updateTilt,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: Transform(
          alignment: Alignment.center,
          transform: mtx,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget is _RadiusLargePanel ? (widget as _RadiusLargePanel).radius : 20),
              gradient: LinearGradient(
                colors: [surface, surface.withOpacity(.96)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                // Stronger elevation when hovered
                BoxShadow(color: Colors.black.withOpacity(shadowOpacity), blurRadius: 22, offset: const Offset(0, 14)),
                BoxShadow(color: cs.primary.withOpacity(_hovered ? .08 : .04), blurRadius: 8, offset: const Offset(0, 3)),
              ],
              border: Border.all(color: cs.outlineVariant.withOpacity(.25)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Stack(children: [
              // Content
              LayoutBuilder(builder: (context, c) {
                final hasHeader = widget.title.trim().isNotEmpty;
                final header = hasHeader
                    ? Row(children: [
                        Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                      ])
                    : const SizedBox.shrink();
                final body = ClipRect(child: widget.child);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (hasHeader) header,
                  if (hasHeader) const SizedBox(height: 8),
                  body,
                ]);
              }),
              // Specular highlight overlay on hover for 3D sheen
              if (_hovered)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget is _RadiusLargePanel ? (widget as _RadiusLargePanel).radius : 20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.08),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

extension _PanelRadius on _LargePanel {
  _LargePanel withRadius(double r) {
    return _RadiusLargePanel(title: title, child: child, radius: r);
  }
}

class _RadiusLargePanel extends _LargePanel {
  final double radius;
  const _RadiusLargePanel({required super.title, required super.child, this.radius = 20});
}

// Simple appear animation wrapper
// ignore: avoid_unused_constructor_parameters
class _StaggeredAppear extends StatefulWidget {
  final Widget child;
  const _StaggeredAppear({required this.child});

  @override
  State<_StaggeredAppear> createState() => _StaggeredAppearState();
}

class _StaggeredAppearState extends State<_StaggeredAppear> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _opacity = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _offset = Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero).animate(_c);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

// Doctors on Duty compact panel
// Removed _DoctorsOnDutyPanel per request.

// Splitter used for adjustable column widths (and optional vertical drag)
// Removed legacy splitter widget used by the old adjustable layout.

// ================= Utility payments history panel =================
class _UtilityPaymentsHistoryPanel extends StatefulWidget {
  @override
  State<_UtilityPaymentsHistoryPanel> createState() => _UtilityPaymentsHistoryPanelState();
}

// ================= Bills history panel =================
class _BillsHistoryPanel extends StatefulWidget {
  @override
  State<_BillsHistoryPanel> createState() => _BillsHistoryPanelState();
}

class _BillsHistoryPanelState extends State<_BillsHistoryPanel> {
  String _mode = 'recent';
  final Set<String> _selected = {};
  String _categoryFilter = 'all';
  // Analytics controls
  String _analyticsPeriod = 'month'; // 'month' | 'year'
  int _analyticsYear = DateTime.now().year;
  int _analyticsMonth = DateTime.now().month;

  List<int> _years(List bills) {
    final st = <int>{};
    for (final b in bills) st.add(b.date.year as int);
    final list = st.toList();
    list.sort((a, b) => b.compareTo(a));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final util = context.watch<UtilityProvider>();
    var list = util.bills.toList()..sort((a, b) => b.date.compareTo(a.date));
    if (_categoryFilter != 'all') list = list.where((b) => b.category == _categoryFilter).toList();
    final years = _years(list);
    if (_mode != 'recent') {
      final y = int.tryParse(_mode);
      if (y != null) list = list.where((e) => e.date.year == y).toList();
    } else {
      list = list.take(12).toList();
    }
    // Analytics compute
    Map<String, double> analyticsTotals = {
      'Consumables': 0,
      'Equipment': 0,
      'Maintenance': 0,
      'Other': 0,
    };
    Iterable billsForAnalytics = util.bills;
    if (_analyticsPeriod == 'year') {
      billsForAnalytics = billsForAnalytics.where((b) => b.date.year == _analyticsYear);
    } else {
      billsForAnalytics = billsForAnalytics.where((b) => b.date.year == _analyticsYear && b.date.month == _analyticsMonth);
    }
    for (final b in billsForAnalytics) {
      final key = analyticsTotals.containsKey(b.category) ? b.category : 'Other';
      analyticsTotals[key] = (analyticsTotals[key] ?? 0) + (b.amount as double);
    }

    return SingleChildScrollView(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(children: [
            const Text('Bills History', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _categoryFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Categories')),
                  DropdownMenuItem(value: 'Consumables', child: Text('Consumables')),
                  DropdownMenuItem(value: 'Equipment', child: Text('Equipment')),
                  DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _categoryFilter = v ?? 'all'),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _mode,
                items: [
                  const DropdownMenuItem(value: 'recent', child: Text('Recent 12 months')),
                  ...years.map((y) => DropdownMenuItem(value: y.toString(), child: Text(y.toString())))
                ],
                onChanged: (v) => setState(() => _mode = v ?? 'recent'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _selected.isEmpty ? null : () async {
                await context.read<UtilityProvider>().deleteBills(_selected.toList());
                setState(() => _selected.clear());
              },
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Delete Selected'),
            ),
          ]),
        ),
        // Analytics bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Category analytics:'),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _analyticsPeriod,
                  items: const [
                    DropdownMenuItem(value: 'month', child: Text('Month')),
                    DropdownMenuItem(value: 'year', child: Text('Year')),
                  ],
                  onChanged: (v) => setState(() => _analyticsPeriod = v ?? 'month'),
                ),
              ),
              const SizedBox(width: 8),
              if (_analyticsPeriod == 'month') ...[
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _analyticsMonth,
                    items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text('M$m'))).toList(),
                    onChanged: (v) => setState(() => _analyticsMonth = v ?? DateTime.now().month),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _analyticsYear,
                  items: (years.isEmpty ? [DateTime.now().year] : years).map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                  onChanged: (v) => setState(() => _analyticsYear = v ?? DateTime.now().year),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _CategoryTotalChip(label: 'Consumables', amount: analyticsTotals['Consumables'] ?? 0),
              _CategoryTotalChip(label: 'Equipment', amount: analyticsTotals['Equipment'] ?? 0),
              _CategoryTotalChip(label: 'Maintenance', amount: analyticsTotals['Maintenance'] ?? 0),
              _CategoryTotalChip(label: 'Other', amount: analyticsTotals['Other'] ?? 0),
              _CategoryTotalChip(label: 'Total', amount: analyticsTotals.values.fold<double>(0, (a, b) => a + b)),
            ])
          ]),
        ),
        const Divider(height: 1),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('No bills')),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final b = list[i];
              final dateStr = '${b.date.year}-${b.date.month.toString().padLeft(2, '0')}-${b.date.day.toString().padLeft(2, '0')}';
              return ListTile(
                dense: true,
                leading: Checkbox(
                  value: _selected.contains(b.id),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(b.id);
                      } else {
                        _selected.remove(b.id);
                      }
                    });
                  },
                ),
                title: Text('${b.itemName} • ₹${b.amount.toStringAsFixed(0)}'),
                subtitle: Text('Date: $dateStr • Category: ${b.category}${b.receiptPath != null ? ' • Receipt: ${b.receiptPath}' : ''}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (b.receiptPath != null && b.receiptPath!.isNotEmpty)
                    IconButton(
                      tooltip: 'Open receipt',
                      icon: const Icon(Icons.visibility),
                      onPressed: () async {
                        try {
                          await OpenFilex.open(b.receiptPath!);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not open receipt: $e')),
                            );
                          }
                        }
                      },
                    ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        await _showEditBillDialog(b);
                      } else if (v == 'delete') {
                        await context.read<UtilityProvider>().deleteBill(b.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ]),
              );
            },
          ),
      ]),
    );
  }

  Future<void> _showEditBillDialog(b) async {
    final itemCtrl = TextEditingController(text: b.itemName);
    final amountCtrl = TextEditingController(text: b.amount.toStringAsFixed(0));
  final receiptCtrl = TextEditingController(text: b.receiptPath ?? '');
    DateTime date = b.date;
    String category = b.category;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('Edit Bill'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Text('Purchase date:'),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 1));
                    if (picked != null) setSt(() => date = picked);
                  },
                  child: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
                )
              ]),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'Consumables', child: Text('Consumables')),
                  DropdownMenuItem(value: 'Equipment', child: Text('Equipment')),
                  DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setSt(() => category = v ?? category),
              ),
              const SizedBox(height: 8),
              TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'Item name / purpose')),
              const SizedBox(height: 8),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost of purchase')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: receiptCtrl, decoration: const InputDecoration(labelText: 'Receipt (path or note)'))),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Pick file',
                  icon: const Icon(Icons.attach_file),
                  onPressed: () async {
                    final res = await FilePicker.platform.pickFiles(withReadStream: false);
                    if (res != null && res.files.isNotEmpty) {
                      final path = res.files.single.path;
                      if (path != null) setSt(() => receiptCtrl.text = path);
                    }
                  },
                ),
                if (receiptCtrl.text.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Open receipt',
                    icon: const Icon(Icons.visibility),
                    onPressed: () async {
                      final path = receiptCtrl.text;
                      await openReceiptWithFallback(context, path);
                    },
                  )
                ]
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = itemCtrl.text.trim();
                final amt = double.tryParse(amountCtrl.text) ?? 0;
                if (name.isEmpty || amt <= 0) return;
                final updated = BillEntry(id: b.id, date: date, itemName: name, amount: amt, receiptPath: receiptCtrl.text.trim().isEmpty ? null : receiptCtrl.text.trim(), category: category);
                await context.read<UtilityProvider>().updateBill(updated);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            )
          ],
        ),
      ),
    );
  }

}

class _CategoryTotalChip extends StatelessWidget {
  final String label;
  final double amount;
  const _CategoryTotalChip({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    final text = '₹${amount.toStringAsFixed(0)}';
    return Chip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
      ]),
      avatar: const Icon(Icons.category, size: 18),
    );
  }
}

// Opens a receipt file path using OpenFilex; if the platform plugin isn't available
// or opening fails, falls back to a simple in-app preview for images/PDFs when possible.
Future<void> openReceiptWithFallback(BuildContext context, String path) async {
  try {
    await OpenFilex.open(path);
    return;
  } on MissingPluginException catch (_) {
    // Fall through to preview
  } catch (e) {
    // Try preview if supported
  }

  final lower = path.toLowerCase();
  if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.gif') || lower.endsWith('.bmp') || lower.endsWith('.webp')) {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: Image.file(
            // ignore: deprecated_member_use
            File(path),
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Could not load image.'),
            ),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
    return;
  }

  if (lower.endsWith('.pdf')) {
    // Use printing's built-in PdfPreview via a minimal wrapper
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 800,
          height: 600,
          child: PdfPreview(
            allowPrinting: false,
            allowSharing: false,
            build: (format) async {
              try {
                // ignore: deprecated_member_use
                final bytes = await File(path).readAsBytes();
                return bytes;
              } catch (_) {
                return Uint8List(0);
              }
            },
          ),
        ),
      ),
    );
    return;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open receipt on this device.')),
    );
  }
}

class _UtilityPaymentsHistoryPanelState extends State<_UtilityPaymentsHistoryPanel> {
  String _mode = 'recent'; // recent or YYYY

  List<int> _availableYears(List payments) {
    final years = <int>{};
    for (final p in payments) {
      years.add(p.date.year as int);
    }
    final list = years.toList();
    list.sort((a, b) => b.compareTo(a));
    return list;
  }

  Future<void> _exportPdf(List entries, Map<String, String> serviceNames) async {
    final doc = pw.Document();
    final rows = <pw.TableRow>[];
    rows.add(pw.TableRow(children: [
      _pdfHeader('Date'), _pdfHeader('Service'), _pdfHeader('Amount'), _pdfHeader('Mode'), _pdfHeader('Paid')
    ]));
    for (final e in entries) {
      final dateStr = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
      rows.add(pw.TableRow(children: [
        _pdfCell(dateStr),
        _pdfCell(serviceNames[e.serviceId] ?? e.serviceId),
        _pdfCell('₹${e.amount.toStringAsFixed(0)}'),
        _pdfCell(e.mode ?? '—'),
        _pdfCell(e.paid ? 'Yes' : 'No'),
      ]));
    }
    doc.addPage(pw.MultiPage(build: (_) => [
      pw.Text('Utility Payments', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Table(border: pw.TableBorder.all(width: .5), children: rows)
    ]));
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  pw.Widget _pdfHeader(String t) => pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
  pw.Widget _pdfCell(String t) => pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(t));

  @override
  Widget build(BuildContext context) {
    final util = context.watch<UtilityProvider>();
    final services = {for (final s in util.services) s.id: s.name};
    var entries = util.payments.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final years = _availableYears(entries);
    if (_mode != 'recent') {
      final y = int.tryParse(_mode);
      if (y != null) {
        entries = entries.where((e) => e.date.year == y).toList();
      }
    } else {
      entries = entries.take(12).toList(); // recent 12
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(children: [
          const Text('Payments History', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _mode,
              items: [
                const DropdownMenuItem(value: 'recent', child: Text('Recent 12 months')),
                ...years.map((y) => DropdownMenuItem(value: y.toString(), child: Text(y.toString())))
              ],
              onChanged: (v) => setState(() => _mode = v ?? 'recent'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: entries.isEmpty ? null : () => _exportPdf(entries, services),
          )
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: entries.isEmpty
            ? const Center(child: Text('No payments'))
            : ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = entries[i];
                  final dateStr = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
                  return ListTile(
                    dense: true,
                    title: Text('${services[e.serviceId] ?? e.serviceId} • ₹${e.amount.toStringAsFixed(0)}'),
                    subtitle: Text('Date: $dateStr • Mode: ${e.mode ?? '—'} • Paid: ${e.paid ? 'Yes' : 'No'}'),
                  );
                },
              ),
      )
    ]);
  }
}

// Reusable phone field with WhatsApp and Call actions
class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onWhatsApp;
  final VoidCallback onCall;
  const _PhoneField({required this.controller, required this.label, required this.onWhatsApp, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: label),
        ),
      ),
      const SizedBox(width: 8),
      Tooltip(
        message: 'WhatsApp',
        child: IconButton(
          icon: Icon(Icons.chat, color: const Color(0xFF25D366)),
          onPressed: onWhatsApp,
        ),
      ),
      Tooltip(
        message: 'Call',
        child: IconButton(
          icon: const Icon(Icons.call_outlined),
          onPressed: onCall,
        ),
      ),
    ]);
  }
}
