import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/revenue_provider.dart';
import 'add_patient_page.dart';
import 'patient_list_page.dart';

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
  revenue('Revenue', Icons.currency_rupee),
  addClinic('Add Clinic', Icons.add_business_outlined),
  staffAttendance('Staff Attendance', Icons.badge_outlined),
  doctorsAttendance('Doctors Attendance', Icons.medical_services_outlined),
  inventory('Inventory', Icons.inventory_2_outlined),
  settings('Settings', Icons.settings_outlined);

  final String label;
  final IconData icon;
  const DashboardSection(this.label, this.icon);
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardSection _section = DashboardSection.overview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _buildSideMenu(),
            const VerticalDivider(width: 1),
            Expanded(child: _buildSectionContent())
          ],
        ),
      ),
    );
  }

  Widget _buildSideMenu() {
    return Container(
      width: 230,
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16,16,16,8),
            child: Text('Main Menu', style: Theme.of(context).textTheme.titleMedium),
          ),
          ...DashboardSection.values.map((s) => _menuTile(s)).toList(),
        ],
      ),
    );
  }

  Widget _menuTile(DashboardSection s) {
    final selected = s == _section;
    return ListTile(
      leading: Icon(s.icon, color: selected ? Theme.of(context).colorScheme.primary : null),
      title: Text(s.label, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
      selected: selected,
      onTap: () => setState(() => _section = s),
    );
  }

  Widget _buildSectionContent() {
    switch (_section) {
      case DashboardSection.overview:
        return _overviewSection();
      case DashboardSection.managePatients:
        return _managePatientsSection();
      case DashboardSection.revenue:
        return _revenueSection();
      case DashboardSection.addClinic:
        return _addClinicSection();
      case DashboardSection.staffAttendance:
        return _staffAttendanceSection();
      case DashboardSection.doctorsAttendance:
        return _doctorsAttendanceSection();
      case DashboardSection.inventory:
        return _inventorySection();
      case DashboardSection.settings:
        return _settingsSection();
    }
  }

  // ================= Overview =================
  Widget _overviewSection() {
    final patientProvider = context.watch<PatientProvider>();
    final revenueProvider = context.watch<RevenueProvider>();
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Wrap(spacing: 16, runSpacing: 16, children: [
              _DashCard(title: 'Appointments (Today)', value: '—', icon: Icons.event_available, width: 200),
              _DashCard(title: 'Total Patients', value: patientProvider.patients.length.toString(), icon: Icons.people, width: 200),
              _DashCard(title: 'Total Revenue', value: '₹${revenueProvider.total.toStringAsFixed(0)}', icon: Icons.account_balance, width: 200),
              _DashCard(title: "Today's Revenue", value: '₹${todaysRevenue.toStringAsFixed(0)}', icon: Icons.today, width: 200),
              _DashCard(title: 'Monthly Revenue', value: '₹${monthlyRevenue.toStringAsFixed(0)}', icon: Icons.calendar_month, width: 220),
              _DashCard(title: 'Clinic Inventory', value: '—', icon: Icons.inventory_2, width: 200),
            ]),
            const SizedBox(height: 24),
            _LargePanel(
              title: 'Staff Attendance (Today)',
              child: const Center(child: Text('Attendance summary placeholder')),
            ),
          ],
        ),
      ),
    );
  }

  // ============== Manage Patients ==============
  Widget _managePatientsSection() {
    final patientProvider = context.watch<PatientProvider>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manage Patients', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Row(children: [
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(AddPatientPage.routeName),
              icon: const Icon(Icons.person_add),
              label: const Text('Add Patient'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(PatientListPage.routeName),
              icon: const Icon(Icons.people_outline),
              label: const Text('All Patients'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_alarm),
              label: const Text('Add Appointment'),
            ),
          ]),
          const SizedBox(height: 24),
          Text('Total Patients: ${patientProvider.patients.length}'),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search patient (placeholder)'),
            onChanged: (v) {},
          ),
          const SizedBox(height: 24),
          Expanded(child: Center(child: Text("Today's Appointments placeholder"))),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Revenue', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Wrap(spacing: 16, runSpacing: 16, children: [
          _DashCard(title: "Today's Revenue", value: '₹${todaysRevenue.toStringAsFixed(0)}', icon: Icons.today, width: 200),
          _DashCard(title: 'Monthly Revenue', value: '₹${monthlyRevenue.toStringAsFixed(0)}', icon: Icons.calendar_month, width: 200),
          _DashCard(title: 'Total Revenue', value: '₹${revenueProvider.total.toStringAsFixed(0)}', icon: Icons.account_balance_wallet, width: 220),
        ]),
        const SizedBox(height: 24),
        ElevatedButton.icon(
            onPressed: () {}, icon: const Icon(Icons.receipt_long), label: const Text('Detailed Revenue Report (placeholder)')),
        const SizedBox(height: 24),
        Expanded(child: Center(child: Text('Revenue chart / table placeholder')))
      ]),
    );
  }

  // ============== Add Clinic ==============
  Widget _addClinicSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Add / Manage Clinics', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        TextField(decoration: const InputDecoration(labelText: 'Clinic Name')),
        TextField(decoration: const InputDecoration(labelText: 'Address')),
        const SizedBox(height: 12),
        ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.save), label: const Text('Register Clinic')),
        const SizedBox(height: 24),
        Expanded(child: Center(child: Text('Clinics list placeholder')))
      ]),
    );
  }

  // ============== Staff Attendance ==============
  Widget _staffAttendanceSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Staff Attendance', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Row(children: [
          ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.playlist_add_check), label: const Text('Mark Attendance')),
          const SizedBox(width: 12),
          ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.summarize), label: const Text('Monthly Summary')),
        ]),
        const SizedBox(height: 24),
        Expanded(child: Center(child: Text('Staff attendance table placeholder')))
      ]),
    );
  }

  // ============== Doctors Attendance ==============
  Widget _doctorsAttendanceSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Doctors Attendance & Payments', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Expanded(child: Center(child: Text('Doctors attendance / payment tracker placeholder')))
      ]),
    );
  }

  // ============== Inventory ==============
  Widget _inventorySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Clinic Inventory & Lab Costs', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Row(children: [
          ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Add Item')),
          const SizedBox(width: 12),
          ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.biotech), label: const Text('Add Lab Cost')),
        ]),
        const SizedBox(height: 24),
        Expanded(child: Center(child: Text('Inventory & lab cost list placeholder')))
      ]),
    );
  }

  // ============== Settings ==============
  Widget _settingsSection() {
    return Center(child: Text('Settings placeholder'));
  }
}

// ================= Reusable Widgets =================
class _DashCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final double width;
  const _DashCard({required this.title, required this.value, required this.icon, this.width = 180});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 120,
      child: Card(
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 26),
            const Spacer(),
            Text(title, style: Theme.of(context).textTheme.labelMedium),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ]),
        ),
      ),
    );
  }
}

class _LargePanel extends StatelessWidget {
  final String title;
  final Widget child;
  const _LargePanel({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(height: 160, child: child)
        ]),
      ),
    );
  }
}
