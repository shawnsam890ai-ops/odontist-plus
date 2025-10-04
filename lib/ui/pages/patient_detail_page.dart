import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/patient_provider.dart';
import '../../core/enums.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/treatment_session.dart';
import '../widgets/multi_select_dropdown.dart';

class PatientDetailPage extends StatefulWidget {
  static const routeName = '/patient-detail';
  final String? patientId;
  const PatientDetailPage({super.key, required this.patientId});

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  TreatmentType _selectedType = TreatmentType.general;
  String? _followUpParentId; // if creating follow-up session

  // General form controllers (simplified initial prototype)
  List<String> _selectedComplaints = [];
  List<String> _selectedQuadrants = [];
  final List<OralExamFinding> _oralFindings = [];
  final List<InvestigationType> _investigations = [];
  final List<InvestigationFinding> _investigationFindings = [];
  // Legacy multi-select treatment plan kept but not shown now
  final List<String> _treatmentPlan = [];
  // New structured per-tooth plan & treatments done
  final List<ToothPlanEntry> _toothPlans = [];
  final List<ToothTreatmentDoneEntry> _treatmentsDone = [];
  final List<String> _mediaPaths = [];
  DateTime? _nextAppointment;
  final TextEditingController _notes = TextEditingController();
  // Prescription builder state
  final List<PrescriptionItem> _prescription = [];
  String? _rxSelectedMedicine;
  final TextEditingController _rxTiming = TextEditingController();
  final TextEditingController _rxTablets = TextEditingController();
  final TextEditingController _rxDays = TextEditingController();
  // Inline oral exam entry controllers
  final TextEditingController _inlineToothController = TextEditingController();
  final TextEditingController _inlineFindingController = TextEditingController();

  // Ortho
  final TextEditingController _orthoFindings = TextEditingController();
  BracketType _bracketType = BracketType.metalRegular;
  final TextEditingController _orthoTotal = TextEditingController();
  final TextEditingController _orthoDoctor = TextEditingController();
  final List<ProcedureStep> _orthoSteps = [];

  // Root Canal
  final List<OralExamFinding> _rcFindings = [];
  final TextEditingController _rcTotal = TextEditingController();
  final List<ProcedureStep> _rcSteps = [];

