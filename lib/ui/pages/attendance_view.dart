import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/staff_attendance_provider.dart';
import '../../models/staff_member.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MonthlyAttendanceView extends StatefulWidget {
  const MonthlyAttendanceView({super.key});
  @override
  State<MonthlyAttendanceView> createState() => _MonthlyAttendanceViewState();
}

class _MonthlyAttendanceViewState extends State<MonthlyAttendanceView> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _staff;
  final _monthlySalaryController = TextEditingController();
  bool _staffCollapsed = false;
  String _staffSearch = '';
  // Inline add-staff form removed in favor of a dialog.

  @override
  void dispose() {
    _monthlySalaryController.dispose();
    super.dispose();
  }

  void _changeMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  List<DateTime> _daysInMonth() {
    final first = _month;
    final nextMonth = DateTime(first.year, first.month + 1, 1);
    final days = nextMonth.subtract(const Duration(days: 1)).day;
    return List.generate(days, (i) => DateTime(first.year, first.month, i + 1));
  }

  String _monthLabel(DateTime m) {
    const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    return '${months[m.month - 1]} ${m.year}';
  }

  Color _cellColor(bool? state) {
    if (state == true) return Colors.green.shade400;
    if (state == false) return Colors.red.shade400;
    return Colors.grey.shade300;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StaffAttendanceProvider>();
    final staffList = provider.staffNames;
    if (_staff == null && staffList.isNotEmpty) _staff = staffList.first;
    final selectedStaff = _staff ?? (staffList.isNotEmpty ? staffList.first : null);
    final days = _daysInMonth();
    int present = 0;
    int absent = 0;
    if (selectedStaff != null) {
      present = provider.presentCount(selectedStaff, _month.year, _month.month);
      absent = provider.absentCount(selectedStaff, _month.year, _month.month);
    }
    final salaryRecord = selectedStaff == null ? null : provider.getSalaryRecord(selectedStaff, _month.year, _month.month);
    final monthlySalary = salaryRecord?.totalSalary ?? 0;
    final paid = salaryRecord?.paid ?? false;
    if (salaryRecord != null) {
      _monthlySalaryController.text = salaryRecord.totalSalary == 0 ? '' : salaryRecord.totalSalary.toStringAsFixed(0);
    }

    final staffPanel = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(
          tooltip: _staffCollapsed ? 'Expand Staff Panel' : 'Collapse Staff Panel',
          icon: Icon(_staffCollapsed ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_left, size: 20),
          onPressed: () => setState(() => _staffCollapsed = !_staffCollapsed),
        ),
        if (!_staffCollapsed) ...[
          const Icon(Icons.group, size: 18),
          const SizedBox(width: 6),
          Text('Staff', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          IconButton(
            tooltip: 'Add Staff',
            icon: const Icon(Icons.person_add, size: 20),
            onPressed: _showAddStaffDialog,
          ),
          IconButton(
              tooltip: 'Select Month',
              onPressed: () async {
                final picked = await showDatePicker(
                    context: context,
                    initialDate: _month,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2100));
                if (picked != null) setState(() => _month = DateTime(picked.year, picked.month));
              },
              icon: const Icon(Icons.calendar_month, size: 20))
        ]
      ]),
      if (!_staffCollapsed) ...[
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, size: 18),
            hintText: 'Search staff by name or phone',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _staffSearch = v.trim().toLowerCase()),
        ),
      ],
      if (!_staffCollapsed) const SizedBox(height: 8),
      if (!_staffCollapsed)
        Expanded(
          child: staffList.isEmpty
              ? const Center(child: Text('No staff'))
              : ListView.separated(
                  itemCount: staffList
                      .where((s) => _staffSearch.isEmpty || s.toLowerCase().contains(_staffSearch) || _matchesPhone(provider, s, _staffSearch))
                      .length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (c, i) {
                    final filtered = staffList
                        .where((s) => _staffSearch.isEmpty || s.toLowerCase().contains(_staffSearch) || _matchesPhone(provider, s, _staffSearch))
                        .toList()
                      ..sort();
                    final name = filtered[i];
                    final member = provider.staffMembers.firstWhere((m) => m.name == name, orElse: () => StaffMember(id: '', name: name));
                    final selected = name == selectedStaff;
                    final primaryPhone = member.phoneNumbers.isNotEmpty ? member.phoneNumbers.first : '';
                    return GestureDetector(
                      onTap: () => setState(() => _staff = name),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          color: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : Theme.of(context).colorScheme.surface,
                          border: Border.all(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerColor.withOpacity(.4)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(children: [
                                  Flexible(
                                      child: Text(member.name,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: selected
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Theme.of(context).textTheme.bodyMedium?.color))),
                                  if (member.age != null) ...[
                                    const SizedBox(width: 6),
                                    Text('(${member.age})', style: const TextStyle(fontSize: 12, color: Colors.grey))
                                  ]
                                ]),
                                // Removed P:A stats per new requirement
                              ],
                            ),
                          ),
                          if (primaryPhone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(primaryPhone, style: const TextStyle(fontSize: 12)),
                            ),
                          Wrap(spacing: 4, children: [
                            IconButton(
                              tooltip: 'View Details',
                              icon: const Icon(Icons.info_outline, size: 18),
                              onPressed: () => _showViewStaffDialog(member),
                            ),
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _showEditStaffDialog(member),
                            ),
                            IconButton(
                              tooltip: 'WhatsApp',
                              icon: Icon(Icons.chat, size: 18, color: primaryPhone.isEmpty ? null : Colors.green),
                              onPressed: primaryPhone.isEmpty ? null : () => _launchWhatsApp(primaryPhone),
                            ),
                            IconButton(
                              tooltip: 'Call',
                              icon: const Icon(Icons.call, size: 18),
                              onPressed: primaryPhone.isEmpty ? null : () => _launchCall(primaryPhone),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => _confirmDeleteStaff(provider, name),
                            ),
                          ])
                        ]),
                      ),
                    );
                  },
                ),
        )
    ]);

    final calendarCard = selectedStaff == null
        ? const Center(child: Text('Add staff to view attendance'))
        : Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
                  Text(_monthLabel(_month), style: const TextStyle(fontWeight: FontWeight.w600)),
                  IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
                  const Spacer(),
                  Text('Salary: ₹${monthlySalary.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w500))
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _legendBox(Colors.green.shade400, 'Present'),
                  const SizedBox(width: 12),
                  _legendBox(Colors.red.shade400, 'Absent'),
                  const SizedBox(width: 12),
                  _legendBox(Colors.grey.shade300, 'None'),
                  const Spacer(),
                  Text('P:$present A:$absent Salary: ₹${monthlySalary.toStringAsFixed(0)}${paid ? ' (Paid)' : ''}')
                ]),
                const SizedBox(height: 8),
                _weekdayHeaderRow(),
                const SizedBox(height: 4),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.only(top: 2),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1.4, // wider than tall to visually shrink height
                    ),
                    itemCount: days.length,
                    itemBuilder: (c, i) {
                      final day = days[i];
                      final state = provider.stateFor(selectedStaff, day);
                      return GestureDetector(
                        onTap: () {
                          provider.cycle(selectedStaff, day);
                          setState(() {});
                        },
                        child: Center(
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _cellColor(state),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text('${day.day}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  color: state == false ? Colors.white : Colors.black87,
                                )),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  ElevatedButton.icon(
                    onPressed: () => _showSetSalaryDialog(selectedStaff),
                    icon: const Icon(Icons.edit),
                    label: const Text('Set Salary'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (!paid) {
                        final confirm = await _confirmMarkPaid(selectedStaff, monthlySalary);
                        if (confirm == true) {
                          provider.markSalaryPaid(selectedStaff, _month.year, _month.month, amount: monthlySalary);
                          setState(() {});
                        }
                      } else {
                        final confirm = await _confirmUnmarkPaid(selectedStaff);
                        if (confirm == true) {
                          provider.unmarkSalaryPaid(selectedStaff, _month.year, _month.month);
                          setState(() {});
                        }
                      }
                    },
                    icon: Icon(paid ? Icons.undo : Icons.check_circle),
                    label: Text(paid ? 'Unmark Paid' : 'Mark Paid'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _launchUPIPayment,
                    icon: const Icon(Icons.payment),
                    label: const Text('Pay (UPI)'),
                  ),
                ])
              ]),
            ),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = width < 860 || width < 1100 && !_staffCollapsed && width < 1000;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: isNarrow
              ? Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: _staffCollapsed ? 56 : 280,
                    child: staffPanel,
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: calendarCard),
                ])
              : Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: _staffCollapsed ? 52 : 300,
                    child: staffPanel,
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: calendarCard),
                ]),
        );
      },
    );
  }

  Widget _weekdayHeaderRow() {
    const labels = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map((l) => Expanded(child: Center(child: Text(l, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))))
          .toList(),
    );
  }

  Widget _legendBox(Color color, String label) => Row(children: [
        Container(width: 18, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);

  Future<void> _launchUPIPayment() async {
    const dummyUrl = 'upi://pay?pa=dentist@upi&pn=Dental%20Clinic&am=0&cu=INR';
    try {
      final uri = Uri.parse(dummyUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No UPI app available')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('UPI launch failed: $e')));
      }
    }
  }

  Future<void> _showAddStaffDialog() async {
    final provider = context.read<StaffAttendanceProvider>();
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final primaryPhoneCtrl = TextEditingController();
    final extraPhoneCtrl = TextEditingController();
    final emgNameCtrl = TextEditingController();
    final emgRelationCtrl = TextEditingController();
    final emgPhoneCtrl = TextEditingController();
    final emgAddressCtrl = TextEditingController();
    final monthlySalaryCtrl = TextEditingController();
    String? sex;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 600),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                elevation: 0,
                backgroundColor: Colors.transparent,
                title: const Text('Add Staff'),
                actions: [
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Form(
                  key: formKey,
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Name *'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: ageCtrl,
                              decoration: const InputDecoration(labelText: 'Age'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: sex,
                              decoration: const InputDecoration(labelText: 'Sex'),
                              items: const [
                                DropdownMenuItem(value: 'M', child: Text('Male')),
                                DropdownMenuItem(value: 'F', child: Text('Female')),
                                DropdownMenuItem(value: 'O', child: Text('Other')),
                              ],
                              onChanged: (v) => sex = v,
                            ),
                          )
                        ]),
                        const SizedBox(height: 12),
                        TextFormField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: primaryPhoneCtrl,
                          decoration: const InputDecoration(labelText: 'Phone Number *'),
                          keyboardType: TextInputType.phone,
                          validator: (v) => (v == null || v.trim().length < 7) ? 'Enter valid phone' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: extraPhoneCtrl,
                          decoration: const InputDecoration(labelText: 'Additional Phone (optional)'),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 20),
                        Text('Emergency Contact', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        TextFormField(controller: emgNameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: TextFormField(controller: emgRelationCtrl, decoration: const InputDecoration(labelText: 'Relation'))),
                          const SizedBox(width: 12),
                          Expanded(child: TextFormField(controller: emgPhoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone)),
                        ]),
                        const SizedBox(height: 12),
                        TextFormField(controller: emgAddressCtrl, decoration: const InputDecoration(labelText: 'Emergency Address')),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: monthlySalaryCtrl,
                          decoration: const InputDecoration(labelText: 'Monthly Salary Allowance'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 28),
                        Row(children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.save),
                              label: const Text('Save'),
                              onPressed: () {
                                if (!formKey.currentState!.validate()) return;
                                final member = StaffMember(
                                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                                  name: nameCtrl.text.trim(),
                                  age: int.tryParse(ageCtrl.text),
                                  sex: sex,
                                  address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                                  phoneNumbers: [
                                    primaryPhoneCtrl.text.trim(),
                                    if (extraPhoneCtrl.text.trim().isNotEmpty) extraPhoneCtrl.text.trim(),
                                  ],
                                  emergencyContact: emgNameCtrl.text.trim().isEmpty
                                      ? null
                                      : EmergencyContact(
                                          name: emgNameCtrl.text.trim(),
                                          relation: emgRelationCtrl.text.trim(),
                                          phone: emgPhoneCtrl.text.trim(),
                                          address: emgAddressCtrl.text.trim().isEmpty ? null : emgAddressCtrl.text.trim(),
                                        ),
                                );
                                provider.addStaffDetailed(member);
                                final salary = double.tryParse(monthlySalaryCtrl.text) ?? 0;
                                if (salary > 0) {
                                  provider.setMonthlySalary(member.name, _month.year, _month.month, salary);
                                }
                                setState(() => _staff = member.name);
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.close),
                              label: const Text('Cancel'),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          )
                        ])
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSetSalaryDialog(String staffName) async {
    final provider = context.read<StaffAttendanceProvider>();
    final existing = provider.getSalaryRecord(staffName, _month.year, _month.month);
    final ctrl = TextEditingController(text: existing == null || existing.totalSalary == 0 ? '' : existing.totalSalary.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set Salary - $staffName'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 260,
            child: TextFormField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Monthly Salary', prefixText: '₹'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter amount';
                final d = double.tryParse(v); if (d == null || d < 0) return 'Invalid';
                return null;
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final val = double.parse(ctrl.text);
              provider.setMonthlySalary(staffName, _month.year, _month.month, val);
              _monthlySalaryController.text = val.toStringAsFixed(0); // keep internal reference for mark paid earlier logic
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  Future<void> _showEditStaffDialog(StaffMember member) async {
    final provider = context.read<StaffAttendanceProvider>();
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: member.name);
    final ageCtrl = TextEditingController(text: member.age?.toString() ?? '');
    final addressCtrl = TextEditingController(text: member.address ?? '');
    final primaryPhoneCtrl = TextEditingController(text: member.phoneNumbers.isNotEmpty ? member.phoneNumbers.first : '');
    final extraPhoneCtrl = TextEditingController(
        text: member.phoneNumbers.length > 1 ? member.phoneNumbers[1] : '');
  final monthlySalaryCtrl = TextEditingController();
  final emgNameCtrl = TextEditingController(text: member.emergencyContact?.name ?? '');
  final emgRelationCtrl = TextEditingController(text: member.emergencyContact?.relation ?? '');
  final emgPhoneCtrl = TextEditingController(text: member.emergencyContact?.phone ?? '');
  final emgAddressCtrl = TextEditingController(text: member.emergencyContact?.address ?? '');
    final salaryRec = provider.getSalaryRecord(member.name, _month.year, _month.month);
    if (salaryRec != null && salaryRec.totalSalary > 0) {
      monthlySalaryCtrl.text = salaryRec.totalSalary.toStringAsFixed(0);
    }
    String? sex = member.sex;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 520),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              elevation: 0,
              backgroundColor: Colors.transparent,
              title: const Text('Edit Staff'),
              actions: [
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close))
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name *'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: ageCtrl,
                          decoration: const InputDecoration(labelText: 'Age'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: sex,
                          decoration: const InputDecoration(labelText: 'Sex'),
                          items: const [
                            DropdownMenuItem(value: 'M', child: Text('Male')),
                            DropdownMenuItem(value: 'F', child: Text('Female')),
                            DropdownMenuItem(value: 'O', child: Text('Other')),
                          ],
                          onChanged: (v) => sex = v,
                        ),
                      )
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: primaryPhoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone Number *'),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v == null || v.trim().length < 7 ? 'Invalid' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: extraPhoneCtrl,
                      decoration: const InputDecoration(labelText: 'Additional Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: monthlySalaryCtrl,
                      decoration: const InputDecoration(labelText: 'Monthly Salary (This Month)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Emergency Contact', style: Theme.of(context).textTheme.titleSmall)),
                    const SizedBox(height: 8),
                    TextFormField(controller: emgNameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextFormField(controller: emgRelationCtrl, decoration: const InputDecoration(labelText: 'Relation'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: emgPhoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone)),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(controller: emgAddressCtrl, decoration: const InputDecoration(labelText: 'Address')),
                    const SizedBox(height: 28),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            final updated = StaffMember(
                              id: member.id,
                              name: nameCtrl.text.trim(),
                              age: int.tryParse(ageCtrl.text),
                              sex: sex,
                              address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                              phoneNumbers: [
                                primaryPhoneCtrl.text.trim(),
                                if (extraPhoneCtrl.text.trim().isNotEmpty) extraPhoneCtrl.text.trim(),
                              ],
                              emergencyContact: emgNameCtrl.text.trim().isEmpty
                                  ? null
                                  : EmergencyContact(
                                      name: emgNameCtrl.text.trim(),
                                      relation: emgRelationCtrl.text.trim(),
                                      phone: emgPhoneCtrl.text.trim(),
                                      address: emgAddressCtrl.text.trim().isEmpty ? null : emgAddressCtrl.text.trim(),
                                    ),
                            );
                            provider.updateStaff(updated);
                            final salary = double.tryParse(monthlySalaryCtrl.text) ?? 0;
                            if (salary > 0) {
                              provider.setMonthlySalary(updated.name, _month.year, _month.month, salary);
                            }
                            if (member.name != updated.name) {
                              setState(() => _staff = updated.name);
                            }
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      )
                    ])
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showViewStaffDialog(StaffMember member) async {
    final provider = context.read<StaffAttendanceProvider>();
    final salaryRec = provider.getSalaryRecord(member.name, _month.year, _month.month);
    final present = provider.presentCount(member.name, _month.year, _month.month);
    final absent = provider.absentCount(member.name, _month.year, _month.month);
    final history = provider.salaryHistory(member.name);
    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 660),
            child: _StaffViewContent(
              member: member,
              provider: provider,
              salaryRec: salaryRec,
              present: present,
              absent: absent,
              allHistory: history,
              currentMonth: _month,
              onClose: () => Navigator.pop(ctx),
            ),
          ),
        );
      },
    );
  }

  // (old _detailRow helper removed; replaced by localized _row in dialog widget)
  Future<bool?> _confirmMarkPaid(String staff, double amount) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Mark Paid'),
        content: Text('Mark salary of ₹${amount.toStringAsFixed(0)} as PAID for $staff?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Mark Paid')),
        ],
      ),
    );
  }

  Future<bool?> _confirmUnmarkPaid(String staff) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undo Paid Status'),
        content: Text('Set salary status back to UNPAID for $staff?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Undo')),
        ],
      ),
    );
  }

  bool _matchesPhone(StaffAttendanceProvider provider, String staffName, String query) {
    if (query.isEmpty) return true;
    final m = provider.staffMembers.firstWhere((s) => s.name == staffName, orElse: () => StaffMember(id: '', name: staffName));
    return m.phoneNumbers.any((p) => p.replaceAll(' ', '').contains(query.replaceAll(' ', '')));
  }

  Future<void> _confirmDeleteStaff(StaffAttendanceProvider provider, String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Staff'),
        content: Text('Are you sure you want to delete "$name"? This will remove attendance and salary records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          )
        ],
      ),
    );
    if (result == true) {
      provider.removeStaff(name);
      if (_staff == name) setState(() => _staff = null);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final uri = Uri.parse('https://wa.me/$phone');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp not available')));
      }
    }
  }

  Future<void> _launchCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (!await canLaunchUrl(uri) || !await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot start call')));
      }
    }
  }
}

