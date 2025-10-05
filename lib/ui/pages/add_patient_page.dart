import 'package:flutter/material.dart';
import '../../providers/patient_provider.dart';
import 'package:provider/provider.dart';
import '../../core/enums.dart';
import '../../core/constants.dart';
// Removed legacy simple SearchMultiSelect (using editable variant)
import '../widgets/search_editable_multi_select.dart';
import '../../providers/options_provider.dart';

class AddPatientPage extends StatefulWidget {
  static const routeName = '/add-patient';
  const AddPatientPage({super.key});
  @override
  State<AddPatientPage> createState() => _AddPatientPageState();
}

class _AddPatientPageState extends State<AddPatientPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  Sex _sex = Sex.male;
  // History selections
  List<String> _pastDental = [];
  List<String> _pastMedical = [];
  List<String> _currentMeds = [];
  List<String> _drugAllergies = [];

  @override
  Widget build(BuildContext context) {
    // Load dynamic options for history
    final opt = context.read<OptionsProvider>();
    if (!opt.isLoaded) {
      opt.ensureLoaded(
        defaultComplaints: const [], // not needed here
        defaultOralFindings: const [],
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
      appBar: AppBar(title: const Text('Add Patient')),
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
                items: Sex.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                    .toList(),
                onChanged: (v) => setState(() => _sex = v ?? Sex.male),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    await context.read<PatientProvider>().addPatient(
                          name: _name.text.trim(),
                          age: int.tryParse(_age.text.trim()) ?? 0,
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
                  label: const Text('Save'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
