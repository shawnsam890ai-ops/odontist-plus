import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/doctor_attendance_provider.dart';
import '../../models/doctor.dart';
import '../../models/payment_rule.dart';
import '../../models/procedures.dart';
import '../../models/payment_entry.dart';
import '../../core/upi_launcher.dart' as upi;

class DoctorsPaymentsSection extends StatelessWidget {
  const DoctorsPaymentsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorProvider>();
    final doctors = provider.doctors;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LayoutBuilder(builder: (context, c) {
              final narrow = c.maxWidth < 700;
              if (!narrow) {
                return Row(children: [
                  Text('Doctors Attendance & Payments', style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  Row(children: [
                    const Text('Require attendance', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Switch(
                      value: provider.requireAttendance,
                      onChanged: provider.setRequireAttendance,
                    ),
                    const SizedBox(width: 12),
                  ]),
                  FilledButton.icon(
                    onPressed: () => _showAddDoctorDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Doctor'),
                  ),
                ]);
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Doctors Attendance & Payments', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('Require attendance', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Switch(
                    value: provider.requireAttendance,
                    onChanged: provider.setRequireAttendance,
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _showAddDoctorDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Doctor'),
                  ),
                ]),
              ]);
            }),
            const SizedBox(height: 16),
            if (doctors.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No doctors added yet')))
            else
              _DoctorsList(),
            const SizedBox(height: 20),
            _LedgerSection(),
          ]),
        ),
      ),
    );
  }

  void _showAddDoctorDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
  DoctorRole role = DoctorRole.endodontist;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Doctor'),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            StatefulBuilder(builder: (context, setSt) {
              return DropdownButtonFormField<DoctorRole>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role in clinic'),
                items: DoctorRole.values
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.label())))
                    .toList(),
                onChanged: (v) => setSt(() => role = v ?? role),
              );
            }),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final id = DateTime.now().microsecondsSinceEpoch.toString();
              context.read<DoctorProvider>().addDoctor(Doctor(id: id, name: name, role: role));
              Navigator.pop(context);
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  // Role labels are provided by DoctorRole.label() extension in the model.
}

class _DoctorsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorProvider>();
    final docs = provider.doctors;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const ListTile(title: Text('Doctors')),
          const Divider(height: 1),
          for (final d in docs) _DoctorTile(d),
        ],
      ),
    );
  }
}