// === Staff View Dialog Content (moved top-level to avoid nesting issues) ===
class _StaffViewContent extends StatefulWidget {
  final StaffMember member;
  final StaffAttendanceProvider provider;
  final MonthlySalaryRecord? salaryRec;
  final int present;
  final int absent;
  final List<MonthlySalaryRecord> allHistory; // already sorted desc
  final DateTime currentMonth;
  final VoidCallback onClose;
  const _StaffViewContent({required this.member, required this.provider, required this.salaryRec, required this.present, required this.absent, required this.allHistory, required this.currentMonth, required this.onClose});
  @override
  State<_StaffViewContent> createState() => _StaffViewContentState();
}

class _StaffViewContentState extends State<_StaffViewContent> {
  bool _historyExpanded = false;
  String _historyMode = 'recent'; // 'recent' or year string
  String _paidFilter = 'all'; // all | paid | unpaid

  List<int> get _availableYears => widget.allHistory.map((e) => e.year).toSet().toList()..sort((a,b)=>b.compareTo(a));

  List<MonthlySalaryRecord> get _displayHistory {
    if (widget.allHistory.isEmpty) return const [];
    if (_historyMode == 'recent') {
      return widget.allHistory.take(12).toList();
    }
    final year = int.tryParse(_historyMode);
    if (year == null) return widget.allHistory.take(12).toList();
    return widget.allHistory.where((r) => r.year == year).toList()..sort((a,b){
      if (a.year != b.year) return b.year.compareTo(a.year);
      return b.month.compareTo(a.month);
    });
  }

