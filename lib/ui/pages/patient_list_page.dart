import 'package:flutter/material.dart';
import 'patient_detail_page.dart';
import '../../providers/patient_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../core/enums.dart';
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
  // Filters
  Sex? _sex;
  String? _doctorId; // from DoctorProvider
  TreatmentType? _type;
  DateTime? _start;
  DateTime? _end;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PatientProvider>();
    final docProvider = context.watch<DoctorProvider>();
    final patients = provider.patients;
    bool hasSessionFilters = _doctorId != null || _type != null || _start != null || _end != null;
    String? selectedDoctorName = _doctorId == null ? null : docProvider.byId(_doctorId!)?.name;
    String norm(String s) => s
        .toLowerCase()
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll(RegExp(r'^dr\s+'), '')
        .trim();
    bool sessionMatches(sess) {
      // sess is TreatmentSession
      if (_type != null && sess.type != _type) return false;
      if (_start != null && sess.date.isBefore(_start!)) return false;
      if (_end != null && sess.date.isAfter(_end!)) return false;
      if (selectedDoctorName != null) {
        String? docName;
        switch (sess.type) {
          case TreatmentType.rootCanal:
            docName = sess.rootCanalDoctorInCharge;
            break;
          case TreatmentType.orthodontic:
            docName = sess.orthoDoctorInCharge;
            break;
          case TreatmentType.prosthodontic:
            docName = sess.prosthodonticDoctorInCharge;
            break;
          case TreatmentType.general:
          case TreatmentType.labWork:
            docName = null;
            break;
        }
        if (docName == null) return false;
        if (norm(docName) != norm(selectedDoctorName)) return false;
      }
      return true;
    }
    final filtered = patients.where((p) {
      if (_query.isNotEmpty && !p.name.toLowerCase().contains(_query.toLowerCase())) return false;
      if (_sex != null && p.sex != _sex) return false;
      if (!hasSessionFilters) return true;
      // For session-level filters, include patient if ANY session matches
      for (final s in p.sessions) {
        if (sessionMatches(s)) return true;
      }
      return false;
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(132),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                // Search
                TextField(
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
                const SizedBox(height: 8),
                // Filters row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<Sex?>(
                        value: _sex,
                        decoration: const InputDecoration(labelText: 'Sex'),
                        items: const [
                          DropdownMenuItem<Sex?>(value: null, child: Text('All')),
                          DropdownMenuItem<Sex?>(value: Sex.male, child: Text('Male')),
                          DropdownMenuItem<Sex?>(value: Sex.female, child: Text('Female')),
                          DropdownMenuItem<Sex?>(value: Sex.other, child: Text('Other')),
                        ],
                        onChanged: (v) => setState(() => _sex = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String?>(
                        value: _doctorId,
                        decoration: const InputDecoration(labelText: 'Doctor treated'),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All')),
                          for (final d in docProvider.doctors)
                            DropdownMenuItem<String?>(value: d.id, child: Text(d.name)),
                        ],
                        onChanged: (v) => setState(() => _doctorId = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<TreatmentType?>(
                        value: _type,
                        decoration: const InputDecoration(labelText: 'Treatment type'),
                        items: const [
                          DropdownMenuItem<TreatmentType?>(value: null, child: Text('All')),
                          DropdownMenuItem<TreatmentType?>(value: TreatmentType.rootCanal, child: Text('Root Canal')),
                          DropdownMenuItem<TreatmentType?>(value: TreatmentType.orthodontic, child: Text('Orthodontic')),
                          DropdownMenuItem<TreatmentType?>(value: TreatmentType.prosthodontic, child: Text('Prosthodontic')),
                          DropdownMenuItem<TreatmentType?>(value: TreatmentType.general, child: Text('General')),
                          DropdownMenuItem<TreatmentType?>(value: TreatmentType.labWork, child: Text('Lab Work')),
                        ],
                        onChanged: (v) => setState(() => _type = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 1),
                          initialDateRange: _start == null || _end == null ? null : DateTimeRange(start: _start!, end: _end!),
                        );
                        if (picked != null) {
                          setState(() {
                            _start = picked.start;
                            _end = picked.end;
                          });
                        }
                      },
                      child: Text(_start == null ? 'Date range' : '${_start!.year}-${_start!.month.toString().padLeft(2, '0')}-${_start!.day.toString().padLeft(2, '0')} → ${_end!.year}-${_end!.month.toString().padLeft(2, '0')}-${_end!.day.toString().padLeft(2, '0')}'),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Clear filters',
                      onPressed: () => setState(() { _sex = null; _doctorId = null; _type = null; _start = null; _end = null; }),
                      icon: const Icon(Icons.clear),
                    )
                  ]),
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: Text('Results: ${filtered.length}')),
              ],
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
