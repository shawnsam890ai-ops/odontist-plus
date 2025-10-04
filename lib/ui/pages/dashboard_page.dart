import 'package:flutter/material.dart';
import 'patient_list_page.dart';
import '../../providers/patient_provider.dart';
import '../../providers/revenue_provider.dart';
import 'add_patient_page.dart';
import 'package:provider/provider.dart';

class DashboardPage extends StatelessWidget {
  static const routeName = '/dashboard';
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final revenueProvider = context.watch<RevenueProvider>();
    final patientProvider = context.watch<PatientProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(title: 'Patients', value: patientProvider.patients.length.toString(), icon: Icons.people),
                  _StatCard(title: 'Revenue', value: '₹${revenueProvider.total.toStringAsFixed(2)}', icon: Icons.currency_rupee),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed(AddPatientPage.routeName),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Patient'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed(PatientListPage.routeName),
                    icon: const Icon(Icons.list),
                    label: const Text('Existing Patients'),
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _StatCard({required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 120,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28),
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.labelMedium),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}