  String _monthLabel(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m-1];
  }

  String _formatDate(DateTime? d){
    if(d==null) return '—';
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  }

  Future<void> _pickPaymentDate(MonthlySalaryRecord rec) async {
    final initial = rec.paymentDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      widget.provider.setPaymentDate(widget.member.name, rec.year, rec.month, picked);
      setState(() {});
    }
  }

  Future<void> _showPrintDialog() async {
    final rows = _buildPrintRows();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Salary History - ${widget.member.name}'),
        content: SizedBox(
          width: 600,
          child: rows.isEmpty ? const Text('No data to print') : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Month')),
                DataColumn(label: Text('Present')),
                DataColumn(label: Text('Absent')),
                DataColumn(label: Text('Salary')),
                DataColumn(label: Text('Payment Date')),
              ],
              rows: rows,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    final buffer = StringBuffer();
    buffer.writeln('Month,Year,Present,Absent,Salary,Paid,Payment Date');
    for (final r in _filteredForExport()) {
      final present = widget.provider.presentCount(widget.member.name, r.year, r.month);
      final absent = widget.provider.absentCount(widget.member.name, r.year, r.month);
      buffer.writeln('${r.month},${r.year},$present,$absent,${r.totalSalary.toStringAsFixed(0)},${r.paid ? 'Yes':'No'},${_formatDate(r.paymentDate)}');
    }
    final data = buffer.toString();
    // Try Clipboard
    try {
      await Clipboard.setData(ClipboardData(text: data));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
    } catch (_) {}
  }

  Future<void> _exportPdf() async {
    final pdfDoc = pw.Document();
    final rows = <pw.TableRow>[];
    rows.add(pw.TableRow(children: [
      _pdfHeaderCell('Month'),
      _pdfHeaderCell('Present'),
      _pdfHeaderCell('Absent'),
      _pdfHeaderCell('Salary'),
      _pdfHeaderCell('Paid'),
      _pdfHeaderCell('Payment Date'),
    ]));
    for (final r in _filteredForExport()) {
      final present = widget.provider.presentCount(widget.member.name, r.year, r.month);
      final absent = widget.provider.absentCount(widget.member.name, r.year, r.month);
      rows.add(pw.TableRow(children: [
        _pdfCell('${_monthLabel(r.month)} ${r.year}'),
        _pdfCell(present.toString()),
        _pdfCell(absent.toString()),
        _pdfCell('₹${r.totalSalary.toStringAsFixed(0)}'),
        _pdfCell(r.paid ? 'Yes' : 'No'),
        _pdfCell(_formatDate(r.paymentDate)),
      ]));
    }
    pdfDoc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Salary History - ${widget.member.name}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Table(border: pw.TableBorder.all(width: .5), children: rows),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdfDoc.save());
  }

  Iterable<MonthlySalaryRecord> _filteredForExport() {
    final base = _displayHistory;
    return base.where((r) {
      if (_paidFilter == 'paid') return r.paid;
      if (_paidFilter == 'unpaid') return !r.paid;
      return true;
    });
  }

  pw.Widget _pdfHeaderCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      );
  pw.Widget _pdfCell(String text) => pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(text));

  List<DataRow> _buildPrintRows() {
    final provider = widget.provider;
    final list = widget.allHistory.take(36).toList(); // reasonable cap for print (3 years)
    return list.map((r) {
      final present = provider.presentCount(widget.member.name, r.year, r.month);
      final absent = provider.absentCount(widget.member.name, r.year, r.month);
      return DataRow(cells: [
        DataCell(Text('${_monthLabel(r.month)} ${r.year}')),
        DataCell(Text(present.toString())),
        DataCell(Text(absent.toString())),
        DataCell(Text('₹${r.totalSalary.toStringAsFixed(0)}${r.paid ? '' : ''}')),
        DataCell(Text(_formatDate(r.paymentDate))),
      ]);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final salaryRec = widget.salaryRec;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(member.name, style: Theme.of(context).textTheme.headlineSmall)),
                IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close))
              ]),
              const SizedBox(height: 4),
              _row('Age', member.age?.toString() ?? '—'),
              _row('Sex', member.sex ?? '—'),
              _row('Phone', member.phoneNumbers.isEmpty ? '—' : member.phoneNumbers.first),
              if (member.phoneNumbers.length > 1) _row('Alt Phone', member.phoneNumbers[1]),
              _row('Address', member.address ?? '—'),
              _row('Salary (This Month)', salaryRec == null ? '—' : '₹${salaryRec.totalSalary.toStringAsFixed(0)}'),
              _row('Paid', salaryRec == null ? '—' : (salaryRec.paid ? 'Yes' : 'No')),
              if (salaryRec != null) _paymentDateRow(salaryRec),
              _row('Present Days', widget.present.toString()),
              _row('Absent Days', widget.absent.toString()),
              const SizedBox(height: 12),
              _buildHistorySection(),
              const SizedBox(height: 20),
              Text('Emergency Contact', style: Theme.of(context).textTheme.titleMedium),
              const Divider(height: 16),
              if (member.emergencyContact == null)
                const Text('Not provided', style: TextStyle(fontStyle: FontStyle.italic))
              else ...[
                _row('Name', member.emergencyContact!.name),
                _row('Relation', member.emergencyContact!.relation),
                _row('Phone', member.emergencyContact!.phone),
                if (member.emergencyContact!.address != null && member.emergencyContact!.address!.isNotEmpty)
                  _row('Address', member.emergencyContact!.address!),
              ],
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: widget.onClose,
                  child: const Text('Close'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 140, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
      Expanded(child: Text(value)),
    ]),
  );

  Widget _paymentDateRow(MonthlySalaryRecord rec) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(width: 140, child: Text('Payment Date', style: TextStyle(fontWeight: FontWeight.w600))),
        Expanded(
          child: Row(children: [
            Text(_formatDate(rec.paymentDate)),
            if (rec.paid) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Edit Payment Date',
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.edit_calendar, size: 18),
                onPressed: () => _pickPaymentDate(rec),
              )
            ]
          ]),
        ),
      ]),
    );
  }

  Widget _buildHistorySection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.5)),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _historyExpanded = !_historyExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                const Icon(Icons.history, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Salary History', style: Theme.of(context).textTheme.titleMedium)),
                if (widget.allHistory.isNotEmpty && _historyExpanded)
                  _yearSelector(),
                const SizedBox(width: 4),
                Icon(_historyExpanded ? Icons.expand_less : Icons.expand_more)
              ]),
            ),
          ),
          if (_historyExpanded)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Padding(
                key: ValueKey(_historyMode + _displayHistory.length.toString()),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: widget.allHistory.isEmpty
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('No salary history', style: TextStyle(fontStyle: FontStyle.italic)),
                        ),
                      )
                    : Column(
                        children: [
                          Row(
                            children: [
                              Text(_historyMode == 'recent' ? 'Recent 12 Months' : 'Year $_historyMode', style: const TextStyle(fontWeight: FontWeight.w600)),
                              const Spacer(),
                              _paidFilterDropdown(),
                              IconButton(
                                tooltip: 'CSV Export (copies to clipboard)',
                                icon: const Icon(Icons.download, size: 20),
                                onPressed: _exportCsv,
                              ),
                              IconButton(
                                tooltip: 'PDF Export',
                                icon: const Icon(Icons.picture_as_pdf, size: 20),
                                onPressed: _exportPdf,
                              ),
                              IconButton(
                                tooltip: 'Print / Export View',
                                icon: const Icon(Icons.print, size: 20),
                                onPressed: _showPrintDialog,
                              )
                            ],
                          ),
                          const Divider(height: 12),
                          ..._displayHistory.map((h) => _historyRow(h)).toList(),
                        ],
                      ),
              ),
            )
        ],
      ),
    );
  }

  Widget _historyRow(MonthlySalaryRecord rec) {
    final present = widget.provider.presentCount(widget.member.name, rec.year, rec.month);
    final absent = widget.provider.absentCount(widget.member.name, rec.year, rec.month);
    if (_paidFilter == 'paid' && !rec.paid) return const SizedBox.shrink();
    if (_paidFilter == 'unpaid' && rec.paid) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 90, child: Text('${rec.month.toString().padLeft(2,'0')}/${rec.year}')),
        Expanded(child: Text('₹${rec.totalSalary.toStringAsFixed(0)}${rec.paid ? ' • Paid' : ''}', style: TextStyle(color: rec.paid ? Colors.green.shade700 : null))),
        SizedBox(width: 54, child: Text('P:$present', style: const TextStyle(fontSize: 12))),
        SizedBox(width: 54, child: Text('A:$absent', style: const TextStyle(fontSize: 12))),
        SizedBox(width: 90, child: Text(_formatDate(rec.paymentDate), style: const TextStyle(fontSize: 12))),
      ]),
    );
  }

  Widget _yearSelector() {
    final years = _availableYears;
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _historyMode == 'recent' ? 'recent' : _historyMode,
        items: [
          const DropdownMenuItem(value: 'recent', child: Text('Recent 12')),
          ...years.map((y) => DropdownMenuItem(value: y.toString(), child: Text(y.toString()))),
        ],
        onChanged: (v) => setState(() => _historyMode = v ?? 'recent'),
      ),
    );
  }

  Widget _paidFilterDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _paidFilter,
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All')),
          DropdownMenuItem(value: 'paid', child: Text('Paid')),
          DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
        ],
        onChanged: (v) => setState(() => _paidFilter = v ?? 'all'),
      ),
    );
  }
}