class _DoctorTile extends StatelessWidget {
  final Doctor d;
  const _DoctorTile(this.d);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorProvider>();
    final rules = d.rules;
    final s = provider.summaryFor(d.id);
    return ExpansionTile(
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text('${d.name} • ${d.role.label()}'),
        const SizedBox(height: 4),
        Text('Doctor: ₹${s.doctorEarned.toStringAsFixed(0)}  •  Payouts: ₹${s.payouts.toStringAsFixed(0)}  •  Outstanding: ₹${s.outstanding.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ]),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Switch(
          value: d.active,
          onChanged: (v) => provider.updateDoctor(d.id, active: v),
        ),
        IconButton(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit),
          onPressed: () => _showEditDoctorDialog(context, d),
        ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => provider.removeDoctor(d.id),
        ),
      ]),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Payment Rules', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddRuleDialog(context, d.id),
                icon: const Icon(Icons.add),
                label: const Text('Add Rule'),
              )
            ]),
            const SizedBox(height: 8),
            if (rules.isEmpty)
              const Text('No rules set')
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in rules.entries) _RuleChip(doctorId: d.id, procedureKey: e.key, rule: e.value)
              ]),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => _showRecordPaymentDialog(context, d.id),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Record Payment'),
              ),
            )
          ]),
        )
      ],
    );
  }

  void _showEditDoctorDialog(BuildContext context, Doctor d) {
    final nameCtrl = TextEditingController(text: d.name);
    DoctorRole role = d.role;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Doctor'),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            StatefulBuilder(builder: (context, setSt) {
              return DropdownButtonFormField<DoctorRole>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role in clinic'),
        items: DoctorRole.values
          .map((r) => DropdownMenuItem(value: r, child: Text(r.label())))
          .toList(),
                onChanged: (v) => setSt(() => role = v ?? role),
              );
            }),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              context.read<DoctorProvider>().updateDoctor(d.id, name: name, role: role);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  void _showAddRuleDialog(BuildContext context, String doctorId) {
    final procCtrl = ValueNotifier<String>(Procedures.rct);
    final modeCtrl = ValueNotifier<PaymentMode>(PaymentMode.fixed);
    final valueCtrl = TextEditingController(text: '0');
    final priceCtrl = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Payment Rule'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: procCtrl.value,
              decoration: const InputDecoration(labelText: 'Procedure'),
              items: const [
                DropdownMenuItem(value: Procedures.rct, child: Text('Root Canal (RCT)')),
                DropdownMenuItem(value: Procedures.ortho, child: Text('Orthodontic (Ortho)')),
                DropdownMenuItem(value: Procedures.prostho, child: Text('Prosthodontic')),
                DropdownMenuItem(value: Procedures.perio, child: Text('Periodontic')),
                DropdownMenuItem(value: Procedures.pedo, child: Text('Pedodontic')),
                DropdownMenuItem(value: Procedures.oms, child: Text('Oral & Maxillofacial Surgery')),
              ],
              onChanged: (v) => procCtrl.value = v ?? Procedures.rct,
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<PaymentMode>(
              valueListenable: modeCtrl,
              builder: (context, mode, _) => DropdownButtonFormField<PaymentMode>(
                value: mode,
                decoration: const InputDecoration(labelText: 'Doctor Share Type'),
                items: const [
                  DropdownMenuItem(value: PaymentMode.fixed, child: Text('Fixed amount')),
                  DropdownMenuItem(value: PaymentMode.percent, child: Text('Percent')),
                ],
                onChanged: (m) => modeCtrl.value = m ?? PaymentMode.fixed,
              ),
            ),
            const SizedBox(height: 8),
            TextField(controller: valueCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Doctor share (amount or %)')),
            const SizedBox(height: 8),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Clinic price (optional)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final key = procCtrl.value;
              final mode = modeCtrl.value;
              final val = double.tryParse(valueCtrl.text) ?? 0;
              final price = double.tryParse(priceCtrl.text);
              final rule = mode == PaymentMode.fixed ? PaymentRule.fixed(val, clinicPrice: price) : PaymentRule.percent(val, clinicPrice: price);
              context.read<DoctorProvider>().setRule(doctorId, key, rule);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }
}

void _showRecordPaymentDialog(BuildContext context, String doctorId) {
  final proc = ValueNotifier<String>(Procedures.rct);
  final amountCtrl = TextEditingController(text: '0');
  final patientCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  DateTime date = DateTime.now();
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Record Payment'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: proc.value,
            decoration: const InputDecoration(labelText: 'Procedure'),
            items: const [
              DropdownMenuItem(value: Procedures.rct, child: Text('Root Canal (RCT)')),
              DropdownMenuItem(value: Procedures.ortho, child: Text('Orthodontic (Ortho)')),
              DropdownMenuItem(value: Procedures.prostho, child: Text('Prosthodontic')),
              DropdownMenuItem(value: Procedures.perio, child: Text('Periodontic')),
              DropdownMenuItem(value: Procedures.pedo, child: Text('Pedodontic')),
              DropdownMenuItem(value: Procedures.oms, child: Text('OMS')),
            ],
            onChanged: (v) => proc.value = v ?? Procedures.rct,
          ),
          const SizedBox(height: 8),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount received (this visit)')),
          const SizedBox(height: 8),
          TextField(controller: patientCtrl, decoration: const InputDecoration(labelText: 'Patient (optional)')),
          const SizedBox(height: 8),
          TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Date:'),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 1));
                if (picked != null) {
                  date = picked;
                }
              },
              child: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
            ),
          ])
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final amt = double.tryParse(amountCtrl.text) ?? 0;
            final attendance = context.read<DoctorAttendanceProvider>();
            final provider = context.read<DoctorProvider>();
            final err = provider.recordPayment(
              doctorId: doctorId,
              procedureKey: proc.value,
              amountReceived: amt,
              date: date,
              patient: patientCtrl.text.trim().isEmpty ? null : patientCtrl.text.trim(),
              note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              attendance: attendance,
            );
            if (err != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              return;
            }
            Navigator.pop(context);
          },
          child: const Text('Save'),
        )
      ],
    ),
  );
}

