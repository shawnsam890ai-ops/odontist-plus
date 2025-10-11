import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/revenue_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/inventory_item.dart';
import 'attendance_view.dart';
import '../../providers/staff_attendance_provider.dart';
import '../../providers/doctor_attendance_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/medicine_provider.dart';
import '../widgets/cases_overview_chart.dart';
import '../widgets/upcoming_schedule_panel.dart';
import 'doctors_payments_section.dart';
import '../../providers/lab_registry_provider.dart';
import 'manage_patients_modern.dart';

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
  labs('Labs', Icons.biotech_outlined),
  medicines('Medicines', Icons.medication_outlined),
  settings('Settings', Icons.settings_outlined);

  final String label;
  final IconData icon;
  const DashboardSection(this.label, this.icon);
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardSection _section = DashboardSection.overview;
  bool _menuCollapsed = false;
  bool _customizeMode = false; // when true, panels become draggable/resizable

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
    final collapsed = _menuCollapsed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: collapsed ? 68 : 230,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 8),
                if (!collapsed)
                  Text('Main Menu', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: collapsed ? 'Expand' : 'Collapse',
                  icon: Icon(collapsed ? Icons.chevron_right : Icons.chevron_left),
                  onPressed: () => setState(() => _menuCollapsed = !collapsed),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: DashboardSection.values.map((s) => _menuTile(s, iconsOnly: collapsed)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile(DashboardSection s, {bool iconsOnly = false}) {
    final selected = s == _section;
    return ListTile(
      leading: Icon(s.icon, color: selected ? Theme.of(context).colorScheme.primary : null),
      title: iconsOnly ? null : Text(s.label, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
      horizontalTitleGap: iconsOnly ? 0 : null,
      selected: selected,
      onTap: () => setState(() => _section = s),
      dense: iconsOnly,
      minLeadingWidth: 0,
      contentPadding: EdgeInsets.symmetric(horizontal: iconsOnly ? 12 : 16),
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
      case DashboardSection.labs:
        return _labsSection();
      case DashboardSection.medicines:
        return _medicinesSection();
      case DashboardSection.settings:
        return _settingsSection();
    }
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LayoutBuilder(builder: (context, c) {
            final narrow = c.maxWidth < 420;
            if (!narrow) {
              return Row(children: [
                Text('Overview', style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: () => setState(() => _customizeMode = !_customizeMode),
                  child: Row(children: [Icon(_customizeMode ? Icons.check : Icons.edit, size: 16), const SizedBox(width: 6), Text(_customizeMode ? 'Done' : 'Customize')]),
                ),
              ]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Overview', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                  onPressed: () => setState(() => _customizeMode = !_customizeMode),
                  child: Row(children: [Icon(_customizeMode ? Icons.check : Icons.edit, size: 16), const SizedBox(width: 6), Text(_customizeMode ? 'Done' : 'Customize')]),
                ),
              ),
            ]);
          }),
          const SizedBox(height: 16),
          // Top metric tiles
          _buildMetricsGrid(todaysRevenue, monthlyRevenue, patientProvider, inventoryProvider, revenueProvider),
          const SizedBox(height: 16),
          // Compact responsive panels: Upcoming Schedule, Cases, Attendance, Doctors on Duty
          LayoutBuilder(builder: (context, c) {
            final narrow = c.maxWidth < 1000;
            final schedulePanel = _LargePanel(
              title: 'Upcoming Schedule',
              child: SizedBox(
                height: narrow ? 220 : 260,
                child: const UpcomingSchedulePanel(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                  showDoctorFilter: false,
                  showTitle: false,
                ),
              ),
            );
            final casesPanel = _LargePanel(
              title: 'Cases Overview',
              child: SizedBox(
                height: narrow ? 220 : 260,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: CasesOverviewChart(
                      data: {
                        'Root Canal': 18,
                        'Orthodontic': 12,
                        'Prosthodontic': 9,
                        'Filling': 30,
                      },
                    ),
                  ),
                ),
              ),
            );
            final attendancePanel = _LargePanel(
              title: 'Staff Attendance (Overview)',
              child: SizedBox(height: narrow ? 220 : 260, child: _AttendanceOverviewWidget()),
            );
            final doctorsDutyPanel = _LargePanel(
              title: 'Doctors on Duty',
              child: SizedBox(height: narrow ? 220 : 260, child: const _DoctorsOnDutyPanel()),
            );

            if (narrow) {
              return Column(children: [
                _StaggeredAppear(delayMs: 0, child: schedulePanel),
                const SizedBox(height: 16),
                _StaggeredAppear(delayMs: 60, child: casesPanel),
                const SizedBox(height: 16),
                _StaggeredAppear(delayMs: 120, child: attendancePanel),
                const SizedBox(height: 16),
                _StaggeredAppear(delayMs: 180, child: doctorsDutyPanel),
              ]);
            }
            // 2x2 grid on wide screens
            return Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _StaggeredAppear(delayMs: 0, child: schedulePanel)),
                const SizedBox(width: 16),
                Expanded(child: _StaggeredAppear(delayMs: 60, child: casesPanel)),
              ]),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _StaggeredAppear(delayMs: 120, child: attendancePanel)),
                const SizedBox(width: 16),
                Expanded(child: _StaggeredAppear(delayMs: 180, child: doctorsDutyPanel)),
              ]),
            ]);
          }),
        ]),
      ),
    );
  }

  // Removed legacy standard top row with adjustable split; simplified overview is used instead.

  Widget _buildMetricsGrid(double todaysRevenue, double monthlyRevenue, PatientProvider patientProvider, InventoryProvider inventoryProvider, RevenueProvider revenueProvider) {
    final items = [
      (
        title: 'Today',
        value: todaysRevenue,
        subtitle: 'Revenue',
        icon: Icons.today
      ),
      (
        title: 'Patients',
        value: patientProvider.patients.length.toDouble(),
        subtitle: 'Total',
        icon: Icons.people
      ),
      (
        title: 'Inventory',
        value: inventoryProvider.totalInventoryValue,
        subtitle: 'Value',
        icon: Icons.inventory_2
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      // Dynamically compute tile width to fit 3..1 columns without overflow
      final w = c.maxWidth;
      double tileW;
      if (w >= 1200) tileW = (w - 16 * 2) / 3; // 3 columns
      else if (w >= 800) tileW = (w - 16) / 2; // 2 columns
      else tileW = w; // single column
      tileW = tileW.clamp(160.0, 420.0);
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (int i = 0; i < items.length; i++)
            SizedBox(
              width: tileW,
              child: _DashMetricCard(
                title: items[i].title,
                value: items[i].value,
                subtitle: items[i].subtitle,
                icon: items[i].icon,
                appearDelayMs: 60 * i,
              ),
            ),
        ],
      );
    });
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
                      return ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: Text(lab.name),
                        subtitle: lab.address.isNotEmpty ? Text(lab.address) : null,
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.add),
                            tooltip: 'Add product',
                            onPressed: () => _showAddLabProductDialog(lab.id),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                _showEditLabDialog(lab.id, lab.name, lab.address);
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
                        subtitle: Text('Store: ₹${m.storeAmount.toStringAsFixed(0)}   •   MRP: ₹${m.mrp.toStringAsFixed(0)}   •   Profit/strip: ₹${profit.toStringAsFixed(0)}   •   Strips: ${m.stripsAvailable}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'delete') {
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
              await context.read<MedicineProvider>().addMedicine(name: name, storeAmount: store, mrp: mrp, strips: strips);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ========= Labs Dialogs =========
  void _showAddLabDialog() {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Register Lab'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Lab name')),
            const SizedBox(height: 8),
            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Lab address')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await context.read<LabRegistryProvider>().addLab(name, addrCtrl.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  void _showEditLabDialog(String id, String name, String address) {
    final nameCtrl = TextEditingController(text: name);
    final addrCtrl = TextEditingController(text: address);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Lab'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Lab name')),
            const SizedBox(height: 8),
            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Lab address')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await context.read<LabRegistryProvider>().updateLab(id, name: nameCtrl.text.trim(), address: addrCtrl.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        const Text('General configuration placeholders will appear here.'),
        const SizedBox(height: 24),
        Wrap(spacing: 12, runSpacing: 12, children: const [
          Chip(label: Text('Theme: Light/Dark')),
          Chip(label: Text('Backup: Not Configured')),
        ])
      ]),
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

