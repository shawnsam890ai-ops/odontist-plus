import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
// table_calendar removed from this page

import '../../providers/patient_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../core/enums.dart';
import '../../models/patient.dart';
import '../../models/treatment_session.dart';
import '../responsive/responsive.dart';
import '../pages/add_patient_page.dart';
import '../pages/patient_detail_page.dart';

class ManagePatientsModern extends StatelessWidget {
  const ManagePatientsModern({super.key});

  static const routeName = '/manage-patients-modern';

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: ManagePatientsModernBody(),
    );
  }
}

class ManagePatientsModernBody extends StatefulWidget {
  const ManagePatientsModernBody({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<ManagePatientsModernBody> createState() => _ManagePatientsModernBodyState();
}

class _ManagePatientsModernBodyState extends State<ManagePatientsModernBody> {
  final Color _primary = const Color(0xFF28A745);
  final Color _text = const Color(0xFF333333);
  final Color _secondary = const Color(0xFF757575);
  final Color _border = const Color(0xFFEEEEEE);

  final TextEditingController _searchCtrl = TextEditingController();
  // Removed All/Active quick filter; keep advanced filters below
  // Advanced filters
  DateTimeRange? _dateRange;
  final Set<TreatmentType> _typeFilters = {};
  String? _doctorIdFilter;
  // Removed appointments-related state (_selectedDay, _doctorId)

  @override
  Widget build(BuildContext context) {
    final patientProvider = context.watch<PatientProvider>();
    final doctorProvider = context.watch<DoctorProvider>();
    final allPatients = patientProvider.patients;
    final query = _searchCtrl.text.trim().toLowerCase();
    var patients = allPatients.where((p) {
      if (query.isEmpty) return true;
      final nameMatch = p.name.toLowerCase().contains(query);
      final idMatch = p.displayNumber.toString().contains(query);
      return nameMatch || idMatch;
    }).toList();
    // No All/Active toggle; rely on search and advanced filters
    // Apply advanced filters if any
    final hasAdv = _dateRange != null || _typeFilters.isNotEmpty || _doctorIdFilter != null;
    if (hasAdv) {
      final doctorName = _doctorIdFilter == null ? null : doctorProvider.byId(_doctorIdFilter!)?.name;
      bool sessionMatches(TreatmentSession s) {
        // Date filter
        if (_dateRange != null) {
          final d = s.date;
          final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
          final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);
          if (d.isBefore(start) || d.isAfter(end)) return false;
        }
        // Type filter
        if (_typeFilters.isNotEmpty && !_typeFilters.contains(s.type)) return false;
        // Doctor filter
        if (doctorName != null && doctorName.trim().isNotEmpty) {
          String? inCharge;
          switch (s.type) {
            case TreatmentType.general:
              inCharge = s.generalDoctorInCharge;
              break;
            case TreatmentType.orthodontic:
              inCharge = s.orthoDoctorInCharge;
              break;
            case TreatmentType.rootCanal:
              inCharge = s.rootCanalDoctorInCharge;
              break;
            case TreatmentType.prosthodontic:
              inCharge = s.prosthodonticDoctorInCharge;
              break;
            default:
              inCharge = null;
          }
          if (inCharge == null || inCharge.trim() != doctorName) return false;
        }
        return true;
      }
      patients = patients.where((p) => p.sessions.any(sessionMatches)).toList();
    }

    return LayoutBuilder(builder: (context, c) {
      final stacked = widget.embedded || c.maxWidth < 700;
      final searchDecoration = InputDecoration(
        hintText: 'Search patients...',
        prefixIcon: const Icon(Icons.search),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: _primary)),
      );

      // Base list used in non-embedded contexts where scrolling is desired.
      final scrollableList = patients.isEmpty
          ? const Center(child: Text('No patients'))
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 16),
              shrinkWrap: false,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: patients.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _centerListItem(_buildPatientCard(patients[i])),
            );

