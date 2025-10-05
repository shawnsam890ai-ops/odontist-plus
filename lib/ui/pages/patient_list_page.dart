import 'package:flutter/material.dart';
import 'patient_detail_page.dart';
import '../../providers/patient_provider.dart';
import 'package:provider/provider.dart';

class PatientListPage extends StatefulWidget {
  static const routeName = '/patients';
  const PatientListPage({super.key});

  @override
  State<PatientListPage> createState() => _PatientListPageState();
}

class _PatientListPageState extends State<PatientListPage> {
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PatientProvider>();
    final patients = provider.patients;
    final filtered = _query.isEmpty
        ? patients
        : patients.where((p) => p.name.toLowerCase().contains(_query.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _query = '';
                            _searchCtrl.clear();
                          });
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
          ? const Center(child: Text('No patients found'))
          : ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = filtered[index];
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