class _LedgerSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorProvider>();
    // Filters UI
    String? doctorFilter;
    String? procFilter;
    DateTime? start;
    DateTime? end;
    return StatefulBuilder(builder: (context, setSt) {
      final entries = provider
          .filteredLedger(doctorId: doctorFilter, procedureKey: procFilter, start: start, end: end)
          .reversed
          .toList();
      final allDocs = provider.doctors;
      // Compute totals for current view (exclude payouts)
      double filteredDoctorTotal = 0, filteredClinicTotal = 0;
      for (final e in entries) {
        if (e.type == EntryType.payment) {
          filteredDoctorTotal += e.doctorShare;
          filteredClinicTotal += e.clinicShare;
        }
      }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Payments Ledger', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _showMakePayoutDialog(context),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Make Payment'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final csv = provider.exportCsv(entries);
                  _showCsvDialog(context, csv);
                },
                icon: const Icon(Icons.download),
                label: const Text('Export CSV'),
              )
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  value: doctorFilter,
                  decoration: const InputDecoration(labelText: 'Doctor'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All')),
                    for (final d in allDocs) DropdownMenuItem<String?>(value: d.id, child: Text(d.name)),
                  ],
                  onChanged: (v) => setSt(() => doctorFilter = v),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  value: procFilter,
                  decoration: const InputDecoration(labelText: 'Procedure'),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('All')),
                    DropdownMenuItem<String?>(value: Procedures.rct, child: Text('RCT')),
                    DropdownMenuItem<String?>(value: Procedures.ortho, child: Text('Ortho')),
                    DropdownMenuItem<String?>(value: Procedures.prostho, child: Text('Prostho')),
                    DropdownMenuItem<String?>(value: Procedures.perio, child: Text('Perio')),
                    DropdownMenuItem<String?>(value: Procedures.pedo, child: Text('Pedo')),
                    DropdownMenuItem<String?>(value: Procedures.oms, child: Text('OMS')),
                  ],
                  onChanged: (v) => setSt(() => procFilter = v),
                ),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                OutlinedButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(context: context, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 1));
                    if (picked != null) setSt(() { start = picked.start; end = picked.end; });
                  },
                  child: Text(start == null ? 'Date range' : '${start!.year}-${start!.month.toString().padLeft(2,'0')}-${start!.day.toString().padLeft(2,'0')}  →  ${end!.year}-${end!.month.toString().padLeft(2,'0')}-${end!.day.toString().padLeft(2,'0')}'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Clear filters',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setSt(() { doctorFilter = null; procFilter = null; start = null; end = null; }),
                ),
              ])
            ]),
            const SizedBox(height: 8),
            Text('Totals — Doctor: ₹${filteredDoctorTotal.toStringAsFixed(0)}    Clinic: ₹${filteredClinicTotal.toStringAsFixed(0)}'),
          ]),
        ),
        const Divider(height: 1),
        if (entries.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No payments recorded yet'))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = entries[i];
              final d = provider.byId(e.doctorId);
              final dateStr = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
              final isPayout = e.type == EntryType.payout;
              // Build a human-friendly subtitle, hiding raw rx: tags similar to revenue ledger
              final friendly = _prettyLedgerSubtitle(context, e, dateStr);
              return ListTile(
                title: Text('${d?.name ?? e.doctorId} • ${isPayout ? 'PAYOUT' : e.procedureKey.toUpperCase()} • ${isPayout ? '₹${e.doctorShare.toStringAsFixed(0)}' : '₹${e.amountReceived.toStringAsFixed(0)}'}'),
                subtitle: Text(friendly),
                trailing: IconButton(
                  tooltip: 'Delete entry',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete entry?'),
                        content: const Text('This will permanently remove the ledger entry.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      context.read<DoctorProvider>().deleteLedgerEntry(e.id);
                    }
                  },
                ),
              );
            },
          ),
      ]),
    );
    });
  }

  // Hide raw rx: tags and show patient/purpose more nicely, similar to revenue ledger behavior.
  String _prettyLedgerSubtitle(BuildContext context, PaymentEntry e, String dateStr) {
    final base = StringBuffer();
    final isPayout = e.type == EntryType.payout;
    if (!isPayout) {
      base.write('Doctor: ₹${e.doctorShare.toStringAsFixed(0)}  |  Clinic: ₹${e.clinicShare.toStringAsFixed(0)}  •  ');
    }
    base.write(dateStr);
    if (e.mode != null) base.write('  •  ${e.mode}');
    // If note contains rx:<sessionId>:... convert to readable label using existing revenue logic pattern
    if (e.note != null && e.note!.startsWith('rx:')) {
      final desc = _friendlyDescriptionFromRx(context, e);
      if (desc != null) base.write('  •  $desc');
    } else if (e.patient != null) {
      base.write('  •  ${e.patient}');
    } else if (e.note != null) {
      base.write('  •  ${e.note}');
    }
    return base.toString();
  }

  String? _friendlyDescriptionFromRx(BuildContext context, PaymentEntry e) {
    // We only have patient name in PaymentEntry, not patientId/session graph here.
    // Prefer showing patient name if available; otherwise hide the opaque rx tag.
    if (e.patient != null && e.patient!.isNotEmpty) return e.patient;
    return null;
  }
}

