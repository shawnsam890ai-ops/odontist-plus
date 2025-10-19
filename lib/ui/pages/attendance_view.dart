import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/staff_attendance_provider.dart';
import '../../models/staff_member.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/upi_launcher.dart' as upi;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../widgets/staff_attendance_widget.dart';
import '../widgets/dental_id_card.dart';
import '../../providers/holidays_provider.dart';
// Removed patient / session imports after extracting schedule panel to dashboard

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
  int _staffIdx = 0;
  bool _staffToggleMode = true; // false = list (scroll), true = single with chevrons (default)

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StaffAttendanceProvider>();
    final staffList = provider.staffNames;
    // Auto-select first staff if none selected so calendar shows by default
    if (_staff == null && staffList.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _staff == null) setState(() { _staff = staffList.first; _staffIdx = 0; });
      });
    }
    final selectedStaff = _staff;

    final calendarCard = selectedStaff == null
        ? const Center(child: Text('Add staff to view attendance'))
        : Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              // Increased only the parent container height; attendance widget unchanged
              child: SizedBox(height: 420, child: StaffAttendanceWidget(showHeader: false, selectedStaff: selectedStaff, showMonthToggle: true)),
            ),
          );
    
    Widget staffPanel({required bool boundedHeight}) {
      return Card(
        color: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(children: [
            Row(children: [
              const Expanded(child: Text('Staff', style: TextStyle(fontWeight: FontWeight.w700))),
              IconButton(onPressed: _showAddStaffDialog, icon: const Icon(Icons.add)),
              IconButton(
                tooltip: 'Toggle staff navigator',
                onPressed: () => setState(() => _staffToggleMode = !_staffToggleMode),
                icon: Icon(_staffToggleMode ? Icons.view_list : Icons.swap_horiz),
              )
            ]),
            const SizedBox(height: 8),
            if (boundedHeight)
              Expanded(child: _buildStaffContent(provider, staffList, selectedStaff, boundedHeight: true))
            else
              _buildStaffContent(provider, staffList, selectedStaff, shrinkWrap: true, boundedHeight: false),
          ]),
        ),
      );
    }

    Widget calendarPanel() => Card(clipBehavior: Clip.antiAlias, child: calendarCard);

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final isNarrow = width < 1040;

      // Narrow layout: allow vertical scrolling so tall content (like the
      // staff ID card) can expand without causing an overflow.
      if (isNarrow) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // No fixed height; let the panel grow and the whole page scroll.
            staffPanel(boundedHeight: false),
            const SizedBox(height: 12),
            calendarPanel(),
          ]),
        );
      }

      // Wide layout: keep side-by-side layout and let the parent (scaffold)
      // constrain height — no vertical scroll here by default.
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: _staffCollapsed ? 52 : 260, child: staffPanel(boundedHeight: true)),
          const SizedBox(width: 16),
          Expanded(child: calendarCard),
        ]),
      );
    });
  }

  Widget _buildStaffContent(StaffAttendanceProvider provider, List<String> staffList, String? selectedStaff, {bool shrinkWrap = false, required bool boundedHeight}) {
    if (_staffToggleMode) {
      final Widget toggleRow = Row(
        children: [
          IconButton(
            onPressed: staffList.isEmpty
                ? null
                : () => setState(() {
                      _staffIdx = (_staffIdx - 1 + staffList.length) % staffList.length;
                      _staff = staffList[_staffIdx];
                    }),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Builder(builder: (ctx) {
              if (staffList.isEmpty) return const SizedBox.shrink();
              final name = staffList[_staffIdx];
              final member = provider.staffMembers.firstWhere((m) => m.name == name, orElse: () => StaffMember(id: '', name: name));
              return GestureDetector(
                onTap: () => setState(() {
                  _staff = name;
                  _staffIdx = staffList.indexOf(name);
                }),
                child: DentalIdCard(
                  name: member.name,
                  age: member.age?.toString(),
                  sex: member.sex,
                  bloodGroup: member.bloodGroup,
                  address: member.address,
                  phoneNumber: member.phoneNumbers.isNotEmpty ? member.phoneNumbers.first : null,
                  emergencyContactNumber: member.emergencyContact?.phone,
                  emergencyContactName: member.emergencyContact?.name,
                ),
              );
            }),
          ),
          IconButton(
            onPressed: staffList.isEmpty
                ? null
                : () => setState(() {
                      _staffIdx = (_staffIdx + 1) % staffList.length;
                      _staff = staffList[_staffIdx];
                    }),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      );

      // When height is bounded (wide layout), allow the toggle content to scroll
      // vertically to avoid bottom overflow for tall ID cards.
      if (boundedHeight) {
        // Use a ListView to allow vertical scrolling within the staff panel
        // when the available height is bounded (wide layout).
        return ListView(
          padding: EdgeInsets.zero,
          children: [toggleRow],
        );
      }

      // Unbounded (narrow) layout: just return the row; the outer page scrolls.
      return toggleRow;
    }

    // Staff list
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: staffList.length,
      itemBuilder: (c, i) {
        final name = staffList[i];
        final isSelected = name == selectedStaff;
        final member = provider.staffMembers.firstWhere((m) => m.name == name, orElse: () => StaffMember(id: '', name: name));
        final primaryPhone = member.phoneNumbers.isNotEmpty ? member.phoneNumbers.first : '';
        return GestureDetector(
          onTap: () => setState(() {
            _staff = name;
            _staffIdx = i;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.06) : Theme.of(context).colorScheme.surface,
              border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor.withOpacity(0.12)),
              borderRadius: BorderRadius.circular(10),
            ),
                          child: Row(children: [
              Expanded(
                child: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? Theme.of(context).colorScheme.primary : null)),
              ),
              Row(children: [
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
                                tooltip: 'Record Payment',
                                icon: const Icon(Icons.payments, size: 18),
                                onPressed: () => _showRecordPaymentDialog(member.name),
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
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () => _confirmDeleteStaff(provider, member.name),
                              ),
              ])
            ]),
          ),
        );
      },
    );
  }

  List<DateTime> _daysInMonth() {
    final first = DateTime(_month.year, _month.month, 1);
    final last = DateTime(_month.year, _month.month + 1, 0);
    return List.generate(last.day, (i) => DateTime(first.year, first.month, i + 1));
  }

  String _monthLabel(DateTime m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[m.month - 1]} ${m.year}';
  }


  // Removed: appointment schedule helper widgets and state since schedule moved out
    
  Future<void> _launchUPIPayment({required String staffName, required double amount, required DateTime date, String? extraNote}) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final note = 'Staff salary — $staffName — $dateStr' + ((extraNote == null || extraNote.trim().isEmpty) ? '' : ' — ${extraNote.trim()}');
    await upi.launchUPIPayment(
      context: context,
      amount: amount > 0 ? amount : null,
      note: note,
    );
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
    // Medical information
    final medAllergyCtrl = TextEditingController();
    final medConditionsCtrl = TextEditingController();
    final medicationsCtrl = TextEditingController();
    String? bloodGroup;
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
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Medical Information', style: Theme.of(context).textTheme.titleSmall),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: bloodGroup,
                          decoration: const InputDecoration(labelText: 'Blood Group'),
                          items: const [
                            DropdownMenuItem(value: 'A+', child: Text('A+')),
                            DropdownMenuItem(value: 'A-', child: Text('A-')),
                            DropdownMenuItem(value: 'B+', child: Text('B+')),
                            DropdownMenuItem(value: 'B-', child: Text('B-')),
                            DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                            DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                            DropdownMenuItem(value: 'O+', child: Text('O+')),
                            DropdownMenuItem(value: 'O-', child: Text('O-')),
                          ],
                          onChanged: (v) => bloodGroup = v,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(controller: medAllergyCtrl, decoration: const InputDecoration(labelText: 'Any Food Allergy?')),
                        const SizedBox(height: 12),
                        TextFormField(controller: medConditionsCtrl, decoration: const InputDecoration(labelText: 'Any Medical Conditions?')),
                        const SizedBox(height: 12),
                        TextFormField(controller: medicationsCtrl, decoration: const InputDecoration(labelText: 'Currently Under Any Medications?')),
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
                                  bloodGroup: bloodGroup,
                                  foodAllergy: medAllergyCtrl.text.trim().isEmpty ? null : medAllergyCtrl.text.trim(),
                                  medicalConditions: medConditionsCtrl.text.trim().isEmpty ? null : medConditionsCtrl.text.trim(),
                                  medications: medicationsCtrl.text.trim().isEmpty ? null : medicationsCtrl.text.trim(),
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

  // ignore: unused_element
  Future<void> _showHolidayDialog() async {
    final holidays = context.read<HolidaysProvider>();
    final year = _month.year;
    final month = _month.month;
    final days = _daysInMonth();
    // make a mutable set of days currently marked
    final selected = holidays.holidaysForMonth(year, month).map((d) => d.day).toSet();

    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: 520,
            height: 420,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(children: [
                Row(children: [
                  const Text('Manage Holidays', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(_monthLabel(_month)),
                ]),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 7,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 1.1,
                    children: days.map((d) {
                      final isSel = selected.contains(d.day);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (isSel) {
                            selected.remove(d.day);
                          } else {
                            selected.add(d.day);
                          }
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSel ? Colors.grey.shade400 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSel ? Colors.grey.shade600 : Colors.transparent),
                          ),
                          alignment: Alignment.center,
                          child: Text('${d.day}', style: TextStyle(fontWeight: FontWeight.w600, color: isSel ? Colors.white : Colors.black87)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      final newH = days.where((d) => selected.contains(d.day)).toList();
                      holidays.setHolidays(newH);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  )
                ])
              ]),
            ),
          ),
        );
      },
    );
    setState(() {});
  }

  // ignore: unused_element
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
  String? bloodGroup = member.bloodGroup;
    // Medical info controllers
    final medAllergyCtrl = TextEditingController(text: member.foodAllergy ?? '');
    final medConditionsCtrl = TextEditingController(text: member.medicalConditions ?? '');
    final medicationsCtrl = TextEditingController(text: member.medications ?? '');

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
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Medical Information', style: Theme.of(context).textTheme.titleSmall)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: bloodGroup,
            decoration: const InputDecoration(labelText: 'Blood Group'),
            items: const [
              DropdownMenuItem(value: 'A+', child: Text('A+')),
              DropdownMenuItem(value: 'A-', child: Text('A-')),
              DropdownMenuItem(value: 'B+', child: Text('B+')),
              DropdownMenuItem(value: 'B-', child: Text('B-')),
              DropdownMenuItem(value: 'AB+', child: Text('AB+')),
              DropdownMenuItem(value: 'AB-', child: Text('AB-')),
              DropdownMenuItem(value: 'O+', child: Text('O+')),
              DropdownMenuItem(value: 'O-', child: Text('O-')),
            ],
            onChanged: (v) => bloodGroup = v,
          ),
          const SizedBox(height: 12),
          TextFormField(controller: medAllergyCtrl, decoration: const InputDecoration(labelText: 'Any Food Allergy?')),
          const SizedBox(height: 12),
          TextFormField(controller: medConditionsCtrl, decoration: const InputDecoration(labelText: 'Any Medical Conditions?')),
          const SizedBox(height: 12),
          TextFormField(controller: medicationsCtrl, decoration: const InputDecoration(labelText: 'Currently Under Any Medications?')),
          const SizedBox(height: 20),
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
                              foodAllergy: medAllergyCtrl.text.trim().isEmpty ? null : medAllergyCtrl.text.trim(),
                              medicalConditions: medConditionsCtrl.text.trim().isEmpty ? null : medConditionsCtrl.text.trim(),
                              medications: medicationsCtrl.text.trim().isEmpty ? null : medicationsCtrl.text.trim(),
                              bloodGroup: bloodGroup,
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

  Future<void> _showRecordPaymentDialog(String staffName) async {
    final provider = context.read<StaffAttendanceProvider>();
    final rec = provider.ensureSalaryRecord(staffName, _month.year, _month.month);
    final amount = rec.totalSalary;
    DateTime date = rec.paymentDate ?? DateTime.now();
    String mode = rec.paymentMode ?? 'Cash';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record Payment - $staffName'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount: ₹${amount.toStringAsFixed(0)}'),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Date: '),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) {
                      date = picked;
                      (ctx as Element).markNeedsBuild();
                    }
                  },
                  child: Text('${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}'),
                )
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: mode,
                decoration: const InputDecoration(labelText: 'Mode of Transaction'),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(value: 'Bank', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    mode = v;
                    // Rebuild the dialog to reflect action button changes
                    (ctx as Element).markNeedsBuild();
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          if (mode == 'UPI')
            TextButton.icon(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Pay via UPI'),
              onPressed: () async {
                await _launchUPIPayment(staffName: staffName, amount: amount, date: date);
              },
            ),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Mark Paid'),
            onPressed: () async {
              if (mode == 'UPI') {
                final completed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('UPI Payment Completed?'),
                    content: Text('Did the UPI payment of ₹${amount.toStringAsFixed(0)} to $staffName on ${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year} complete successfully?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Completed')),
                    ],
                  ),
                );
                if (completed != true) return;
              }
              provider.markSalaryPaid(staffName, _month.year, _month.month, amount: amount, mode: mode, date: date);
              Navigator.pop(ctx);
              setState(() {});
            },
          )
        ],
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
  // ignore: unused_element
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

  // ignore: unused_element
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

  // ignore: unused_element
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

// Removed _ApptEntry class (schedule extraction)

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
              _row('Blood Group', (member.bloodGroup == null || member.bloodGroup!.trim().isEmpty) ? '—' : member.bloodGroup!),
              _row('Food Allergy', (member.foodAllergy == null || member.foodAllergy!.trim().isEmpty) ? 'NIL' : member.foodAllergy!),
              _row('Medical Conditions', (member.medicalConditions == null || member.medicalConditions!.trim().isEmpty) ? 'NIL' : member.medicalConditions!),
              _row('Medications', (member.medications == null || member.medications!.trim().isEmpty) ? 'NIL' : member.medications!),
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
                          ..._displayHistory.map((h) => _historyRow(h)),
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

