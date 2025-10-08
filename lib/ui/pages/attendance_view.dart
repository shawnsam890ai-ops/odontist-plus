import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/staff_attendance_provider.dart';
import '../../models/staff_member.dart';
import 'package:url_launcher/url_launcher.dart';

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
                    final p = provider.presentCount(name, _month.year, _month.month);
                    final a = provider.absentCount(name, _month.year, _month.month);
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
                                const SizedBox(height: 2),
                                Text('P:$p A:$a', style: const TextStyle(fontSize: 11)),
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
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _monthlySalaryController,
                      decoration: const InputDecoration(labelText: 'Monthly Salary'),
                      keyboardType: TextInputType.number,
                      onSubmitted: (v) {
                        final val = double.tryParse(v) ?? 0;
                        provider.setMonthlySalary(selectedStaff, _month.year, _month.month, val);
                        setState(() {});
                      },
                    ),
                  )
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      childAspectRatio: .9,
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
                        child: Container(
                          decoration: BoxDecoration(
                            color: _cellColor(state),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          alignment: Alignment.center,
                          child: Text('${day.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: state == false ? Colors.white : Colors.black87,
                              )),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      final val = double.tryParse(_monthlySalaryController.text) ?? 0;
                      provider.setMonthlySalary(selectedStaff, _month.year, _month.month, val);
                      setState(() {});
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Salary'),
                  ),
                  ElevatedButton.icon(
                    onPressed: paid
                        ? null
                        : () {
              provider.markSalaryPaid(selectedStaff, _month.year, _month.month,
                amount: double.tryParse(_monthlySalaryController.text));
                            setState(() {});
                          },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark Paid'),
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
