import 'package:flutter/material.dart';
import 'patient_detail_page.dart';
import '../../providers/patient_provider.dart';
import 'package:provider/provider.dart';

class PatientListPage extends StatelessWidget {
  static const routeName = '/patients';
  const PatientListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PatientProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Patients')),
      body: ListView.separated(
        itemCount: provider.patients.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final p = provider.patients[index];
          return ListTile(
            title: Text('${p.displayNumber}. ${p.name}'),
            subtitle: Text(p.phone),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(PatientDetailPage.routeName, arguments: {'patientId': p.id}),
          );
        },
      ),
    );
  }
}