// Attendance overview widget (read-only calendar) used in overview section
class _AttendanceOverviewWidget extends StatefulWidget {
  @override
  State<_AttendanceOverviewWidget> createState() => _AttendanceOverviewWidgetState();
}

class _AttendanceOverviewWidgetState extends State<_AttendanceOverviewWidget> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _staff;


  Color _cellColor(bool? state) {
    if (state == true) return Colors.green.shade400;
    if (state == false) return Colors.red.shade400;
    return Colors.grey.shade200;
  }

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
            // Title row
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Staff Attendance (Overview)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
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
            final state = provider.stateFor(staff, date);
            final status = state == true ? 'Present' : state == false ? 'Absent' : 'No data';
            inner = Tooltip(
              message: status,
              waitDuration: const Duration(milliseconds: 250),
              child: Container(
                decoration: BoxDecoration(
                  color: _cellColor(state),
                  borderRadius: BorderRadius.circular(cell * 0.15),
                ),
                alignment: Alignment.center,
                child: Text('$day', style: TextStyle(fontSize: dayFont.toDouble(), fontWeight: FontWeight.w600, color: state==false? Colors.white : Colors.black87)),
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
  const _DashCard({required this.title, required this.value, required this.icon, this.width = 180});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, size: 20), const SizedBox(width: 6), Expanded(child: Text(title, style: const TextStyle(fontSize: 12)))]),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }
}

