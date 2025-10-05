import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/patient_provider.dart';
import '../../core/enums.dart';
import '../../core/constants.dart';
import '../widgets/search_editable_multi_select.dart';
import '../../providers/options_provider.dart';

class EditPatientPage extends StatefulWidget {
  static const routeName = '/edit-patient';
  final String patientId;
  const EditPatientPage({super.key, required this.patientId});

  @override
  State<EditPatientPage> createState() => _EditPatientPageState();
}

class _EditPatientPageState extends State<EditPatientPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _age;
  late TextEditingController _address;
  late TextEditingController _phone;
  Sex _sex = Sex.male;
  List<String> _pastDental = [];
  List<String> _pastMedical = [];
  List<String> _currentMeds = [];
  List<String> _drugAllergies = [];
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      final patient = context.read<PatientProvider>().byId(widget.patientId);
      if (patient != null) {
        _name = TextEditingController(text: patient.name);
        _age = TextEditingController(text: patient.age.toString());
        _address = TextEditingController(text: patient.address);
        _phone = TextEditingController(text: patient.phone);
        _sex = patient.sex;
        _pastDental = List.from(patient.pastDentalHistory);
        _pastMedical = List.from(patient.pastMedicalHistory);
        _currentMeds = List.from(patient.currentMedications);
        _drugAllergies = List.from(patient.drugAllergies);
        _loaded = true;
      } else {
        // Pop if patient missing
        WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Load dynamic option lists (history) if not already
    final opt = context.read<OptionsProvider>();
    if (!opt.isLoaded) {
      opt.ensureLoaded(
        defaultComplaints: const [],
        defaultPlan: const [],
        defaultTreatmentDone: const [],
        defaultMedicines: const [],
        defaultPastDental: AppConstants.pastDentalHistoryOptions,
        defaultPastMedical: AppConstants.pastMedicalHistoryOptions,
        defaultMedicationOptions: AppConstants.medicationOptions,
        defaultDrugAllergies: AppConstants.drugAllergyOptions,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Patient')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Patient Name'),
                validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _age,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Enter age' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Sex>(
                value: _sex,
                items: Sex.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                onChanged: (v) => setState(() => _sex = v ?? _sex),
                decoration: const InputDecoration(labelText: 'Sex'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              Text('Medical / Dental History', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Builder(builder: (ctx){
                final watch = ctx.watch<OptionsProvider>();
                return SearchEditableMultiSelect(
                  label: 'Past Dental History',
                  options: watch.pastDentalHistory,
                  initial: _pastDental,
                  onChanged: (v)=> setState(()=> _pastDental = v),
                  onAdd: (val)=> watch.addValue('pastDental', val),
                  onDelete: (val) async {
                    final ok = await watch.removeValue('pastDental', val);
                    if (!ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete: option in use.')));
                    }
                  },
                );
              }),
              const SizedBox(height: 12),
              Builder(builder: (ctx){
                final watch = ctx.watch<OptionsProvider>();
                return SearchEditableMultiSelect(
                  label: 'Past Medical History',
                  options: watch.pastMedicalHistory,
                  initial: _pastMedical,
                  onChanged: (v)=> setState(()=> _pastMedical = v),
                  onAdd: (val)=> watch.addValue('pastMedical', val),
                  onDelete: (val) async {
                    final ok = await watch.removeValue('pastMedical', val);
                    if (!ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete: option in use.')));
                    }
                  },
                );
              }),
              if (_pastMedical.isNotEmpty) ...[
                const SizedBox(height: 12),
                Builder(builder: (ctx){
                  final watch = ctx.watch<OptionsProvider>();
                  return SearchEditableMultiSelect(
                    label: 'Current Medications',
                    options: watch.medicationOptions,
                    initial: _currentMeds,
                    onChanged: (v)=> setState(()=> _currentMeds = v),
                    onAdd: (val)=> watch.addValue('dynamicMedications', val),
                    onDelete: (val) async {
                      final ok = await watch.removeValue('dynamicMedications', val);
                      if (!ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete: option in use.')));
                      }
                    },
                  );
                }),
              ],
              const SizedBox(height: 12),
              Builder(builder: (ctx){
                final watch = ctx.watch<OptionsProvider>();
                return SearchEditableMultiSelect(
                  label: 'Drug Allergies',
                  options: watch.drugAllergyOptions,
                  initial: _drugAllergies,
                  onChanged: (v)=> setState(()=> _drugAllergies = v),
                  onAdd: (val)=> watch.addValue('drugAllergies', val),
                  onDelete: (val) async {
                    final ok = await watch.removeValue('drugAllergies', val);
                    if (!ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete: option in use.')));
                    }
                  },
                );
              }),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;
                        final ageVal = int.tryParse(_age.text.trim());
                        if (ageVal == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid age value')));
                          return;
                        }
                        await context.read<PatientProvider>().updatePatient(
                              patientId: widget.patientId,
                              name: _name.text.trim(),
                              age: ageVal,
                              sex: _sex,
                              address: _address.text.trim(),
                              phone: _phone.text.trim(),
                              pastDentalHistory: _pastDental,
                              pastMedicalHistory: _pastMedical,
                              currentMedications: _currentMeds,
                              drugAllergies: _drugAllergies,
                            );
                        if (!mounted) return;
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