void _showCsvDialog(BuildContext context, String csv) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Export CSV'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(child: SelectableText(csv)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    ),
  );
}

void _showMakePayoutDialog(BuildContext context) {
  final provider = context.read<DoctorProvider>();
  final allDocs = provider.doctors;
  if (allDocs.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No doctors available')));
    return;
  }
  String doctorId = allDocs.first.id;
  final amountCtrl = TextEditingController(text: '0');
  final noteCtrl = TextEditingController();
  final modeCtrl = ValueNotifier<String>('Cash');
  DateTime date = DateTime.now();
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Make Payment to Doctor'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: doctorId,
            decoration: const InputDecoration(labelText: 'Doctor'),
            items: [for (final d in allDocs) DropdownMenuItem(value: d.id, child: Text(d.name))],
            onChanged: (v) => doctorId = v ?? doctorId,
          ),
          const SizedBox(height: 8),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
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
          TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Date:'),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 1));
                if (picked != null) {
                  date = picked;
                }
              },
              child: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
            ),
          ])
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        // Show Pay via UPI when selected
        ValueListenableBuilder<String>(
          valueListenable: modeCtrl,
          builder: (ctx, mode, _) {
            if (mode != 'UPI') return const SizedBox.shrink();
            return TextButton.icon(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Pay via UPI'),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0;
                final doctorName = provider.byId(doctorId)?.name ?? 'Doctor';
                final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                final extra = noteCtrl.text.trim();
                final note = 'Doctor payout — $doctorName — $dateStr' + (extra.isEmpty ? '' : ' — $extra');
                await upi.launchUPIPayment(
                  context: context,
                  amount: amt > 0 ? amt : null,
                  note: note,
                );
              },
            );
          },
        ),
        ElevatedButton(
          onPressed: () async {
            final amt = double.tryParse(amountCtrl.text) ?? 0;
            if (amt <= 0) return;
            // For UPI, ask if the payment completed to keep ledger consistent.
            if (modeCtrl.value == 'UPI') {
              final doctorName = provider.byId(doctorId)?.name ?? 'doctor';
              final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final completed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('UPI Payment Completed?'),
                  content: Text('Did the UPI payment of ₹${amt.toStringAsFixed(0)} to $doctorName on $dateStr complete successfully?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Completed')),
                  ],
                ),
              );
              if (completed != true) return; // Don't record unless confirmed completed
            } else {
              // Non-UPI modes: regular confirmation
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Confirm Payment'),
                  content: Text('Pay ₹${amt.toStringAsFixed(0)} to ${provider.byId(doctorId)?.name ?? 'doctor'}?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
                  ],
                ),
              );
              if (confirm != true) return;
            }
            provider.recordPayoutWithMode(
              doctorId: doctorId,
              amount: amt,
              date: date,
              note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              mode: modeCtrl.value,
            );
            Navigator.pop(context);
          },
          child: const Text('Done'),
        )
      ],
    ),
  );
}

