import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/revenue_provider.dart';
import 'add_patient_page.dart';
import 'patient_list_page.dart';
import '../../providers/inventory_provider.dart';
import '../../models/inventory_item.dart';
import 'attendance_view.dart';

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
  bool _menuCollapsed = false;

  double _estimateProfit(double totalRevenue, double labCosts) {
    // Placeholder profit logic: revenue - lab costs (inventory purchase costs not subtracted yet)
    return totalRevenue - labCosts;
  }

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
              _DashCard(title: 'Clinic Inventory', value: '₹${inventoryProvider.totalInventoryValue.toStringAsFixed(0)}', icon: Icons.inventory_2, width: 200),
              _DashCard(title: 'Profit (Est.)', value: '₹${_estimateProfit(revenueProvider.total, inventoryProvider.totalLabCost).toStringAsFixed(0)}', icon: Icons.trending_up, width: 200),
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
    return const MonthlyAttendanceView();
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
    final inventoryProvider = context.watch<InventoryProvider>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Clinic Inventory & Lab Costs', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Row(children: [
          ElevatedButton.icon(onPressed: () => _showAddInventoryDialog(), icon: const Icon(Icons.add), label: const Text('Add Item')),
          const SizedBox(width: 12),
          ElevatedButton.icon(onPressed: () => _showAddLabCostDialog(), icon: const Icon(Icons.biotech), label: const Text('Add Lab Cost')),
          Text('Total Inv: ₹${inventoryProvider.totalInventoryValue.toStringAsFixed(0)}  | Lab Cost: ₹${inventoryProvider.totalLabCost.toStringAsFixed(0)}')
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: Row(children: [
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: Column(children: [
                  const ListTile(title: Text('Lab Work Costs')),
                  const Divider(height: 1),
                  Expanded(
                      child: inventoryProvider.labCosts.isEmpty
                          ? const Center(child: Text('No lab costs'))
                          : ListView.builder(
                              itemCount: inventoryProvider.labCosts.length,
                              itemBuilder: (c, i) {
                                final cost = inventoryProvider.labCosts[i];
                                return ListTile(
                                  title: Text(cost.description),
                                  subtitle: Text('₹${cost.cost.toStringAsFixed(0)}'),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') _showEditLabCostDialog(cost.id, cost.description, cost.cost);
                                      if (v == 'delete') inventoryProvider.removeLabCost(cost.id);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                                    ],
                                  ),
                                );
                              },
                            ))
                ]),
              ),
            )
          ]),
        )
      ]),
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
              final c = double.tryParse(costCtrl.text) ?? unitCost;
              context.read<InventoryProvider>().updateItem(id, name: n, quantity: q, unitCost: c);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  void _showAddLabCostDialog() {
    final descCtrl = TextEditingController();
    final costCtrl = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Lab Cost'),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Cost'), keyboardType: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final d = descCtrl.text.trim();
              if (d.isEmpty) return;
              final c = double.tryParse(costCtrl.text) ?? 0;
              context.read<InventoryProvider>().addLabCost(LabCostItem(description: d, cost: c));
              Navigator.pop(context);
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  void _showEditLabCostDialog(String id, String desc, double cost) {
    final descCtrl = TextEditingController(text: desc);
    final costCtrl = TextEditingController(text: cost.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Lab Cost'),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Cost'), keyboardType: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final d = descCtrl.text.trim();
              if (d.isEmpty) return;
              final c = double.tryParse(costCtrl.text) ?? cost;
              context.read<InventoryProvider>().updateLabCost(id, description: d, cost: c);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  // ========= Reusable Dashboard Widgets =========
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

class _LargePanel extends StatelessWidget {
  final String title;
  final Widget child;
  const _LargePanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(height: 160, child: child)
          ]),
        ),
      ),
    );
  }
}
