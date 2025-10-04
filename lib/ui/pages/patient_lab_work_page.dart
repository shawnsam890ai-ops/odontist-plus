import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/lab_provider.dart';
import '../../core/constants.dart';

class PatientLabWorkPage extends StatefulWidget {
  static const routeName = '/patient-lab-work';
  final String? patientId;
  const PatientLabWorkPage({super.key, required this.patientId});

  @override
  State<PatientLabWorkPage> createState() => _PatientLabWorkPageState();
}

class _PatientLabWorkPageState extends State<PatientLabWorkPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<LabProvider>().ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final labProvider = context.watch<LabProvider>();
    final patientId = widget.patientId;
    if (patientId == null) {
      return const Scaffold(body: Center(child: Text('Patient ID missing')));
    }
    final works = labProvider.byPatient(patientId);

    return Scaffold(
      appBar: AppBar(title: const Text('Lab Work')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addWork(patientId),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: works.length,
        itemBuilder: (_, i) {
          final w = works[i];
          return Card(
            child: ListTile(
              title: Text('${w.workType} (${w.shade})'),
              subtitle: Text('Lab: ${w.labName}\nDue: ${w.expectedDelivery.toLocal().toString().split(' ').first}${w.delivered ? '\nDelivered' : ''}'),
              trailing: Switch(
                value: w.delivered,
                onChanged: (v) => context.read<LabProvider>().markDelivered(w.id, v),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addWork(String patientId) async {
    final labName = TextEditingController();
    String? workType;
    final shade = TextEditingController();
    DateTime? expected;
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
              return AlertDialog(
                title: const Text('Add Lab Work'),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: labName,
                          decoration: const InputDecoration(labelText: 'Lab Name'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: workType,
                          decoration: const InputDecoration(labelText: 'Work Type'),
                          items: AppConstants.labWorkTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setSt(() => workType = v),
                          validator: (v) => v == null ? 'Choose type' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: shade,
                          decoration: const InputDecoration(labelText: 'Shade'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(expected == null ? 'Pick expected date' : 'Expected: ${expected!.toLocal().toString().split(' ').first}'),
                            ),
                            TextButton(
                                onPressed: () async {
                                  final now = DateTime.now();
                                  final d = await showDatePicker(
                                      context: context,
                                      initialDate: now,
                                      firstDate: now.subtract(const Duration(days: 1)),
                                      lastDate: now.add(const Duration(days: 365)));
                                  if (d != null) setSt(() => expected = d);
                                },
                                child: const Text('Select'))
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate() && expected != null) {
                          Navigator.pop(context, true);
                        }
                      },
                      child: const Text('Add'))
                ],
              );
            }));
    if (result == true) {
      await context.read<LabProvider>().addWork(
            patientId: patientId,
            labName: labName.text.trim(),
            workType: workType!,
            shade: shade.text.trim(),
            expectedDelivery: expected!,
          );
    }
  }
}