class _RuleChip extends StatelessWidget {
  final String doctorId;
  final String procedureKey;
  final PaymentRule rule;
  const _RuleChip({required this.doctorId, required this.procedureKey, required this.rule});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorProvider>();
    final label = _ruleLabel(procedureKey, rule);
    return InputChip(
      label: Text(label),
      onDeleted: () => provider.removeRule(doctorId, procedureKey),
    );
  }

  String _ruleLabel(String key, PaymentRule r) {
    String proc;
    switch (key) {
      case Procedures.rct:
        proc = 'RCT';
        break;
      case Procedures.ortho:
        proc = 'Ortho';
        break;
      case Procedures.prostho:
        proc = 'Prostho';
        break;
      case Procedures.perio:
        proc = 'Perio';
        break;
      case Procedures.pedo:
        proc = 'Pedo';
        break;
      case Procedures.oms:
        proc = 'OMS';
        break;
      default:
        proc = key;
    }
    final val = r.mode == PaymentMode.fixed ? '₹${r.value.toStringAsFixed(0)}' : '${r.value.toStringAsFixed(0)}%';
    return '$proc — $val';
  }
}

class _AllocationQuickCalc extends StatefulWidget {
  final String doctorId;
  const _AllocationQuickCalc({required this.doctorId});

  @override
  State<_AllocationQuickCalc> createState() => _AllocationQuickCalcState();
}

class _AllocationQuickCalcState extends State<_AllocationQuickCalc> {
  String proc = Procedures.rct;
  final amtCtrl = TextEditingController(text: '0');

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorProvider>();
    final charge = double.tryParse(amtCtrl.text) ?? 0;
    final split = provider.allocate(widget.doctorId, proc, charge);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Quick Allocation Calculator', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              return Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: proc,
                    decoration: const InputDecoration(labelText: 'Procedure'),
                    items: const [
                      DropdownMenuItem(value: Procedures.rct, child: Text('Root Canal (RCT)')),
                      DropdownMenuItem(value: Procedures.ortho, child: Text('Orthodontic (Ortho)')),
                      DropdownMenuItem(value: Procedures.prostho, child: Text('Prosthodontic')),
                      DropdownMenuItem(value: Procedures.perio, child: Text('Periodontic')),
                      DropdownMenuItem(value: Procedures.pedo, child: Text('Pedodontic')),
                      DropdownMenuItem(value: Procedures.oms, child: Text('OMS')),
                    ],
                    onChanged: (v) => setState(() => proc = v ?? Procedures.rct),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: amtCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Charge amount (this visit)'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Doctor: ₹${split.$1.toStringAsFixed(0)}  |  Clinic: ₹${split.$2.toStringAsFixed(0)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}
