import 'package:flutter/material.dart';
import '../../providers/patient_provider.dart';
import 'package:provider/provider.dart';
import '../../core/enums.dart';
import '../../core/constants.dart';
import '../widgets/search_multi_select.dart';

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
              SearchMultiSelect(
                options: AppConstants.pastDentalHistoryOptions,
                initial: _pastDental,
                label: 'Past Dental History',
                onChanged: (v) => setState(() => _pastDental = v),
              ),
              const SizedBox(height: 12),
              SearchMultiSelect(
                options: AppConstants.pastMedicalHistoryOptions,
                initial: _pastMedical,
                label: 'Past Medical History',
                onChanged: (v) => setState(() => _pastMedical = v),
              ),
              if (_pastMedical.isNotEmpty) ...[
                const SizedBox(height: 12),
                SearchMultiSelect(
                  options: AppConstants.medicationOptions,
                  initial: _currentMeds,
                  label: 'Current Medications',
                  onChanged: (v) => setState(() => _currentMeds = v),
                ),
              ],
              const SizedBox(height: 12),
              SearchMultiSelect(
                options: AppConstants.drugAllergyOptions,
                initial: _drugAllergies,
                label: 'Drug Allergies',
                onChanged: (v) => setState(() => _drugAllergies = v),
              ),
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