  @override
  Widget build(BuildContext context) {
    final patientProvider = context.watch<PatientProvider>();
    final patient = widget.patientId == null ? null : patientProvider.byId(widget.patientId!);

    if (patient == null) {
      return const Scaffold(body: Center(child: Text('Patient not found')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(patient.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _basicInfoCard(patient),
            const SizedBox(height: 16),
            _typeSelector(),
            const SizedBox(height: 16),
            _buildTypeForm(),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final session = _createSession();
                await context.read<PatientProvider>().addSession(patient.id, session);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session saved.')));
              },
              icon: const Icon(Icons.save),
              label: const Text('Save Session'),
            )
          ],
        ),
      ),
    );
  }

  Widget _basicInfoCard(patient) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('ID: ${patient.displayNumber}${patient.customNumber.isNotEmpty ? ' (${patient.customNumber})' : ''}')),
                IconButton(
                  tooltip: 'Edit Custom ID',
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () async {
                    final controller = TextEditingController(text: patient.customNumber);
                    final newVal = await showDialog<String>(
                        context: context,
                        builder: (_) => AlertDialog(
                              title: const Text('Edit Custom Patient ID'),
                              content: TextField(
                                controller: controller,
                                decoration: const InputDecoration(labelText: 'Custom ID'),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save'))
                              ],
                            ));
                    if (newVal != null) {
                      await context.read<PatientProvider>().updateCustomNumber(patient.id, newVal);
                    }
                  },
                ),
              ],
            ),
            Text('Name: ${patient.name}'),
            Text('Age/Sex: ${patient.age}/${patient.sex.label}'),
            Text('Phone: ${patient.phone}'),
            Text('Address: ${patient.address}'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              ElevatedButton.icon(
                onPressed: () => _openLabWork(patient.id),
                icon: const Icon(Icons.biotech, size: 18),
                label: const Text('Lab Work'),
              ),
              if (_followUpParentId != null)
                OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _followUpParentId = null;
                      });
                    },
                    child: const Text('Cancel Follow-Up'))
            ])
          ],
        ),
      ),
    );
  }

  Widget _typeSelector() {
    return Row(
      children: [
        const Text('Type:'),
        const SizedBox(width: 12),
        DropdownButton<TreatmentType>(
          value: _selectedType,
          items: TreatmentType.values
              .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
              .toList(),
          onChanged: (v) => setState(() => _selectedType = v ?? TreatmentType.general),
        )
      ],
    );
  }

  Widget _buildTypeForm() {
    switch (_selectedType) {
      case TreatmentType.general:
        return _generalForm();
      case TreatmentType.orthodontic:
        return _orthoForm();
      case TreatmentType.rootCanal:
        return _rootCanalForm();
      case TreatmentType.labWork:
        return const Text('Lab work linking handled separately');
    }
  }

  // (Removed old chip selector - switched to MultiSelectDropdown)

  Widget _generalForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Chief Complaint & Quadrants
        if (_followUpParentId == null) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('1. Chief Complaint'),
                  MultiSelectDropdown(
                    options: AppConstants.chiefComplaints,
                    initialSelected: _selectedComplaints,
                    label: 'Complaint Type',
                    onChanged: (vals) => setState(() => _selectedComplaints = vals),
                  ),
                  const SizedBox(height: 12),
                  MultiSelectDropdown(
                    options: AppConstants.quadrants,
                    initialSelected: _selectedQuadrants,
                    label: 'Quadrant',
                    onChanged: (vals) => setState(() => _selectedQuadrants = vals),
                  ),
                ],
              ),
            ),
          ),
        ],
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('2. Oral Examination'),
                _dataTable<OralExamFinding>(
                  columns: const ['Tooth', 'Finding', ''],
                  rows: _oralFindings.map((f) => [f.toothNumber, f.finding, '']).toList(),
                  trailingBuilder: (index) => IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: () => setState(() => _oralFindings.removeAt(index)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                      controller: _inlineToothController,
                      decoration: const InputDecoration(labelText: 'Tooth (FDI)'),
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                      controller: _inlineFindingController,
                      decoration: const InputDecoration(labelText: 'Finding'),
                    )),
                    const SizedBox(width: 8),
                    ElevatedButton(
                        onPressed: _addInlineOralFinding,
                        child: const Text('Add'))
                  ],
                )
              ],
            ),
          ),
        ),
        // 3. Investigation selection + conditional findings & media
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('3. Investigations'),
        MultiSelectDropdown(
          options: InvestigationType.values.map((e) => e.label).toList(),
          initialSelected: _investigations.map((e) => e.label).toList(),
          label: 'Select Investigations',
          onChanged: (vals) => setState(() {
            _investigations
              ..clear()
              ..addAll(vals.map((l) => InvestigationType.values.firstWhere((it) => it.label == l)));
          }),
        ),
        if (_investigations.isNotEmpty) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Tooth')),
                DataColumn(label: Text('Finding')),
                DataColumn(label: Text('Media')),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (var i = 0; i < _investigationFindings.length; i++)
                  DataRow(cells: [
                    DataCell(Text(_investigationFindings[i].toothNumber)),
                    DataCell(Text(_investigationFindings[i].finding)),
                    DataCell(IconButton(
                      icon: Icon(
                        _investigationFindings[i].imagePath == null ? Icons.attach_file : Icons.visibility,
                        color: _investigationFindings[i].imagePath == null ? null : Colors.teal,
                      ),
                      tooltip: _investigationFindings[i].imagePath == null ? 'No media' : 'View Attachment',
                      onPressed: _investigationFindings[i].imagePath == null
                          ? null
                          : () {
                              // Placeholder: could implement opening the file with an external viewer
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('File: ${_investigationFindings[i].imagePath}')));
                            },
                    )),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: () => setState(() => _investigationFindings.removeAt(i))),
                      ],
                    )),
                  ])
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                    onPressed: () => _addInvestigationFinding(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Finding')),
              ],
            ),
          ),
        ],
            ]),
          ),
        ),
        // 4. Treatment Plan per tooth
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('4. Treatment Plan'),
              _multiSelectToothPlan(),
            ]),
          ),
        ),
        // 5. Treatment Done
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('5. Treatment Done'),
              _multiSelectTreatmentDone(),
            ]),
          ),
        ),
        // 6. Prescription
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('6. Prescription'),
        _prescriptionBuilder(),
        ..._prescription.map((p) => ListTile(
              dense: true,
              title: Text('#Rx-${p.serial.toString().padLeft(3, '0')}  ${p.medicine}  ${p.timing}'),
              subtitle: Text('${p.tablets} tabs/ml x ${p.days} days'),
              trailing: IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () => setState(() => _prescription.remove(p))),
            )),
            ]),
          ),
        ),
        // 7. Next Appointment
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('7. Next Appointment Date'),
              Row(
          children: [
            Expanded(child: Text(_nextAppointment == null ? 'Not set' : _nextAppointment!.toLocal().toString().split(' ').first)),
            TextButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                      context: context,
                      initialDate: _nextAppointment ?? now,
                      firstDate: now.subtract(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 365)));
                  if (picked != null) setState(() => _nextAppointment = picked);
                },
                child: const Text('Select'))
          ],
        ),
            ]),
          ),
        ),
        // 8. Notes
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('8. Notes'),
              TextField(
          controller: _notes,
          decoration: const InputDecoration(labelText: 'Notes'),
          maxLines: 3,
        ),
            ]),
          ),
        ),
        // 9. Attachments
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('9. Attachments (Media)'),
              Wrap(
          spacing: 8,
          children: [
            ElevatedButton.icon(
                onPressed: _pickAttachment,
                icon: const Icon(Icons.attach_file),
                label: const Text('Add File')),
            if (_mediaPaths.isEmpty) const Text('No attachments yet'),
          ],
        ),
        ..._mediaPaths.map((p) => ListTile(
              dense: true,
              leading: const Icon(Icons.insert_drive_file, size: 18),
              title: Text(p.split('/').last),
              subtitle: Text(p),
              trailing: IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () => setState(() => _mediaPaths.remove(p))),
            )),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _orthoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _orthoFindings,
          decoration: const InputDecoration(labelText: 'Oral Findings'),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<BracketType>(
          value: _bracketType,
          items: BracketType.values.map((b) => DropdownMenuItem(value: b, child: Text(b.label))).toList(),
          onChanged: (v) => setState(() => _bracketType = v ?? BracketType.metalRegular),
          decoration: const InputDecoration(labelText: 'Bracket Type'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _orthoTotal,
          decoration: const InputDecoration(labelText: 'Total Treatment Amount (Excluding Appliance)'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _orthoDoctor,
          decoration: const InputDecoration(labelText: 'Doctor in Charge'),
        ),
        const Divider(height: 24),
        Text('Procedure Steps', style: Theme.of(context).textTheme.titleMedium),
        ElevatedButton(
            onPressed: () => _addProcedureStep(isOrtho: true),
            child: const Text('Add Step')),
        ..._orthoSteps.map((s) => ListTile(
              dense: true,
              title: Text('${s.description}'),
              subtitle: Text('${s.date.toLocal().toString().split(' ').first}${s.payment != null ? '  Paid: ${s.payment}' : ''}'),
              trailing: IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () => setState(() => _orthoSteps.remove(s))),
            )),
        if (_orthoTotal.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_orthoBalanceSummary(), style: Theme.of(context).textTheme.bodyMedium),
          )
      ],
    );
  }

  Widget _rootCanalForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
            onPressed: () async {
              final toothController = TextEditingController();
              final findingController = TextEditingController();
              await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                        title: const Text('Add Root Canal Finding'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(controller: toothController, decoration: const InputDecoration(labelText: 'Tooth (FDI)')),
                            TextField(controller: findingController, decoration: const InputDecoration(labelText: 'Finding')),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          ElevatedButton(
                              onPressed: () {
                                if (toothController.text.isNotEmpty && findingController.text.isNotEmpty) {
                                  setState(() {
                                    _rcFindings.add(OralExamFinding(toothNumber: toothController.text, finding: findingController.text));
                                  });
                                }
                                Navigator.pop(context);
                              },
                              child: const Text('Add'))
                        ],
                      ));
            },
            child: const Text('Add Finding')),
        ..._rcFindings.map((f) => ListTile(title: Text('${f.toothNumber}: ${f.finding}'))),
        const SizedBox(height: 12),
        TextField(
          controller: _rcTotal,
          decoration: const InputDecoration(labelText: 'Total Amount Payable'),
          keyboardType: TextInputType.number,
        ),
        const Divider(height: 24),
        Text('Procedure Steps', style: Theme.of(context).textTheme.titleMedium),
        ElevatedButton(onPressed: () => _addProcedureStep(isOrtho: false), child: const Text('Add Step')),
        ..._rcSteps.map((s) => ListTile(
              dense: true,
              title: Text(s.description),
              subtitle: Text('${s.date.toLocal().toString().split(' ').first}${s.payment != null ? '  Paid: ${s.payment}' : ''}'),
              trailing: IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () => setState(() => _rcSteps.remove(s))),
            )),
        if (_rcTotal.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_rootCanalBalanceSummary(), style: Theme.of(context).textTheme.bodyMedium),
          )
      ],
    );
  }

  TreatmentSession _createSession() {
    final uuid = const Uuid();
    switch (_selectedType) {
      case TreatmentType.general:
        return TreatmentSession(
          id: uuid.v4(),
          type: TreatmentType.general,
          date: DateTime.now(),
          parentSessionId: _followUpParentId,
          chiefComplaint: ChiefComplaintEntry(complaints: _selectedComplaints, quadrants: _selectedQuadrants),
          oralExamFindings: _oralFindings,
          investigations: _investigations,
          investigationFindings: _investigationFindings,
          generalTreatmentPlan: _treatmentPlan, // legacy
          toothPlans: _toothPlans,
          treatmentsDone: _treatmentsDone,
          notes: _notes.text.trim(),
          prescription: _prescription,
          mediaPaths: _mediaPaths,
          nextAppointment: _nextAppointment,
        );
      case TreatmentType.orthodontic:
        return TreatmentSession(
          id: uuid.v4(),
          type: TreatmentType.orthodontic,
          date: DateTime.now(),
          parentSessionId: _followUpParentId,
          orthoOralFindings: _orthoFindings.text.trim(),
          bracketType: _bracketType,
          orthoTotalAmount: double.tryParse(_orthoTotal.text.trim()),
          orthoDoctorInCharge: _orthoDoctor.text.trim(),
          orthoSteps: _orthoSteps,
        );
      case TreatmentType.rootCanal:
        return TreatmentSession(
          id: uuid.v4(),
          type: TreatmentType.rootCanal,
          date: DateTime.now(),
          parentSessionId: _followUpParentId,
          rootCanalFindings: _rcFindings,
          rootCanalTotalAmount: double.tryParse(_rcTotal.text.trim()),
          rootCanalSteps: _rcSteps,
        );
      case TreatmentType.labWork:
        return TreatmentSession(
          id: uuid.v4(),
          type: TreatmentType.labWork,
          date: DateTime.now(),
          parentSessionId: _followUpParentId,
        );
    }
  }

  Widget _prescriptionBuilder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                value: _rxSelectedMedicine,
                items: AppConstants.prescriptionMedicines.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _rxSelectedMedicine = v),
                decoration: const InputDecoration(labelText: 'Medicine'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _rxTiming,
                decoration: const InputDecoration(labelText: 'Timing (e.g. 1-0-1)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _rxTablets,
                decoration: const InputDecoration(labelText: 'Qty (Tabs/ml)'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _rxDays,
                decoration: const InputDecoration(labelText: 'Days'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
                onPressed: _addPrescriptionItem,
                child: const Text('Add'))
          ],
        )
      ],
    );
  }

  // Helpers & dialogs
  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _dataTable<T>({required List<String> columns, required List<List<String>> rows, Widget Function(int index)? trailingBuilder}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          ...columns.map((c) => DataColumn(label: Text(c))),
        ],
        rows: [
          for (var i = 0; i < rows.length; i++)
            DataRow(cells: [
              for (var j = 0; j < rows[i].length - 1; j++) DataCell(Text(rows[i][j])),
              DataCell(trailingBuilder == null ? const SizedBox() : trailingBuilder(i)),
            ])
        ],
      ),
    );
  }

  Widget _multiSelectToothPlan() {
    // Represent existing plans as display, add/edit via dialog using multi-entry one at a time
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_toothPlans.isEmpty) const Text('No plans added'),
        ..._toothPlans.asMap().entries.map((e) => ListTile(
              dense: true,
              title: Text('Tooth ${e.value.toothNumber}'),
              subtitle: Text(e.value.plan),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editPlan(e.key)),
                  IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () => setState(() => _toothPlans.removeAt(e.key))),
                ],
              ),
            )),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: _addToothPlan, icon: const Icon(Icons.add), label: const Text('Add Plan')),
        )
      ],
    );
  }

  Widget _multiSelectTreatmentDone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_treatmentsDone.isEmpty) const Text('No treatment done entries'),
        ..._treatmentsDone.asMap().entries.map((e) => ListTile(
              dense: true,
              title: Text('Tooth ${e.value.toothNumber}'),
              subtitle: Text(e.value.treatment),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editTreatmentDone(e.key)),
                  IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () => setState(() => _treatmentsDone.removeAt(e.key))),
                ],
              ),
            )),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: _addTreatmentDone, icon: const Icon(Icons.add), label: const Text('Add Treatment Done')),
        )
      ],
    );
  }

  void _addInlineOralFinding() {
    final tooth = _inlineToothController.text.trim();
    final finding = _inlineFindingController.text.trim();
    if (tooth.isEmpty || finding.isEmpty) return;
    setState(() {
      _oralFindings.add(OralExamFinding(toothNumber: tooth, finding: finding));
      _inlineToothController.clear();
      _inlineFindingController.clear();
    });
  }

  Future<void> _addInvestigationFinding() async {
    final tooth = TextEditingController();
    final finding = TextEditingController();
    String? pickedPath;
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
              return AlertDialog(
                title: const Text('Add Investigation Finding'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: tooth, decoration: const InputDecoration(labelText: 'Tooth (FDI)')),
                    TextField(controller: finding, decoration: const InputDecoration(labelText: 'Finding')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text(pickedPath == null ? 'No media selected' : pickedPath!.split('/').last)),
                        IconButton(
                            onPressed: () async {
                              final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
                              if (res != null && res.files.isNotEmpty) {
                                setSt(() => pickedPath = res.files.single.path);
                              }
                            },
                            icon: const Icon(Icons.attach_file))
                      ],
                    )
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
                ],
              );
            }));
    if (ok == true && tooth.text.trim().isNotEmpty && finding.text.trim().isNotEmpty) {
      setState(() => _investigationFindings.add(InvestigationFinding(toothNumber: tooth.text.trim(), finding: finding.text.trim(), imagePath: pickedPath)));
    }
  }

  Future<void> _addToothPlan() async {
    final tooth = TextEditingController();
    final plan = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Add Treatment Plan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: tooth, decoration: const InputDecoration(labelText: 'Tooth (FDI)')),
                  TextField(controller: plan, decoration: const InputDecoration(labelText: 'Plan')),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
              ],
            ));
    if (ok == true && tooth.text.isNotEmpty && plan.text.isNotEmpty) {
      setState(() => _toothPlans.add(ToothPlanEntry(toothNumber: tooth.text.trim(), plan: plan.text.trim())));
    }
  }

  Future<void> _editPlan(int index) async {
    final existing = _toothPlans[index];
    final tooth = TextEditingController(text: existing.toothNumber);
    final plan = TextEditingController(text: existing.plan);
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Edit Treatment Plan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: tooth, decoration: const InputDecoration(labelText: 'Tooth (FDI)')),
                  TextField(controller: plan, decoration: const InputDecoration(labelText: 'Plan')),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
              ],
            ));
    if (ok == true && tooth.text.isNotEmpty && plan.text.isNotEmpty) {
      setState(() => _toothPlans[index] = ToothPlanEntry(toothNumber: tooth.text.trim(), plan: plan.text.trim()));
    }
  }

  Future<void> _addTreatmentDone() async {
    final tooth = TextEditingController();
    final treat = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Add Treatment Done'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: tooth, decoration: const InputDecoration(labelText: 'Tooth (FDI)')),
                  TextField(controller: treat, decoration: const InputDecoration(labelText: 'Treatment')),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
              ],
            ));
    if (ok == true && tooth.text.isNotEmpty && treat.text.isNotEmpty) {
      setState(() => _treatmentsDone.add(ToothTreatmentDoneEntry(toothNumber: tooth.text.trim(), treatment: treat.text.trim())));
    }
  }

  Future<void> _editTreatmentDone(int index) async {
    final existing = _treatmentsDone[index];
    final tooth = TextEditingController(text: existing.toothNumber);
    final treat = TextEditingController(text: existing.treatment);
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Edit Treatment Done'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: tooth, decoration: const InputDecoration(labelText: 'Tooth (FDI)')),
                  TextField(controller: treat, decoration: const InputDecoration(labelText: 'Treatment')),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
              ],
            ));
    if (ok == true && tooth.text.isNotEmpty && treat.text.isNotEmpty) {
      setState(() => _treatmentsDone[index] = ToothTreatmentDoneEntry(toothNumber: tooth.text.trim(), treatment: treat.text.trim()));
    }
  }

  Future<void> _pickAttachment() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res != null) {
      setState(() {
        for (final f in res.files) {
          if (f.path != null) _mediaPaths.add(f.path!);
        }
      });
    }
  }

  void _addPrescriptionItem() {
    if (_rxSelectedMedicine == null || _rxTiming.text.trim().isEmpty) return;
    final serial = _prescription.length + 1;
    setState(() {
      _prescription.add(PrescriptionItem(
          serial: serial,
          medicine: _rxSelectedMedicine!,
          timing: _rxTiming.text.trim(),
          tablets: int.tryParse(_rxTablets.text.trim()) ?? 0,
          days: int.tryParse(_rxDays.text.trim()) ?? 0));
      _rxTiming.clear();
      _rxTablets.clear();
      _rxDays.clear();
    });
  }

  void _addProcedureStep({required bool isOrtho}) async {
    final desc = TextEditingController();
    final pay = TextEditingController();
    final note = TextEditingController();
    final uuid = const Uuid();
    final result = await showDialog<ProcedureStep>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Add Procedure Step'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
                  TextField(controller: pay, decoration: const InputDecoration(labelText: 'Payment (optional)'), keyboardType: TextInputType.number),
                  TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () {
                      if (desc.text.trim().isEmpty) return;
                      Navigator.pop(
                          context,
                          ProcedureStep(
                              id: uuid.v4(),
                              date: DateTime.now(),
                              description: desc.text.trim(),
                              payment: double.tryParse(pay.text.trim()),
                              note: note.text.trim().isEmpty ? null : note.text.trim()));
                    },
                    child: const Text('Add'))
              ],
            ));
    if (result != null) {
      setState(() {
        if (isOrtho) {
          _orthoSteps.add(result);
        } else {
          _rcSteps.add(result);
        }
      });
    }
  }

  String _orthoBalanceSummary() {
    final total = double.tryParse(_orthoTotal.text.trim()) ?? 0;
    final paid = _orthoSteps.fold<double>(0, (p, e) => p + (e.payment ?? 0));
    final bal = total - paid;
    return 'Paid: $paid / Total: $total  Balance: $bal';
  }

  String _rootCanalBalanceSummary() {
    final total = double.tryParse(_rcTotal.text.trim()) ?? 0;
    final paid = _rcSteps.fold<double>(0, (p, e) => p + (e.payment ?? 0));
    final bal = total - paid;
    return 'Paid: $paid / Total: $total  Balance: $bal';
  }

  void _openLabWork(String patientId) {
    Navigator.of(context).pushNamed('/patient-lab-work', arguments: {'patientId': patientId});
  }
}