      // Fallback list for embedded usage where the parent provides scrolling
      // and we must avoid unbounded height errors.
      final listWidget = patients.isEmpty
          ? const Center(child: Text('No patients'))
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 16),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: patients.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _centerListItem(_buildPatientCard(patients[i])),
            );

      final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _searchCtrl, decoration: searchDecoration, onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        Row(children: [
          // Add Patient CTA (left aligned for mobile, right aligned on wide)
          FilledButton.icon(
            onPressed: () async {
              await Navigator.of(context).pushNamed(AddPatientPage.routeName);
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Add Patient'),
          ),
          const Spacer(),
          Text('${patients.length} result${patients.length == 1 ? '' : 's'}', style: TextStyle(color: _secondary)),
        ]),
        const SizedBox(height: 10),
        // Advanced filters row (responsive wrap)
        _advancedFiltersRow(doctorProvider),
        const SizedBox(height: 12),
        if (!stacked)
          Expanded(
            child: context.responsiveCenter(
              maxWidth: 1200,
              child: scrollableList,
            ),
          )
        else if (!widget.embedded)
          // On narrow screens (stacked) in standalone mode, allow vertical scroll.
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.gutter),
              child: scrollableList,
            ),
          )
        else
          // Embedded mode: parent handles scrolling; keep list non-scrollable.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.gutter),
            child: listWidget,
          ),
      ]);

      if (widget.embedded) {
        return content;
      }
      return Padding(padding: EdgeInsets.all(context.gap + 8), child: content);
    });
  }

  Widget _advancedFiltersRow(DoctorProvider doctorProvider) {
    final bool hasFilters = _dateRange != null || _typeFilters.isNotEmpty || _doctorIdFilter != null;
    String dateLabel() {
      if (_dateRange == null) return 'Date range';
      final s = _dateRange!.start;
      final e = _dateRange!.end;
      return '${s.month}/${s.day} - ${e.month}/${e.day}';
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(now.year - 3),
              lastDate: DateTime(now.year + 3),
              initialDateRange: _dateRange,
              saveText: 'Apply',
            );
            if (picked != null) setState(() => _dateRange = picked);
          },
          icon: const Icon(Icons.date_range),
          label: Text(dateLabel()),
        ),
        // Treatment type filter chips
        _typeChip('General', TreatmentType.general),
        _typeChip('Ortho', TreatmentType.orthodontic),
        _typeChip('Root Canal', TreatmentType.rootCanal),
        _typeChip('Prostho', TreatmentType.prosthodontic),
        // Doctor dropdown
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<String?>(
            value: _doctorIdFilter,
            decoration: const InputDecoration(labelText: 'Doctor'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All doctors')),
              for (final d in doctorProvider.doctors)
                DropdownMenuItem<String?>(value: d.id, child: Text(d.name)),
            ],
            onChanged: (v) => setState(() => _doctorIdFilter = v),
          ),
        ),
        if (hasFilters)
          TextButton.icon(
            onPressed: () => setState(() {
              _dateRange = null;
              _typeFilters.clear();
              _doctorIdFilter = null;
            }),
            icon: const Icon(Icons.clear),
            label: const Text('Clear filters'),
          ),
      ],
    );
  }

  Widget _typeChip(String label, TreatmentType type) {
    final selected = _typeFilters.contains(type);
    return FilterChip(
      label: Text(label, style: TextStyle(color: selected ? Colors.white : _secondary)),
      selected: selected,
      onSelected: (v) => setState(() {
        if (v) {
          _typeFilters.add(type);
        } else {
          _typeFilters.remove(type);
        }
      }),
      selectedColor: _primary,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      side: BorderSide(color: _border),
    );
  }

  /// Center each patient card and constrain its max width on wide screens so
  /// the list doesn't feel overly stretched on desktop.
  Widget _centerListItem(Widget child) {
    final w = MediaQuery.of(context).size.width;
    // Pick a comfortable max width for cards depending on viewport.
    double maxW;
    if (w >= 1600) {
      maxW = 980;
    } else if (w >= 1200) {
      maxW = 920;
    } else if (w >= 900) {
      maxW = 820;
    } else if (w >= 700) {
      maxW = 640;
    } else {
      maxW = double.infinity; // mobile: full width
    }
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: child,
      ),
    );
  }

  Widget _buildPatientCard(Patient p) {
    final active = p.sessions.isNotEmpty;
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).pushNamed(PatientDetailPage.routeName, arguments: {'patientId': p.id}),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: LayoutBuilder(builder: (ctx, cons) {
            const double avatarSize = 40.0;
            final bool narrow = cons.maxWidth < 380; // very small phones
            final nameStyle = TextStyle(
              fontWeight: FontWeight.w700,
              color: _text,
              fontSize: narrow ? 13 : 14,
            );
            final metaStyle = TextStyle(
              color: _secondary,
              fontSize: narrow ? 12 : 13,
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: avatar, name (expanded), actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: avatarSize,
                      height: avatarSize,
                      child: CircleAvatar(
                        backgroundColor: _primary.withOpacity(0.12),
                        child: Icon(Icons.person, color: _secondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        p.name,
                        style: nameStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                    // Trailing actions (fixed-size icons)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'WhatsApp',
                  iconSize: 22,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: (p.phone.trim().isEmpty) ? null : () => _openWhatsApp(p.phone),
                  icon: SvgPicture.asset('assets/images/whatsapp.svg', width: 22, height: 22),
                ),
                IconButton(
                  tooltip: 'Call',
                  iconSize: 22,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: (p.phone.trim().isEmpty) ? null : () => _callPhone(p.phone),
                  icon: const Icon(Icons.phone, color: Color(0xFF20C4C4)),
                ),
                const SizedBox(width: 6),
                Container(width: 10, height: 10, decoration: BoxDecoration(color: active ? Colors.green : Colors.grey, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: Icon(Icons.more_vert, color: _secondary),
                  onSelected: (v) async {
                    if (v == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Patient?'),
                          content: Text('This will permanently delete "${p.name}" and all related sessions. This action cannot be undone.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await context.read<PatientProvider>().deletePatient(p.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted ${p.name}')));
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete Patient')),
                  ],
                ),
                    ]),
                  ],
                ),
                const SizedBox(height: 4),
                // Second line: MRN aligned under the text (indent to avatar + gap)
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: Row(
                    children: [
                      SizedBox(width: avatarSize + 12),
                      Expanded(
                        child: Text(
                          'MRN: ${p.displayNumber.toString().padLeft(4, '0')}',
                          style: metaStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // Communication helpers
  Future<void> _callPhone(String? phone) async {
    try {
      if (phone == null || phone.trim().isEmpty) return;
      final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      final uri = Uri(scheme: 'tel', path: digits);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Call not supported on this device')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Call failed: $e')));
    }
  }

  Future<void> _openWhatsApp(String? phone) async {
    try {
      if (phone == null || phone.trim().isEmpty) return;
      final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final waUriNative = Uri.parse('whatsapp://send?phone=$digits');
      final waUriWeb = Uri.parse('https://wa.me/$digits');
      if (await canLaunchUrl(waUriNative)) {
        await launchUrl(waUriNative);
      } else if (await canLaunchUrl(waUriWeb)) {
        await launchUrl(waUriWeb, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp not available')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('WhatsApp open failed: $e')));
    }
  }

}