class _DashMetricCard extends StatefulWidget {
  final String title;
  final double value;
  final String? subtitle;
  final IconData icon;
  final int appearDelayMs;
  const _DashMetricCard({Key? key, required this.title, required this.value, required this.icon, this.subtitle, this.appearDelayMs = 0}) : super(key: key);

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
          BoxShadow(color: Colors.black.withOpacity(_hovered ? .10 : .05), blurRadius: 14, offset: const Offset(0,8)),
          BoxShadow(color: cs.primary.withOpacity(_hovered ? .08 : .03), blurRadius: 6, offset: const Offset(0,2)),
        ],
        border: Border.all(color: cs.outlineVariant.withOpacity(.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(builder: (context, c) {
        final s = (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight);
        final effScale = (s / 160).clamp(.6, 2.2);
        final iconSize = 22 * effScale;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                final text = isInt ? v.toInt().toString() : '₹${v.toStringAsFixed(0)}';
                return FittedBox(
                  alignment: Alignment.centerLeft,
                  child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: accentColor)),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 2),
              Text(widget.subtitle!, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ]
          ],
        );
      }),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surface = cs.surface;
    final translateY = _pressed ? 0.0 : (_hovered ? -2.0 : 0.0);
    final shadowOpacity = _pressed ? .02 : (_hovered ? .10 : .05);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() { _hovered = false; _pressed = false; }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..translate(0.0, translateY),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [surface, surface.withOpacity(.96)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(shadowOpacity), blurRadius: 18, offset: const Offset(0,10)),
              BoxShadow(color: cs.primary.withOpacity(_hovered ? .06 : .03), blurRadius: 6, offset: const Offset(0,2)),
            ],
            border: Border.all(color: cs.outlineVariant.withOpacity(.25)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: LayoutBuilder(builder: (context, c) {
            final header = Row(children: [
              Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
            ]);
            // If child might overflow, wrap in SingleChildScrollView to be safe.
            final body = ClipRect(child: widget.child);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              header,
              const SizedBox(height: 8),
              Expanded(flex: 0, child: body),
            ]);
          }),
        ),
      ),
    );
  }
}

// Simple appear animation wrapper
class _StaggeredAppear extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _StaggeredAppear({required this.child, this.delayMs = 0});

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
    if (widget.delayMs > 0) {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _c.forward();
      });
    } else {
      _c.forward();
    }
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
class _DoctorsOnDutyPanel extends StatelessWidget {
  const _DoctorsOnDutyPanel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final doctors = context.watch<DoctorProvider>().doctors;
    final attendance = context.watch<DoctorAttendanceProvider>();
    final today = DateTime.now();
    final key = DateTime(today.year, today.month, today.day);

    final rows = <Widget>[];
    for (final d in doctors) {
      final map = attendance.attendance[d.name] ?? const {};
      final present = map[key] == true;
      rows.add(ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: CircleAvatar(radius: 14, backgroundColor: cs.primary.withOpacity(.12), child: Icon(Icons.person, color: cs.primary, size: 16)),
        title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: present ? Colors.green.withOpacity(.12) : Colors.red.withOpacity(.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (present ? Colors.green : Colors.red).withOpacity(.35)),
          ),
          child: Text(present ? 'Present' : 'Absent', style: TextStyle(color: present ? Colors.green.shade700 : Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ));
    }

    if (rows.isEmpty) {
      return const Center(child: Text('No doctors added'));
    }
    return ListView(
      children: rows,
    );
  }
}

// Splitter used for adjustable column widths (and optional vertical drag)
// Removed legacy splitter widget used by the old adjustable layout.
