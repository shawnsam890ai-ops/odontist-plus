import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/revenue_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/inventory_item.dart';
import 'attendance_view.dart';
import '../../providers/staff_attendance_provider.dart';
// Removed Doctors on duty feature; related providers no longer needed here.
import '../../providers/medicine_provider.dart';
import '../../providers/options_provider.dart';
import '../../models/medicine.dart';
import '../../providers/utility_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/revenue_entry.dart';
// Removed fl_chart and revenue_entry imports after chart removal
import '../../providers/auth_provider.dart';
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
  staffAttendance('Staff Attendance', Icons.badge_outlined),
  doctorsAttendance('Doctors Attendance', Icons.medical_services_outlined),
  inventory('Inventory', Icons.inventory_2_outlined),
  utility('Utility', Icons.miscellaneous_services_outlined),
  labs('Labs', Icons.biotech_outlined),
  medicines('Medicines', Icons.medication_outlined),
  settings('Settings', Icons.settings_outlined);

  final String label;
  final IconData icon;
  const DashboardSection(this.label, this.icon);
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardSection _section = DashboardSection.overview;
  // Removed "Customize" mode; simplified static layout

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F7FA), Color(0xFFE8F5E9)],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              const SizedBox(width: 8),
              _buildSideMenu(),
              const SizedBox(width: 12),
              Expanded(child: _buildSectionContent()),
            ],
          ),
        ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // center icons vertically
        children: [
          for (final s in DashboardSection.values) _iconOnlyMenuItem(s),
        ],
      ),
    );
  }

  Widget _iconOnlyMenuItem(DashboardSection s) {
    final selected = s == _section;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Tooltip(
        message: s.label,
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _section = s),
          child: Container(
            decoration: BoxDecoration(
              color: selected ? cs.primary.withOpacity(.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? cs.primary.withOpacity(.35) : Colors.transparent),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            child: Icon(s.icon, color: selected ? cs.primary : cs.onSurfaceVariant),
          ),
        ),
      ),
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
            _LargePanel(
              title: 'Upcoming Schedule',
              child: SizedBox(
                height: 220,
                child: const UpcomingSchedulePanel(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                  showDoctorFilter: false,
                  showTitle: false,
                ),
              ),
            ).withRadius(12),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _LargePanel(
                  title: 'Cases Overview',
                  child: SizedBox(
                    height: 220,
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
                  title: 'Staff Attendance (Overview)',
                  child: SizedBox(height: 220, child: _AttendanceOverviewWidget()),
                ),
              ),
            ]),
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
                        title: 'Staff Attendance (Overview)',
                        child: SizedBox(height: 240, child: _AttendanceOverviewWidget()),
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
                  title: 'Upcoming Schedule',
                  child: SizedBox(
                    height: 560,
                    child: const UpcomingSchedulePanel(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                      showDoctorFilter: false,
                      showTitle: false,
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
      // Fixed squarish cards to avoid empty right space; wrap will auto-flow
      const tileW = 180.0;
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
                valueColor: i == 0 ? (items[i].value >= 0 ? Colors.green : Colors.red) : null,
                appearDelayMs: 60 * i,
              ),
            ),
        ],
      );
    });
  }

  // Vertical metrics stack for wide layout
  Widget _buildMetricsColumn(double todaysRevenue, double monthlyRevenue, PatientProvider patientProvider, InventoryProvider inventoryProvider, RevenueProvider revenueProvider) {
    final entries = [
      ('Today', todaysRevenue, 'Revenue', Icons.today, todaysRevenue >= 0 ? Colors.green : Colors.red),
      ('Patients', patientProvider.patients.length.toDouble(), 'Total', Icons.people, null),
      ('Inventory', inventoryProvider.totalInventoryValue, 'Value', Icons.inventory_2, null),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          SizedBox(
            width: 180,
            height: 170,
            child: _DashMetricCard(
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Revenue', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Wrap(spacing: 16, runSpacing: 16, children: [
         _DashCard(title: "Today's Revenue", value: '₹${todaysRevenue.toStringAsFixed(0)}', icon: Icons.today, width: 200, valueColor: todaysRevenue >= 0 ? Colors.green : Colors.red),
         _DashCard(title: 'Monthly Revenue', value: '₹${monthlyRevenue.toStringAsFixed(0)}', icon: Icons.calendar_month, width: 200, valueColor: monthlyRevenue >= 0 ? Colors.green : Colors.red),
         _DashCard(title: 'Total Revenue', value: '₹${revenueProvider.total.toStringAsFixed(0)}', icon: Icons.account_balance_wallet, width: 220, valueColor: revenueProvider.total >= 0 ? Colors.green : Colors.red),
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
        Text('Utility', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Row(children: [
          ElevatedButton.icon(onPressed: _showAddUtilityDialog, icon: const Icon(Icons.add), label: const Text('Add Utility')),
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

// ================= Revenue & Expenses Panel =================
class _RevenueListPanel extends StatefulWidget {
  @override
  State<_RevenueListPanel> createState() => _RevenueListPanelState();
}

class _RevenueListPanelState extends State<_RevenueListPanel> {
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
                  return ListTile(
                    dense: true,
                    title: Text(e.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(dateStr + (e.patientId.isNotEmpty ? '  •  ${e.patientId}' : '')),
                    trailing: Text((e.amount >= 0 ? '+' : '') + '₹${e.amount.toStringAsFixed(0)}', style: TextStyle(color: amtColor, fontWeight: FontWeight.w700)),
                  );
                },
              ),
      ),
    ]);
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
                    (e.amount >= 0 ? '+' : '') + '₹' + e.amount.toStringAsFixed(0),
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
  final Color? valueColor;
  const _DashCard({required this.title, required this.value, required this.icon, this.width = 180, this.valueColor});

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
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: valueColor)),
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
              final text = isInt ? v.toInt().toString() : '₹${v.toStringAsFixed(0)}';
              return FittedBox(
                alignment: Alignment.center,
                child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: widget.valueColor ?? accentColor)),
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
            borderRadius: BorderRadius.circular(widget is _RadiusLargePanel ? (widget as _RadiusLargePanel).radius : 20),
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
