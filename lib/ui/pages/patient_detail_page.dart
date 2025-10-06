import 'package:flutter/material.dart'; // keep Flutter material
import 'dart:ui';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/patient_provider.dart';
import '../../providers/options_provider.dart';
import '../../core/enums.dart';
import '../../core/constants.dart';
import '../../models/treatment_session.dart';
import '../../models/patient.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../widgets/multi_select_dropdown.dart';
import '../widgets/search_editable_multi_select.dart';
// import '../widgets/search_multi_select.dart'; // no longer needed here after moving to full-screen edit page
import 'edit_patient_page.dart';

class PatientDetailPage extends StatefulWidget {
  static const routeName = '/patient-detail';
  final String? patientId;
  const PatientDetailPage({super.key, required this.patientId});

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> with TickerProviderStateMixin {
  TreatmentType _selectedType = TreatmentType.general;
  String? _followUpParentId; // follow up parent id
  String? _editingSessionId; // when set, we update existing session instead of creating new
  bool _showRxForm = false; // hides main session entry form until Add Rx pressed

  // General form state
  List<String> _selectedComplaints = [];
  List<String> _selectedQuadrants = [];
  final List<OralExamFinding> _oralFindings = [];
  // Temp selections for new oral findings (multi-select style like complaints)
  List<String> _selectedOralFindingOptions = [];
  final List<InvestigationType> _investigations = [];
  final List<InvestigationFinding> _investigationFindings = [];
  final List<String> _treatmentPlan = []; // legacy
  final List<ToothPlanEntry> _toothPlans = [];
  final List<ToothTreatmentDoneEntry> _treatmentsDone = [];
  // Inline FDI tooth number inputs for plan / done additions
  final TextEditingController _planToothController = TextEditingController();
  final TextEditingController _doneToothController = TextEditingController();
  // New multi-select buffers for plan and treatment done (legacy structured lists retained)
  List<String> _selectedPlanOptions = [];
  List<String> _selectedTreatmentDoneOptions = [];
  final List<String> _mediaPaths = [];
  final List<String> _rvgImages = [];
  DateTime? _nextAppointment;
  final TextEditingController _notes = TextEditingController();

  // Prescription
  final List<PrescriptionItem> _prescription = [];
  String? _rxSelectedMedicine;
  final TextEditingController _rxTiming = TextEditingController();
  final TextEditingController _rxTablets = TextEditingController();
  final TextEditingController _rxDays = TextEditingController();

  // Inline oral
  final TextEditingController _inlineToothController = TextEditingController();
  final TextEditingController _inlineFindingController = TextEditingController();

  // Inline investigation add
  final TextEditingController _invToothController = TextEditingController();
  final TextEditingController _invFindingController = TextEditingController();
  String? _invPickedPath;

  // (Inline edit dialog uses local controllers)

  // Ortho
  final TextEditingController _orthoFindings = TextEditingController();
  BracketType _bracketType = BracketType.metalRegular;
  final TextEditingController _orthoTotal = TextEditingController();
  final TextEditingController _orthoDoctor = TextEditingController();
  final List<ProcedureStep> _orthoSteps = [];

  // Root canal
  final List<OralExamFinding> _rcFindings = [];
  final TextEditingController _rcTotal = TextEditingController();
  final List<ProcedureStep> _rcSteps = [];
  // Session history filtering by registered date (unique existing session dates)
  String? _sessionFilterDateStr; // YYYY-MM-DD string currently selected

  @override
  Widget build(BuildContext context) {
    // Ensure dynamic options are loaded
  _ensureOptionsLoaded(context);
    final patient = widget.patientId == null ? null : context.watch<PatientProvider>().byId(widget.patientId!);
    if (patient == null) return const Scaffold(body: Center(child: Text('Patient not found')));
    return Scaffold(
      appBar: AppBar(title: Text(patient.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _basicInfoCard(patient),
            const SizedBox(height: 12),
            // Previous sessions container moved near top
            _sessionHistoryContainer(patient),
            const SizedBox(height: 16),
            // Removed duplicate Add Rx + outer type row (type now moved inside form header)
            // Global follow-up button removed (now per-session inside history list)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _showRxForm
                  ? Column(
                      children: [
                        // Inline header showing Type selector at top of form
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Type:', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(width: 12),
                                _typeSelector(),
                              ],
                            ),
                          ),
                        ),
                        _buildTypeForm(),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (_editingSessionId == null) {
                                    final session = _createSession();
                                    await context.read<PatientProvider>().addSession(patient.id, session);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session saved.')));
                                  } else {
                                    final updated = _createSession().copyWith(id: _editingSessionId);
                                    await context.read<PatientProvider>().updateSession(patient.id, updated);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session updated.')));
                                  }
                                  setState(() {
                                    _editingSessionId = null;
                                    _showRxForm = false;
                                    _resetFormState();
                                  });
                                },
                                icon: Icon(_editingSessionId == null ? Icons.save : Icons.save_as),
                                label: Text(_editingSessionId == null ? 'Save Session' : 'Update Session'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (_editingSessionId != null)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.close),
                                label: const Text('Cancel Edit'),
                                onPressed: () {
                                  setState(() {
                                    _editingSessionId = null;
                                    _showRxForm = false;
                                    _resetFormState();
                                  });
                                },
                              )
                          ],
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            // END session entry form
          ],
        ),
      ),
    );
  }

  // Ensure all option lists (including new oral findings) are loaded exactly once
  bool _optionsLoaded = false;
  void _ensureOptionsLoaded(BuildContext context) {
    if (_optionsLoaded) return;
    final opt = context.read<OptionsProvider>();
    opt.ensureLoaded(
      defaultComplaints: AppConstants.chiefComplaints,
      defaultOralFindings: AppConstants.oralFindings,
      defaultPlan: AppConstants.generalTreatmentPlanOptions,
      defaultTreatmentDone: AppConstants.generalTreatmentDoneOptions,
      defaultMedicines: AppConstants.prescriptionMedicines,
      defaultPastDental: AppConstants.pastDentalHistoryOptions,
      defaultPastMedical: AppConstants.pastMedicalHistoryOptions,
      defaultMedicationOptions: AppConstants.medicationOptions,
      defaultDrugAllergies: AppConstants.drugAllergyOptions,
    );
    _optionsLoaded = true;
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
            if (patient.pastDentalHistory.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Past Dental: ${patient.pastDentalHistory.join(', ')}'),
              ),
            if (patient.pastMedicalHistory.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Past Medical: ${patient.pastMedicalHistory.join(', ')}'),
              ),
            if (patient.currentMedications.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Medications: ${patient.currentMedications.join(', ')}'),
              ),
            if (patient.drugAllergies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Allergies: ${patient.drugAllergies.join(', ')}', style: const TextStyle(color: Colors.redAccent)),
              ),
            if (patient.pastDentalHistory.isNotEmpty || patient.pastMedicalHistory.isNotEmpty || patient.currentMedications.isNotEmpty || patient.drugAllergies.isNotEmpty)
              const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              ElevatedButton.icon(
                onPressed: () => _openLabWork(patient.id),
                icon: const Icon(Icons.biotech, size: 18),
                label: const Text('Lab Work'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed(EditPatientPage.routeName, arguments: {'patientId': patient.id}),
                icon: const Icon(Icons.manage_accounts, size: 18),
                label: const Text('Edit Patient'),
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

  // (Edit patient dialog removed in favor of full-screen page)

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
                  Builder(
                    builder: (ctx) {
                      final opt = ctx.watch<OptionsProvider>();
                      return SearchEditableMultiSelect(
                        label: 'Complaint Type',
                        options: opt.complaints,
                        initial: _selectedComplaints,
                        onChanged: (vals) => setState(() => _selectedComplaints = vals),
                        onAdd: (v) => opt.addValue('complaints', v),
                        onDelete: (v) async {
                          final ok = await opt.removeValue('complaints', v);
                          if (!ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete: option in use.')));
                          }
                        },
                      );
                    },
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
                Builder(builder: (ctx){
                  final opt = ctx.watch<OptionsProvider>();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SearchEditableMultiSelect(
                        label: 'Select / Add Findings',
                        options: opt.oralFindingsOptions,
                        initial: _selectedOralFindingOptions,
                        onChanged: (vals)=> setState(()=> _selectedOralFindingOptions = vals),
                        onAdd: (v)=> opt.addValue('oralFindings', v),
                        onDelete: (v) async {
                          final ok = await opt.removeValue('oralFindings', v);
                          if (!ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete: finding in use.')));
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inlineToothController,
                              decoration: const InputDecoration(labelText: 'Tooth (optional, FDI)'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            onPressed: _addInlineOralFinding,
                            label: const Text('Add'),
                          )
                        ],
                      ),
                      if (_selectedOralFindingOptions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top:6),
                          child: Text('Press Add to append selected findings${' with ' + (_inlineToothController.text.isEmpty ? 'no tooth' : 'tooth ' + _inlineToothController.text)}'),
                        )
                    ],
                  );
                })
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
                  // If investigations changed and no longer relevant, keep existing findings (could filter if needed later)
                }),
              ),
              if (_investigations.isNotEmpty) ...[
                const SizedBox(height: 12),
                if (_investigationFindings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('No investigation findings yet. Add below:', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 38,
                    dataRowMinHeight: 40,
                    columns: const [
                      DataColumn(label: Text('Tooth', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Finding', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Media', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.w600))),
                    ],
                    rows: [
                      for (var i = 0; i < _investigationFindings.length; i++)
                        DataRow(cells: [
                          DataCell(Text(_investigationFindings[i].toothNumber)),
                          DataCell(Text(_investigationFindings[i].finding)),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _investigationFindings[i].imagePath == null ? Icons.attach_file : Icons.visibility,
                                  color: _investigationFindings[i].imagePath == null ? null : Colors.teal,
                                ),
                                tooltip: _investigationFindings[i].imagePath == null ? 'Attach Media' : 'View Attachment',
                                onPressed: () async {
                                  if (_investigationFindings[i].imagePath == null) {
                                    await _attachMediaToInvestigation(i);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('File: ${_investigationFindings[i].imagePath}')));
                                  }
                                },
                              ),
                            ],
                          )),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                tooltip: 'Edit',
                                onPressed: () => _editInvestigationFinding(i),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                onPressed: () => setState(() => _investigationFindings.removeAt(i)),
                              ),
                            ],
                          )),
                        ]),
                      // Inline add row
                      DataRow(cells: [
                        DataCell(SizedBox(
                          width: 70,
                          child: TextField(
                            controller: _invToothController,
                            decoration: const InputDecoration(isDense: true, hintText: 'Tooth'),
                          ),
                        )),
                        DataCell(SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _invFindingController,
                            decoration: const InputDecoration(isDense: true, hintText: 'Finding'),
                          ),
                        )),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: _invPickedPath == null ? 'Attach Media' : 'Change Media',
                              icon: Icon(_invPickedPath == null ? Icons.attach_file : Icons.image, color: _invPickedPath == null ? null : Colors.teal),
                              onPressed: _pickInvestigationMedia,
                            ),
                            if (_invPickedPath != null)
                              IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(() => _invPickedPath = null),
                              )
                          ],
                        )),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              tooltip: 'Add',
                              onPressed: _addInvestigationFindingInline,
                            ),
                          ],
                        )),
                      ])
                    ],
                  ),
                ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Finding'),
                        onPressed: _addInvestigationFindingInline,
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload RVG Image'),
                        onPressed: () async {
                          final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
                          if (res != null) {
                            setState(() {
                              for (final f in res.files) {
                                if (f.path != null) _rvgImages.add(f.path!);
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (_rvgImages.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: _rvgImages
                          .map((p) => Chip(
                                label: Text(p.split('/').last),
                                onDeleted: () => setState(() => _rvgImages.remove(p)),
                              ))
                          .toList(),
                    ),
                  ],
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
    const uuid = Uuid();
    // Before creating session, flush any pending oral finding selections not yet added
    if (_selectedOralFindingOptions.isNotEmpty) {
      final tooth = _inlineToothController.text.trim();
      for (final f in _selectedOralFindingOptions) {
        _oralFindings.add(OralExamFinding(toothNumber: tooth, finding: f));
      }
      _sortByTooth(_oralFindings, (f) => f.toothNumber);
      _selectedOralFindingOptions.clear();
      _inlineToothController.clear();
      _inlineFindingController.clear();
    }
    switch (_selectedType) {
      case TreatmentType.general:
        return TreatmentSession(
          id: uuid.v4(),
          type: TreatmentType.general,
          date: DateTime.now(),
          parentSessionId: _followUpParentId,
          // Deep copies to preserve snapshot (avoid later clears mutating saved session)
          chiefComplaint: ChiefComplaintEntry(
            complaints: List.from(_selectedComplaints),
            quadrants: List.from(_selectedQuadrants),
          ),
          oralExamFindings: List.from(_oralFindings),
          investigations: List.from(_investigations),
          investigationFindings: List.from(_investigationFindings),
          generalTreatmentPlan: List.from(_treatmentPlan), // legacy
          toothPlans: List.from(_toothPlans),
          treatmentsDone: List.from(_treatmentsDone),
          planOptions: List.from(_selectedPlanOptions),
          treatmentDoneOptions: List.from(_selectedTreatmentDoneOptions),
          notes: _notes.text.trim(),
          prescription: List.from(_prescription),
          mediaPaths: List.from(_mediaPaths),
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
          orthoSteps: List.from(_orthoSteps),
        );
      case TreatmentType.rootCanal:
        return TreatmentSession(
          id: uuid.v4(),
          type: TreatmentType.rootCanal,
          date: DateTime.now(),
          parentSessionId: _followUpParentId,
          rootCanalFindings: List.from(_rcFindings),
          rootCanalTotalAmount: double.tryParse(_rcTotal.text.trim()),
          rootCanalSteps: List.from(_rcSteps),
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
              child: Builder(builder: (ctx){
                final opt = ctx.watch<OptionsProvider>();
                return InkWell(
                  onTap: () async {
                    final selected = await _openMedicinePicker(opt);
                    if (selected != null) setState(()=> _rxSelectedMedicine = selected);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Medicine'),
                    child: Text(_rxSelectedMedicine ?? 'Select', style: TextStyle(color: _rxSelectedMedicine==null? Colors.grey : null)),
                  ),
                );
              }),
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

  Future<String?> _openMedicinePicker(OptionsProvider opt) async {
    final controller = TextEditingController();
    String query = '';
    String? localSelected = _rxSelectedMedicine;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSB) {
        final filtered = opt.medicineOptions.where((m) => m.toLowerCase().contains(query.toLowerCase())).toList();
        return AlertDialog(
          title: const Text('Select Medicine'),
          content: SizedBox(
            width: 400,
            height: 480,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search'),
                  onChanged: (v) => setSB(() => query = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(hintText: 'Add new medicine'),
                        onSubmitted: (_) async {
                          final val = controller.text.trim();
                          if (val.isNotEmpty) {
                            await opt.addValue('medicines', val);
                            controller.clear();
                            setSB(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final val = controller.text.trim();
                        if (val.isNotEmpty) {
                          await opt.addValue('medicines', val);
                          controller.clear();
                          setSB(() {});
                        }
                      },
                      child: const Text('Add'),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (c, i) {
                      final med = filtered[i];
                      return ListTile(
                        leading: Radio<String>(
                          value: med,
                          groupValue: localSelected,
                          onChanged: (v)=> setSB(()=> localSelected = v),
                        ),
                        title: Text(med),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final ok = await opt.removeValue('medicines', med);
                            if (!ok) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete: medicine in use.')));
                              }
                            } else {
                              if (localSelected == med) localSelected = null;
                              setSB(() {});
                            }
                          },
                        ),
                        onTap: () => setSB(()=> localSelected = med),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, localSelected), child: const Text('Select')),
          ],
        );
      }),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(builder: (ctx){
          final opt = ctx.watch<OptionsProvider>();
          return SearchEditableMultiSelect(
            label: 'Select Plan Options',
            options: opt.planOptions,
            initial: _selectedPlanOptions,
            onChanged: (vals)=> setState(()=> _selectedPlanOptions = vals),
            onAdd: (v)=> opt.addValue('plan', v),
            onDelete: (v) async {
              final ok = await opt.removeValue('plan', v);
              if (!ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete: option in use.')));
              }
            },
          );
        }),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: TextField(
                controller: _planToothController,
                decoration: const InputDecoration(
                  labelText: 'Tooth (FDI)',
                  hintText: 'e.g. 11',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add w/ Tooth'),
              onPressed: () {
                final tooth = _planToothController.text.trim();
                if (tooth.isEmpty || !_isValidFdi(tooth)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid FDI tooth number')));
                  return;
                }
                if (_selectedPlanOptions.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select plan option(s) first')));
                  return;
                }
                final optionsToAdd = List<String>.from(_selectedPlanOptions);
                setState(() {
                  for (final p in optionsToAdd) {
                    _toothPlans.add(ToothPlanEntry(toothNumber: tooth, plan: p));
                  }
                  _selectedPlanOptions.clear(); // prevent duplicate unassociated chips
                  _planToothController.clear();
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedPlanOptions.isEmpty) const Text('No plan options selected'),
        if (_selectedPlanOptions.isNotEmpty)
          Wrap(
            spacing: 6,
            children: _selectedPlanOptions.map((p) => Chip(label: Text(p))).toList(),
          ),
        if (_toothPlans.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Per-Tooth Plan Entries (${_toothPlans.length})', style: Theme.of(context).textTheme.bodyMedium),
          Wrap(
            spacing: 6,
            children: [
              for (int i=0;i<_toothPlans.length;i++)
                Chip(
                  label: Text('${_toothPlans[i].toothNumber}: ${_toothPlans[i].plan}'),
                  onDeleted: () => setState(()=> _toothPlans.removeAt(i)),
                )
            ],
          )
        ]
      ],
    );
  }

  Widget _multiSelectTreatmentDone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(builder: (ctx){
          final opt = ctx.watch<OptionsProvider>();
          return SearchEditableMultiSelect(
            label: 'Select Treatments Done',
            options: opt.treatmentDoneOptions,
            initial: _selectedTreatmentDoneOptions,
            onChanged: (vals)=> setState(()=> _selectedTreatmentDoneOptions = vals),
            onAdd: (v)=> opt.addValue('done', v),
            onDelete: (v) async {
              final ok = await opt.removeValue('done', v);
              if (!ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete: option in use.')));
              }
            },
          );
        }),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: TextField(
                controller: _doneToothController,
                decoration: const InputDecoration(
                  labelText: 'Tooth (FDI)',
                  hintText: 'e.g. 46',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_task),
              label: const Text('Add w/ Tooth'),
              onPressed: () {
                final tooth = _doneToothController.text.trim();
                if (tooth.isEmpty || !_isValidFdi(tooth)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid FDI tooth number')));
                  return;
                }
                if (_selectedTreatmentDoneOptions.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select treatment(s) done first')));
                  return;
                }
                final doneToAdd = List<String>.from(_selectedTreatmentDoneOptions);
                setState(() {
                  for (final d in doneToAdd) {
                    _treatmentsDone.add(ToothTreatmentDoneEntry(toothNumber: tooth, treatment: d));
                  }
                  _selectedTreatmentDoneOptions.clear();
                  _doneToothController.clear();
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedTreatmentDoneOptions.isEmpty) const Text('No treatments selected'),
        if (_selectedTreatmentDoneOptions.isNotEmpty)
          Wrap(
            spacing: 6,
            children: _selectedTreatmentDoneOptions.map((p) => Chip(label: Text(p))).toList(),
          ),
        if (_treatmentsDone.isNotEmpty) ...[
          const SizedBox(height: 8),
            Text('Per-Tooth Treatments (${_treatmentsDone.length})', style: Theme.of(context).textTheme.bodyMedium),
            Wrap(
              spacing: 6,
              children: [
                for (int i=0;i<_treatmentsDone.length;i++)
                  Chip(
                    label: Text('${_treatmentsDone[i].toothNumber}: ${_treatmentsDone[i].treatment}'),
                    onDeleted: () => setState(()=> _treatmentsDone.removeAt(i)),
                  )
              ],
            )
        ]
      ],
    );
  }

  bool _isValidFdi(String value) {
    // Accept permanent (11-18,21-28,31-38,41-48) & primary (51-55,61-65,71-75,81-85)
    // Allow optional retained prefix R and optional 1-2 letter supernumerary suffix (e.g., 11A, R53B)
    final reg = RegExp(r'^(R)?(1[1-8]|2[1-8]|3[1-8]|4[1-8]|5[1-5]|6[1-5]|7[1-5]|8[1-5])([A-Z]{1,2})?$', caseSensitive: false);
    return reg.hasMatch(value.trim());
  }

  void _addInlineOralFinding() {
    if (_selectedOralFindingOptions.isEmpty) {
      // Fallback: if user typed manual finding text in old field (still present logically)
      final manual = _inlineFindingController.text.trim();
      if (manual.isEmpty) return;
      final tooth = _inlineToothController.text.trim();
      setState(() {
        _oralFindings.add(OralExamFinding(toothNumber: tooth, finding: manual));
        _sortByTooth(_oralFindings, (f) => f.toothNumber);
        _inlineFindingController.clear();
        _inlineToothController.clear();
      });
      return;
    }
    final tooth = _inlineToothController.text.trim();
    setState(() {
      for (final f in _selectedOralFindingOptions) {
        _oralFindings.add(OralExamFinding(toothNumber: tooth, finding: f));
      }
      _sortByTooth(_oralFindings, (f) => f.toothNumber);
      _selectedOralFindingOptions.clear();
      _inlineToothController.clear();
      _inlineFindingController.clear();
    });
  }

  Future<void> _attachMediaToInvestigation(int index) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (res != null && res.files.isNotEmpty) {
      setState(() {
        final existing = _investigationFindings[index];
        _investigationFindings[index] = InvestigationFinding(
          toothNumber: existing.toothNumber,
          finding: existing.finding,
          imagePath: res.files.single.path,
        );
      });
    }
  }

  Future<void> _pickInvestigationMedia() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (res != null && res.files.isNotEmpty) {
      setState(() => _invPickedPath = res.files.single.path);
    }
  }

  void _addInvestigationFindingInline() {
    final tooth = _invToothController.text.trim();
    final finding = _invFindingController.text.trim();
    if (tooth.isEmpty || finding.isEmpty) return;
    setState(() {
      _investigationFindings.add(InvestigationFinding(toothNumber: tooth, finding: finding, imagePath: _invPickedPath));
      _sortByTooth(_investigationFindings, (f) => f.toothNumber);
      _invToothController.clear();
      _invFindingController.clear();
      _invPickedPath = null;
    });
  }

  Future<void> _editInvestigationFinding(int index) async {
    final tooth = TextEditingController(text: _investigationFindings[index].toothNumber);
    final finding = TextEditingController(text: _investigationFindings[index].finding);
    String? mediaPath = _investigationFindings[index].imagePath;
    final result = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
              return AlertDialog(
                title: const Text('Edit Investigation Finding'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: tooth, decoration: const InputDecoration(labelText: 'Tooth (FDI)')),
                    TextField(controller: finding, decoration: const InputDecoration(labelText: 'Finding')),
                    Row(
                      children: [
                        IconButton(
                            tooltip: mediaPath == null ? 'Attach Media' : 'Change Media',
                            icon: Icon(mediaPath == null ? Icons.attach_file : Icons.image, color: mediaPath == null ? null : Colors.teal),
                            onPressed: () async {
                              final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
                              if (res != null && res.files.isNotEmpty) {
                                setSt(() => mediaPath = res.files.single.path);
                              }
                            }),
                        if (mediaPath != null)
                          IconButton(
                              tooltip: 'Remove Media',
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => setSt(() => mediaPath = null)),
                      ],
                    )
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
                ],
              );
            }));
    if (result == true && tooth.text.trim().isNotEmpty && finding.text.trim().isNotEmpty) {
      setState(() {
        _investigationFindings[index] = InvestigationFinding(
          toothNumber: tooth.text.trim(),
          finding: finding.text.trim(),
          imagePath: mediaPath,
        );
        _sortByTooth(_investigationFindings, (f) => f.toothNumber);
      });
    }
  }

  // Removed dialog helpers for plan & treatment done (replaced by multi-select)

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
    const uuid = Uuid();
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

  // Generic sorter converting tooth numbers (possibly strings like 11, 12) to int where possible.
  void _sortByTooth<T>(List<T> list, String Function(T) toothExtractor) {
    int parse(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    list.sort((a, b) => parse(toothExtractor(a)).compareTo(parse(toothExtractor(b))));
  }

  // =============== Modern Styling Helpers ===============
  Color _typeColor(TreatmentSession s) {
    switch (s.type) {
      case TreatmentType.general:
        return Theme.of(context).colorScheme.primary;
      case TreatmentType.orthodontic:
        return Colors.purpleAccent.shade400;
      case TreatmentType.rootCanal:
        return Colors.teal.shade600;
      case TreatmentType.labWork:
        return Colors.orange.shade700;
    }
  }

  List<Color> _typeGradientColors(TreatmentSession s, {bool followUp = false}) {
    final base = _typeColor(s);
    final lighter = Color.alphaBlend(base.withOpacity(0.25), Colors.white);
    if (followUp) {
      return [lighter, base.withOpacity(0.12)];
    }
    return [base.withOpacity(0.22), base.withOpacity(0.05)];
  }

  IconData _typeIcon(TreatmentSession s, {bool isFollowUp = false}) {
    if (isFollowUp) return Icons.subdirectory_arrow_right_rounded;
    switch (s.type) {
      case TreatmentType.general:
        return Icons.medical_services_outlined;
      case TreatmentType.orthodontic:
        return Icons.settings_input_component;
      case TreatmentType.rootCanal:
        return Icons.healing_outlined;
      case TreatmentType.labWork:
        return Icons.science_outlined;
    }
  }

  Widget _sessionHistory(patient) {
    final sessions = patient.sessions;
    if (sessions.isEmpty) return const SizedBox();
    // Build parent -> children map for follow-ups
    final Map<String, List<TreatmentSession>> followUps = {};
    final parents = <TreatmentSession>[];
    for (final s in sessions) {
      if (s.parentSessionId == null) {
        parents.add(s);
      } else {
        followUps.putIfAbsent(s.parentSessionId!, () => []).add(s);
      }
    }
    // Sort parents by date descending
    parents.sort((a,b)=> b.date.compareTo(a.date));
    Widget buildTile(TreatmentSession s, {bool isFollowUp=false, int? parentCount, List<TreatmentSession>? childFollowUpsFiltered}) {
      List<String> planOpts;
      List<String> doneOpts;
      try {
        final po = (s as dynamic).planOptions;
        planOpts = (po is List) ? po.cast<String>() : <String>[];
      } catch (_) { planOpts = <String>[]; }
      try {
        final td = (s as dynamic).treatmentDoneOptions;
        doneOpts = (td is List) ? td.cast<String>() : <String>[];
      } catch (_) { doneOpts = <String>[]; }
      final orderedDetails = _buildSessionDetailLines(s, planOpts, doneOpts);
  // titlePrefix removed (follow-up title constructed inline)
      // Determine if we should elevate chief complaint(s) into the title for general parent sessions
      bool movedComplaintToTitle = false;
      String datePart = s.date.toLocal().toString().split(' ').first;
  // displayTitle no longer needed (follow-up title now custom composed)
      String complaintsFullForTitle = '';
      if (!isFollowUp && s.type == TreatmentType.general && s.chiefComplaint != null) {
        final complaintsFull = s.chiefComplaint!.complaints.join(', ');
        if (complaintsFull.trim().isNotEmpty) {
          complaintsFullForTitle = complaintsFull;
          // (was: displayTitle assignment removed)
          movedComplaintToTitle = true;
        } else {
          // (was: displayTitle assignment removed)
        }
      } else {
  // (legacy displayTitle removed)
      }
      final badge = !isFollowUp && parentCount != null && parentCount > 0
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(left:8),
              padding: const EdgeInsets.symmetric(horizontal:8, vertical:4),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _typeColor(s).withOpacity(.85),
                  _typeColor(s).withOpacity(.55),
                ]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _typeColor(s).withOpacity(.35),
                    blurRadius: 6,
                    offset: const Offset(0,2),
                  )
                ],
              ),
              child: Text(parentCount.toString(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : const SizedBox.shrink();
      // Timeline visuals for follow-ups
      Widget leadingBullet(bool isLast) {
        return SizedBox(
          width: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 2,
                  height: 18,
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                ),
            ],
          ),
        );
      }
      final gradient = _typeGradientColors(s, followUp: isFollowUp);
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _typeColor(s).withOpacity(.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: _typeColor(s).withOpacity(.20),
              blurRadius: 14,
              offset: const Offset(0,6),
              spreadRadius: -2,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              iconColor: _typeColor(s).withOpacity(.9),
              collapsedIconColor: _typeColor(s).withOpacity(.8),
              tilePadding: EdgeInsets.only(left: isFollowUp ? 8 : 12, right: 8, top: 4, bottom: 4),
              childrenPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (isFollowUp)
                        leadingBullet(false)
                      else
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: _typeColor(s).withOpacity(.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Icon(_typeIcon(s), size: 18, color: _typeColor(s).withOpacity(.9)),
                        ),
                      Expanded(
                        child: isFollowUp
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // First line: date + label
                                  Text(
                                    '${s.date.toLocal().toIso8601String().split('T').first} • Follow-Up',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(.85),
                                      fontSize: 13.0,
                                    ),
                                    softWrap: true,
                                  ),
                                  // Second line: Treatment Done summary if any
                                  Builder(builder: (_) {
                                    final structured = s.treatmentsDone;
                                    final legacy = doneOpts;
                                    if (structured.isEmpty && legacy.isEmpty) return const SizedBox.shrink();
                                    String line;
                                    if (structured.isNotEmpty) {
                                      final entries = structured
                                          .map((e) => (e.toothNumber.trim().isEmpty ? e.treatment : '${e.toothNumber}-${e.treatment}'))
                                          .toList();
                                      line = entries.join(', ');
                                    } else {
                                      line = legacy.join(', ');
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Done: ' + line,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(.70),
                                              fontSize: 11.5,
                                            ),
                                        softWrap: true,
                                      ),
                                    );
                                  }),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (!isFollowUp) badge,
                      if (!isFollowUp && s.type == TreatmentType.general)
                        Tooltip(
                          message: 'Add Follow-Up',
                          child: IconButton(
                            icon: const Icon(Icons.reply_all, size: 20),
                            onPressed: () {
                              _startFollowUpFrom(s);
                              setState(() => _showRxForm = true);
                            },
                          ),
                        ),
                      Tooltip(
                        message: 'View',
                        child: IconButton(
                            icon: const Icon(Icons.visibility_rounded, size: 20),
                            onPressed: () => _viewSessionDialog(s, planOpts, doneOpts)),
                      ),
                      Tooltip(
                        message: 'Edit',
                        child: IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 20),
                            onPressed: () => _editExistingSession(s)),
                      ),
                      Tooltip(
                        message: 'Delete',
                        child: IconButton(
                            icon: const Icon(Icons.delete_forever_rounded, size: 20),
                            onPressed: () => _deleteSessionConfirm(patient, s.id)),
                      ),
                    ],
                  ),
                  if (movedComplaintToTitle) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _typeColor(s).withOpacity(.13),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _typeColor(s).withOpacity(.30), width: .8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              complaintsFullForTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(.92),
                                height: 1.15,
                              ),
                              softWrap: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            datePart,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(.70),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Treatment Done summary (structured preferred)
                    if (s.treatmentsDone.isNotEmpty || doneOpts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Builder(builder: (_) {
                        String line = '';
                        if (s.treatmentsDone.isNotEmpty) {
                          final entries = s.treatmentsDone
                              .map((e) => (e.toothNumber.trim().isEmpty ? e.treatment : '${e.toothNumber}-${e.treatment}'))
                              .toList();
                          const maxItems = 4;
                          if (entries.length > maxItems) {
                            line = entries.take(maxItems).join(', ') + ' +${entries.length - maxItems} more';
                          } else {
                            line = entries.join(', ');
                          }
                        } else {
                          line = doneOpts.join(', ');
                        }
                        if (line.isEmpty) return const SizedBox.shrink();
                        return Text(
                          'Treatment Done: ' + line,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(.75),
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      }),
                    ],
                  ] else ...[
                    if (!isFollowUp) const SizedBox(height: 4),
                    if (!isFollowUp && orderedDetails.isNotEmpty)
                      Text(
                        orderedDetails.first,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(.75),
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (!isFollowUp && (s.treatmentsDone.isNotEmpty || doneOpts.isNotEmpty)) ...[
                      const SizedBox(height: 4),
                      Builder(builder: (_) {
                        final hasStructuredDone = s.treatmentsDone.isNotEmpty;
                        String treatmentDoneLine = '';
                        if (hasStructuredDone) {
                          final entries = s.treatmentsDone
                              .map((e) => (e.toothNumber.trim().isEmpty ? e.treatment : '${e.toothNumber}-${e.treatment}'))
                              .toList();
                          const maxItems = 4;
                          if (entries.length > maxItems) {
                            treatmentDoneLine = entries.take(maxItems).join(', ') + ' +${entries.length - maxItems} more';
                          } else {
                            treatmentDoneLine = entries.join(', ');
                          }
                        } else if (doneOpts.isNotEmpty) {
                          treatmentDoneLine = doneOpts.join(', ');
                        }
                        if (treatmentDoneLine.isEmpty) return const SizedBox.shrink();
                        return Text(
                          'Treatment Done: ' + treatmentDoneLine,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(.75),
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      }),
                    ],
                  ]
                ],
              ),
              // Removed separate subtitle & trailing; integrated into custom title Column (Option B)
              children: [
                // Removed expanded Add Follow-Up button (only trailing icon now)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: orderedDetails.map((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(l),
                        )).toList(),
                  ),
                ),
                if (!isFollowUp && (childFollowUpsFiltered?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _typeColor(s).withOpacity(.85),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Follow-Ups', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (var i=0;i<childFollowUpsFiltered!.length;i++)
                    Padding(
                      padding: const EdgeInsets.only(left:4),
                      child: buildTile(childFollowUpsFiltered[i], isFollowUp: true),
                    ),
                ]
              ],
            ),
          ),
        ),
      );
    }
    bool matches(TreatmentSession s) {
      if (_sessionFilterDateStr == null) return true;
      return s.date.toLocal().toString().split(' ').first == _sessionFilterDateStr;
    }

    final parentTiles = <Widget>[];
    for (final p in parents) {
      final children = (followUps[p.id] ?? [])..sort((a,b)=> a.date.compareTo(b.date));
      final filteredChildren = children.where(matches).toList();
      if (!matches(p) && filteredChildren.isEmpty) continue;
      parentTiles.add(buildTile(p,
          isFollowUp: false,
          parentCount: (followUps[p.id] ?? []).length,
          childFollowUpsFiltered: filteredChildren));
    }
    if (parentTiles.isEmpty) return const SizedBox();
    // Constrain with scroll if many entries
    final content = Column(children: parentTiles);
    if (parentTiles.length > 4) {
      return SizedBox(height: 360, child: SingleChildScrollView(child: content));
    }
    return content;
  }

  List<String> _buildSessionDetailLines(TreatmentSession s, List<String> planOpts, List<String> doneOpts) {
    final lines = <String>[];
    if (s.chiefComplaint != null && (s.chiefComplaint!.complaints.isNotEmpty || s.chiefComplaint!.quadrants.isNotEmpty)) {
      lines.add('Chief Complaint: ${s.chiefComplaint!.complaints.join(', ')}');
      if (s.chiefComplaint!.quadrants.isNotEmpty) {
        lines.add('Quadrants: ${s.chiefComplaint!.quadrants.join(', ')}');
      }
    }
    if (s.oralExamFindings.isNotEmpty) {
      lines.add('Oral Findings: ${s.oralExamFindings.map((e) => '${e.toothNumber}-${e.finding}').join('; ')}');
    }
    if (s.investigations.isNotEmpty) {
      lines.add('Investigations: ${s.investigations.map((e) => e.label).join(', ')}');
    }
    if (s.investigationFindings.isNotEmpty) {
      lines.add('Investigation Findings: ${s.investigationFindings.map((e) => '${e.toothNumber}-${e.finding}').join('; ')}');
    }
    if (planOpts.isNotEmpty) {
      lines.add('Plan Options: ${planOpts.join(', ')}');
    }
    if (doneOpts.isNotEmpty) {
      lines.add('Treatment Done: ${doneOpts.join(', ')}');
    }
    if (s.toothPlans.isNotEmpty) {
      lines.add('Tooth Plans: ${s.toothPlans.map((e) => '${e.toothNumber}-${e.plan}').join('; ')}');
    }
    if (s.treatmentsDone.isNotEmpty) {
      lines.add('Tooth Treatments: ${s.treatmentsDone.map((e) => '${e.toothNumber}-${e.treatment}').join('; ')}');
    }
    if (s.prescription.isNotEmpty) {
      lines.add('Prescription: ${s.prescription.map((e) => '#${e.serial} ${e.medicine} ${e.timing}').join('; ')}');
    }
    if (s.nextAppointment != null) {
      lines.add('Next Appt: ${s.nextAppointment!.toLocal().toString().split(' ').first}');
    }
    if (s.notes.isNotEmpty) {
      lines.add('Notes: ${s.notes}');
    }
    return lines;
  }

  void _viewSessionDialog(TreatmentSession s, List<String> planOpts, List<String> doneOpts) {
    // Custom rich formatting only for general sessions as requested
    if (s.type == TreatmentType.general) {
      final bold = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold);
      String _alphaIndex(int i) => String.fromCharCode(97 + i); // a, b, c

      final ccComplaints = s.chiefComplaint?.complaints ?? [];
      final ccQuadrants = s.chiefComplaint?.quadrants ?? [];
      final oral = s.oralExamFindings;
      final invDone = s.investigations;
      final invFindings = s.investigationFindings;
      final toothPlans = s.toothPlans; // structured per-tooth plan
      final toothTreatments = s.treatmentsDone; // structured per-tooth treatments

      // Fallback to option lists if structured lists empty
      final planDisplayStructured = toothPlans.isNotEmpty;
      final treatmentDisplayStructured = toothTreatments.isNotEmpty;

      final children = <Widget>[];
      int section = 1;

      // 1. Chief complaint (always show in general for clarity)
      final complaintText = ccComplaints.isNotEmpty ? ccComplaints.join(', ') : 'No complaint recorded';
      final quadrantsText = ccQuadrants.isNotEmpty ? ccQuadrants.join(', ') : 'N/A';
      children.add(RichText(
        text: TextSpan(style: Theme.of(context).textTheme.bodyMedium, children: [
          TextSpan(text: '${section++}. '),
          TextSpan(text: 'Chief complaint', style: bold),
          const TextSpan(text: ' : '),
          TextSpan(text: 'Pt c/o of $complaintText wrt $quadrantsText.'),
        ]),
      ));
      children.add(const SizedBox(height: 6));

      // 2. Oral findings enumerated a) tooth, finding
      final oralLine = oral.isNotEmpty
          ? oral.asMap().entries.map((e) {
              final idx = e.key; final f = e.value;
              final display = f.toothNumber.trim().isEmpty ? f.finding : '${f.toothNumber}, ${f.finding}';
              return '${_alphaIndex(idx)}) $display';
            }).join('  ')
          : 'None';
      children.add(RichText(
        text: TextSpan(style: Theme.of(context).textTheme.bodyMedium, children: [
          TextSpan(text: '${section++}. '),
          TextSpan(text: 'Oral findings', style: bold),
          const TextSpan(text: ' : '),
          TextSpan(text: oralLine),
        ]),
      ));
      children.add(const SizedBox(height: 6));

      // 3. Investigation done
      children.add(RichText(
        text: TextSpan(style: Theme.of(context).textTheme.bodyMedium, children: [
          TextSpan(text: '${section++}. '),
          TextSpan(text: 'Investigation done', style: bold),
          const TextSpan(text: ' : '),
          TextSpan(text: invDone.isEmpty ? 'None' : invDone.map((e) => e.label).join(', ')),
        ]),
      ));
      children.add(const SizedBox(height: 6));

      // 4. Investigational findings
      final findingsText = invFindings.isNotEmpty
          ? invFindings.map((f) => '${f.toothNumber}, ${f.finding}').join('  ')
          : 'None';
      children.add(RichText(
        text: TextSpan(style: Theme.of(context).textTheme.bodyMedium, children: [
          TextSpan(text: '${section++}. '),
          TextSpan(text: 'Investigational findings', style: bold),
          const TextSpan(text: ' : '),
          TextSpan(text: findingsText),
        ]),
      ));
      children.add(const SizedBox(height: 6));

      // 5. Treatment Plan
      String planLine;
      if (planDisplayStructured && toothPlans.isNotEmpty) {
        planLine = toothPlans.asMap().entries.map((e) {
          final idx = e.key; final p = e.value; return '${_alphaIndex(idx)}. ${p.toothNumber}, ${p.plan}';
        }).join('  ');
      } else if (planOpts.isNotEmpty) {
        planLine = planOpts.join(', ');
      } else {
        planLine = 'None';
      }
      children.add(RichText(
        text: TextSpan(style: Theme.of(context).textTheme.bodyMedium, children: [
          TextSpan(text: '${section++}. '),
          TextSpan(text: 'Treatment Plan', style: bold),
          const TextSpan(text: ' : '),
          TextSpan(text: planLine),
        ]),
      ));
      children.add(const SizedBox(height: 6));

      // 6. Treatment done
      String doneLine;
      if (treatmentDisplayStructured && toothTreatments.isNotEmpty) {
        doneLine = toothTreatments.asMap().entries.map((e) {
          final idx = e.key; final t = e.value; return '${_alphaIndex(idx)}. ${t.toothNumber}, ${t.treatment}';
        }).join('  ');
      } else if (doneOpts.isNotEmpty) {
        doneLine = doneOpts.join(', ');
      } else {
        doneLine = 'None';
      }
      children.add(RichText(
        text: TextSpan(style: Theme.of(context).textTheme.bodyMedium, children: [
          TextSpan(text: '${section++}. '),
          TextSpan(text: 'Treatment done', style: bold),
          const TextSpan(text: ' : '),
          TextSpan(text: doneLine),
        ]),
      ));
      children.add(const SizedBox(height: 6));

      // Next appointment
      if (s.nextAppointment != null) {
        children.add(RichText(
          text: TextSpan(style: Theme.of(context).textTheme.bodyMedium, children: [
            TextSpan(text: 'Next appointment: ', style: bold),
            TextSpan(text: s.nextAppointment!.toLocal().toString().split(' ').first),
          ]),
        ));
        children.add(const SizedBox(height: 6));
      }

      // Notes
      if (s.notes.isNotEmpty) {
        children.add(RichText(
          text: TextSpan(style: Theme.of(context).textTheme.bodyMedium, children: [
            TextSpan(text: 'Notes: ', style: bold),
            TextSpan(text: s.notes),
          ]),
        ));
      }

      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                title: const Text('General Session Details'),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  ),
                ),
                actions: [
          TextButton(
            onPressed: () => _printGeneralSession(
              patient: context.read<PatientProvider>().byId(widget.patientId!)!,
              s: s,
              planOpts: planOpts,
              doneOpts: doneOpts,
              ),
            child: const Text('Print')),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                ],
              ));
      return;
    }
    // Non-general fallback to previous simple list formatting
    final lines = _buildSessionDetailLines(s, planOpts, doneOpts);
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text('${s.type.label} Session Details'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: lines.map((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(l),
                        )).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            ));
  }

  void _editExistingSession(TreatmentSession s) {
    // For now: load into current form for editing only if same type (general). More types can be added later.
    if (s.type != TreatmentType.general) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit only supported for General sessions currently.')));
      return;
    }
    setState(() {
      _editingSessionId = s.id;
      _selectedType = s.type;
      _selectedComplaints = List.from(s.chiefComplaint?.complaints ?? []);
      _selectedQuadrants = List.from(s.chiefComplaint?.quadrants ?? []);
      _oralFindings
        ..clear()
        ..addAll(s.oralExamFindings);
      _investigations
        ..clear()
        ..addAll(s.investigations);
      _investigationFindings
        ..clear()
        ..addAll(s.investigationFindings);
      _selectedPlanOptions = List.from(s.planOptions);
      _selectedTreatmentDoneOptions = List.from(s.treatmentDoneOptions);
      _toothPlans
        ..clear()
        ..addAll(s.toothPlans);
      _treatmentsDone
        ..clear()
        ..addAll(s.treatmentsDone);
      _prescription
        ..clear()
        ..addAll(s.prescription);
      _notes.text = s.notes;
      _nextAppointment = s.nextAppointment;
      _showRxForm = true; // ensure form is visible when editing
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session data loaded. Make changes and Save Session.')));
  }

  void _resetFormState() {
    _selectedType = TreatmentType.general;
    _followUpParentId = null;
    _selectedComplaints.clear();
    _selectedQuadrants.clear();
    _oralFindings.clear();
    _investigations.clear();
    _investigationFindings.clear();
    _treatmentPlan.clear();
    _toothPlans.clear();
    _treatmentsDone.clear();
    _selectedPlanOptions.clear();
    _selectedTreatmentDoneOptions.clear();
    _mediaPaths.clear();
    _rvgImages.clear();
    _nextAppointment = null;
    _notes.clear();
    _prescription.clear();
    // Ortho
    _orthoFindings.clear();
    _bracketType = BracketType.metalRegular;
    _orthoTotal.clear();
    _orthoDoctor.clear();
    _orthoSteps.clear();
    // Root canal
    _rcFindings.clear();
    _rcTotal.clear();
    _rcSteps.clear();
  }

  void _startFollowUpFrom(TreatmentSession base) {
    // Only meaningful for general sessions; ignore others
    if (base.type != TreatmentType.general) return;
    setState(() {
      _resetFormState();
      _showRxForm = true;
      _followUpParentId = base.id; // link parent
      // Carry forward selected context but clear findings that should be new observations
      _selectedType = TreatmentType.general;
      _selectedComplaints = List.from(base.chiefComplaint?.complaints ?? []);
      _selectedQuadrants = List.from(base.chiefComplaint?.quadrants ?? []);
      // Do NOT copy oral exam findings or investigation findings (new exam expected)
      // Copy plan options (treatment plan often continues) but not treatments done (fresh for this visit)
      _selectedPlanOptions = List.from(base.planOptions);
      _selectedTreatmentDoneOptions.clear();
      // Structured tooth plans carried forward; treatments done not carried
      _toothPlans
        ..clear()
        ..addAll(base.toothPlans);
      _treatmentsDone.clear();
      // Prescription not copied (usually new)
      _prescription.clear();
      _notes.clear();
      _nextAppointment = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Follow-up started. Adjust details and save.')));
  }

  Future<void> _printGeneralSession({required Patient patient, required TreatmentSession s, required List<String> planOpts, required List<String> doneOpts}) async {
    // Build the exact same textual representation used in dialog
    if (s.type != TreatmentType.general) return;
    final doc = pw.Document();
    String alpha(int i) => String.fromCharCode(97 + i);

    final ccComplaints = s.chiefComplaint?.complaints ?? [];
    final ccQuadrants = s.chiefComplaint?.quadrants ?? [];
    final oral = s.oralExamFindings;
    final invDone = s.investigations;
    final invFindings = s.investigationFindings;
    final toothPlans = s.toothPlans;
    final toothTreatments = s.treatmentsDone;
    final planDisplayStructured = toothPlans.isNotEmpty;
    final treatmentDisplayStructured = toothTreatments.isNotEmpty;

    String complaintText = ccComplaints.isNotEmpty ? ccComplaints.join(', ') : 'No complaint recorded';
    String quadrantsText = ccQuadrants.isNotEmpty ? ccQuadrants.join(', ') : 'N/A';
  String oralLine = oral.isNotEmpty
    ? oral.asMap().entries.map((e) {
      final f = e.value; final idx = e.key;
      final display = f.toothNumber.trim().isEmpty ? f.finding : '${f.toothNumber}, ${f.finding}';
      return '${alpha(idx)}) $display';
      }).join('  ')
    : 'None';
    String invDoneLine = invDone.isEmpty ? 'None' : invDone.map((e) => e.label).join(', ');
    String invFindingsLine = invFindings.isNotEmpty
        ? invFindings.map((f) => '${f.toothNumber}, ${f.finding}').join('  ')
        : 'None';
    String planLine;
    if (planDisplayStructured && toothPlans.isNotEmpty) {
      planLine = toothPlans.asMap().entries.map((e) => '${alpha(e.key)}. ${e.value.toothNumber}, ${e.value.plan}').join('  ');
    } else if (planOpts.isNotEmpty) {
      planLine = planOpts.join(', ');
    } else {
      planLine = 'None';
    }
    String doneLine;
    if (treatmentDisplayStructured && toothTreatments.isNotEmpty) {
      doneLine = toothTreatments.asMap().entries.map((e) => '${alpha(e.key)}. ${e.value.toothNumber}, ${e.value.treatment}').join('  ');
    } else if (doneOpts.isNotEmpty) {
      doneLine = doneOpts.join(', ');
    } else {
      doneLine = 'None';
    }
    final nextAppt = s.nextAppointment == null ? null : s.nextAppointment!.toLocal().toString().split(' ').first;

    // Load optional header/footer images (ignore if missing)
    Future<pw.Widget?> loadImage(String assetPath) async {
      try {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List();
        final image = pw.MemoryImage(bytes);
        return pw.Image(image, fit: pw.BoxFit.contain, height: 80);
      } catch (_) {
        return null;
      }
    }

    Future<pw.Widget?> resolveImage(String base) async {
      // If caller passes a name with extension already, try directly first
      final hasExt = base.contains('.') && !base.endsWith('.');
      final candidates = <String>[];
      if (hasExt) {
        candidates.add('assets/images/' + base);
      } else {
        candidates.addAll([
          'assets/images/' + base + '.png',
          'assets/images/' + base + '.jpg',
          'assets/images/' + base + '.jpeg',
        ]);
      }
      for (final c in candidates) {
        final w = await loadImage(c);
        if (w != null) return w;
      }
      // Debug print (will show in console, harmless in release)
      // ignore: avoid_print
      print('Print header/footer: none of these paths found: ' + candidates.join(', '));
      return null;
    }

    final headerImage = await resolveImage('clinic_header');
    final footerImage = await resolveImage('clinic_footer');

  final demographicsLeft = 'Patient: ${patient.name}\nID: ${patient.displayNumber}${patient.customNumber.isNotEmpty ? ' (${patient.customNumber})' : ''}\nAge/Sex: ${patient.age}/${patient.sex.label}\nDate: ${DateTime.now().toLocal().toString().split(' ').first}';
    // Build concise history summary (only show non-empty)
    List<pw.Widget> historyLines = [];
    if (patient.pastDentalHistory.isNotEmpty) {
      historyLines.add(pw.Text('Dental: ' + patient.pastDentalHistory.join(', '), style: const pw.TextStyle(fontSize: 9)));
    }
    if (patient.pastMedicalHistory.isNotEmpty) {
      historyLines.add(pw.Text('Medical: ' + patient.pastMedicalHistory.join(', '), style: const pw.TextStyle(fontSize: 9)));
    }
    if (patient.currentMedications.isNotEmpty) {
      historyLines.add(pw.Text('Meds: ' + patient.currentMedications.join(', '), style: const pw.TextStyle(fontSize: 9)));
    }
    if (patient.drugAllergies.isNotEmpty) {
  historyLines.add(pw.Text('Allergies: ' + patient.drugAllergies.join(', '), style: const pw.TextStyle(fontSize: 9)));
    }

    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => headerImage == null
            ? pw.SizedBox()
            : pw.Column(children: [headerImage, pw.Divider(thickness: 1)]),
        footer: (ctx) => footerImage == null
            ? pw.SizedBox()
            : pw.Column(children: [pw.Divider(thickness: 1), footerImage]),
        build: (ctx) => [
          pw.Text('GENERAL SESSION REPORT', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: pw.Text(demographicsLeft, style: const pw.TextStyle(fontSize: 10))),
                if (historyLines.isNotEmpty) ...[
                  pw.SizedBox(width: 16),
                  pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('History:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), ...historyLines]))
                ]
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text('1. Chief complaint : Pt c/o of $complaintText wrt $quadrantsText.'),
            pw.SizedBox(height: 4),
            pw.Text('2. Oral findings : $oralLine'),
            pw.SizedBox(height: 4),
            pw.Text('3. Investigation done : $invDoneLine'),
            pw.SizedBox(height: 4),
            pw.Text('4. Investigational findings : $invFindingsLine'),
            pw.SizedBox(height: 4),
            pw.Text('5. Treatment Plan : $planLine'),
            pw.SizedBox(height: 4),
            pw.Text('6. Treatment done : $doneLine'),
            if (nextAppt != null) ...[
              pw.SizedBox(height: 8),
              pw.Text('Next appointment: $nextAppt'),
            ],
            if (s.notes.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text('Notes: ${s.notes}'),
            ],
        ],
      ),
    );

  await Printing.layoutPdf(onLayout: (format) async => doc.save());
    if (headerImage == null || footerImage == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Header/Footer image missing (expected clinic_header / clinic_footer in assets/images).')));
      }
    }
  }

  // New containerized session history with rounded edges
  Widget _sessionHistoryContainer(patient) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          // Outline only look
          color: Theme.of(context).colorScheme.surface.withOpacity(.0),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(.35), width: 1.4),
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isNarrow = constraints.maxWidth < 480;
              // Build unique session date list (yyyy-mm-dd) from patient's sessions
              final sessions = patient.sessions as List<TreatmentSession>;
              final dateSet = <String>{};
              for (final s in sessions) {
                dateSet.add(s.date.toLocal().toString().split(' ').first);
              }
              final dates = dateSet.toList()..sort((a,b)=> b.compareTo(a));
              final dateDropdown = ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: DropdownButtonFormField<String>(
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Registered Date'),
                  value: _sessionFilterDateStr ?? '',
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All Dates')),
                    ...dates.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  ],
                  onChanged: (val) => setState(() => _sessionFilterDateStr = (val == '' ? null : val)),
                ),
              );
              final clearBtn = (_sessionFilterDateStr != null)
                  ? IconButton(
                      tooltip: 'Clear date filter',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _sessionFilterDateStr = null),
                    )
                  : const SizedBox.shrink();
              final addRxBtn = TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => setState(() => _showRxForm = !_showRxForm),
                icon: Icon(_showRxForm ? Icons.close : Icons.add_circle_outline),
                label: Text(_showRxForm ? 'Close' : 'Add Rx'),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Previous Sessions',
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        addRxBtn,
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: dateDropdown),
                        clearBtn,
                      ],
                    ),
                  ],
                );
              }
              // Wide layout: keep in one row
              return Row(
                children: [
                  Text('Previous Sessions', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 16),
                  dateDropdown,
                  const SizedBox(width: 8),
                  clearBtn,
                  const Spacer(),
                  addRxBtn,
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          _sessionHistory(patient),
        ],
      ), // Column
    ), // inner Container
  );
  }

  Future<void> _deleteSessionConfirm(patient, String sessionId) async {
    final sessions = patient.sessions as List<TreatmentSession>;
    final hasChildren = sessions.any((s) => s.parentSessionId == sessionId);
    bool cascade = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (c, setSt) {
        return AlertDialog(
          title: const Text('Delete Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasChildren)
                const Text('Are you sure you want to delete this session permanently?')
              else ...[
                const Text('This session has follow-up sessions.'),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: cascade,
                  onChanged: (v)=> setSt(()=> cascade = v ?? false),
                  title: const Text('Also delete all its follow-ups (cascade).'),
                ),
                const SizedBox(height:4),
                if(!cascade) const Text('Deletion blocked unless you choose cascade.', style: TextStyle(fontSize:12, color: Colors.redAccent)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (hasChildren && !cascade) {
                  Navigator.pop(context, false);
                } else {
                  Navigator.pop(context, true);
                }
              },
              child: Text(hasChildren ? (cascade ? 'Delete All' : 'Delete') : 'Delete'),
            ),
          ],
        );
      })
    );
    if (ok == true) {
      final provider = context.read<PatientProvider>();
      // If cascade, delete children first
      if (cascade) {
        final children = sessions.where((s) => s.parentSessionId == sessionId).toList();
        for (final ch in children) {
          await provider.removeSession(patient.id, ch.id);
        }
      }
      await provider.removeSession(patient.id, sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Session${cascade ? ' and follow-ups' : ''} deleted')));
      setState(() {});
    }
  }
}
