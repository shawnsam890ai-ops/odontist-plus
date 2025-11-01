import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'dart:convert';
import '../../providers/doctor_provider.dart';
import '../../providers/doctor_attendance_provider.dart';
import '../../models/doctor.dart';
import '../../models/payment_rule.dart';
import '../../models/procedures.dart';
import '../../models/payment_entry.dart';
import '../../models/treatment_session.dart' show TreatmentSession, ToothTreatmentDoneEntry;
import '../../models/patient.dart';
import '../../providers/patient_provider.dart';
import '../../core/upi_launcher.dart' as upi;
import '../widgets/staff_attendance_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/staff_attendance_provider.dart';

class DoctorsPaymentsSection extends StatefulWidget {
  const DoctorsPaymentsSection({super.key});

  @override
  State<DoctorsPaymentsSection> createState() => _DoctorsPaymentsSectionState();
}

class _DoctorsPaymentsSectionState extends State<DoctorsPaymentsSection> {
  String? _selectedDoctorId;
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorProvider>();
    final doctors = provider.doctors;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header simplified: only Add Doctor button (title and attendance toggle removed)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _showAddDoctorDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Doctor'),
              ),
            ),
            const SizedBox(height: 16),
            if (doctors.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No doctors added yet')))
            else
              Builder(builder: (context) {
                final total = doctors.length;
                List<Doctor> visible = doctors;
                int pageCount = 1;
                if (total > 3) {
                  pageCount = (total / 3).ceil();
                  if (_pageIndex >= pageCount) _pageIndex = 0;
                  final start = _pageIndex * 3;
                  final end = (start + 3) > total ? total : (start + 3);
                  visible = doctors.sublist(start, end);
                }
                return Column(
                  children: [
                    _DoctorsPortraitsGrid(
                      doctors: visible,
                      selectedDoctorId: _selectedDoctorId,
                      onDoctorSelected: (doctorId) {
                        setState(() { _selectedDoctorId = _selectedDoctorId == doctorId ? null : doctorId; });
                      },
                      onViewDoctor: (doc) => _showDoctorProfileDialog(context, doc),
                    ),
                    if (total > 3) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Previous',
                            onPressed: () => setState(() { _pageIndex = (_pageIndex - 1 + pageCount) % pageCount; }),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('Page ${_pageIndex + 1} / $pageCount'),
                          IconButton(
                            tooltip: 'Next',
                            onPressed: () => setState(() { _pageIndex = (_pageIndex + 1) % pageCount; }),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              }),
            if (_selectedDoctorId != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _DoctorDetailsView(doctorId: _selectedDoctorId!),
              ),
            const SizedBox(height: 16),
            // Global Quick Allocation Calculator moved to bottom
            _GlobalAllocationQuickCalc(),
          ]),
        ),
      ),
    );
  }

  void _showAddDoctorDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    DoctorRole role = DoctorRole.endodontist;
    DoctorSex sex = DoctorSex.male;
    EmploymentType employmentType = EmploymentType.consultant;
    final ageCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final regNoCtrl = TextEditingController();
    final regStateCtrl = TextEditingController();
    DateTime? dob;
    String? photoPath;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Doctor'),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            StatefulBuilder(builder: (context, setSt) {
              return DropdownButtonFormField<DoctorRole>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role in clinic'),
                items: DoctorRole.values
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.label())))
                    .toList(),
                onChanged: (v) => setSt(() => role = v ?? role),
              );
            }),
            const SizedBox(height: 8),
            StatefulBuilder(builder: (context, setSt) {
              return DropdownButtonFormField<DoctorSex>(
                value: sex,
                decoration: const InputDecoration(labelText: 'Sex'),
                items: DoctorSex.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.label())))
                    .toList(),
                onChanged: (v) => setSt(() => sex = v ?? sex),
              );
            }),
            const SizedBox(height: 8),
            StatefulBuilder(builder: (context, setSt) {
              return DropdownButtonFormField<EmploymentType>(
                value: employmentType,
                decoration: const InputDecoration(labelText: 'Employment type'),
                items: EmploymentType.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.label())))
                    .toList(),
                onChanged: (v) => setSt(() => employmentType = v ?? employmentType),
              );
            }),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: ageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age (optional)'))),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(context: context, initialDate: dob ?? DateTime(now.year - 25, now.month, now.day), firstDate: DateTime(1900), lastDate: now);
                  if (picked != null) {
                    dob = picked;
                    (context as Element).markNeedsBuild();
                  }
                },
                child: Text('DOB: ' + (dob == null ? 'Select' : '${dob!.year}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}')),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
            const SizedBox(height: 8),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: regNoCtrl, decoration: const InputDecoration(labelText: 'Registration number'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: regStateCtrl, decoration: const InputDecoration(labelText: 'Registered state'))),
            ]),
            const SizedBox(height: 12),
            StatefulBuilder(builder: (context, setSt) {
              return Row(children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: kIsWeb);
                    if (res != null) {
                      final f = res.files.single;
                      if (kIsWeb && f.bytes != null) {
                        final ext = (f.extension ?? '').toLowerCase();
                        final mime = (ext == 'jpg' || ext == 'jpeg')
                          ? 'image/jpeg'
                          : (ext == 'gif')
                            ? 'image/gif'
                            : (ext == 'bmp')
                              ? 'image/bmp'
                              : (ext == 'webp')
                                ? 'image/webp'
                                : 'image/png';
                        final dataUrl = 'data:$mime;base64,${base64Encode(f.bytes!)}';
                        setSt(() => photoPath = dataUrl);
                      } else if (f.path != null) {
                        setSt(() => photoPath = f.path);
                      }
                    }
                  },
                  icon: const Icon(Icons.photo),
                  label: const Text('Choose Photo'),
                ),
                const SizedBox(width: 8),
                if (photoPath != null)
                  Expanded(
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: (photoPath!.startsWith('data:')
                            ? Image.network(photoPath!, width: 32, height: 32, fit: BoxFit.cover)
                            : Image.file(File(photoPath!), width: 32, height: 32, fit: BoxFit.cover)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(File(photoPath!).path.split(Platform.pathSeparator).last, overflow: TextOverflow.ellipsis)),
                      IconButton(
                        tooltip: 'Clear',
                        onPressed: () => setSt(() => photoPath = null),
                        icon: const Icon(Icons.clear, size: 18),
                      )
                    ]),
                  ),
              ]);
            }),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final id = DateTime.now().microsecondsSinceEpoch.toString();
              context.read<DoctorProvider>().addDoctor(Doctor(
                id: id,
                name: name,
                role: role,
                photoPath: photoPath,
                sex: sex,
                employmentType: employmentType,
                age: int.tryParse(ageCtrl.text),
                dob: dob,
                phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                registrationNumber: regNoCtrl.text.trim().isEmpty ? null : regNoCtrl.text.trim(),
                registeredState: regStateCtrl.text.trim().isEmpty ? null : regStateCtrl.text.trim(),
              ));
              Navigator.pop(context);
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  // Opens a compact dialog with Doctor Profile + Payment Rules
  void _showDoctorProfileDialog(BuildContext context, Doctor doctor) {
    final rules = doctor.rules;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Doctor Profile — ${doctor.name}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DoctorProfileBlock(doctor: doctor),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Payment Rules', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (rules.isEmpty)
                  const Text('No rules set')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in rules.entries)
                        _RuleChip(doctorId: doctor.id, procedureKey: e.key, rule: e.value),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  // Role labels are provided by DoctorRole.label() extension in the model.
}

class _DoctorsPortraitsGrid extends StatelessWidget {
  final List<Doctor> doctors;
  final String? selectedDoctorId;
  final Function(String) onDoctorSelected;
  final Function(Doctor)? onViewDoctor;

  const _DoctorsPortraitsGrid({
    required this.doctors,
    required this.selectedDoctorId,
    required this.onDoctorSelected,
    this.onViewDoctor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Larger boxes; compute columns accordingly
          final itemWidth = 280.0; // bigger card width
          final columns = (constraints.maxWidth / itemWidth).floor().clamp(1, 5);
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: doctors
                .map(
                  (doctor) => _DoctorPortraitBox(
                    doctor: doctor,
                    isSelected: selectedDoctorId == doctor.id,
                    onTap: () => onDoctorSelected(doctor.id),
                    onView: onViewDoctor == null ? null : () => onViewDoctor!(doctor),
                    width: (constraints.maxWidth - (columns - 1) * 16) / columns,
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _DoctorPortraitBox extends StatelessWidget {
  final Doctor doctor;
  final bool isSelected;
  final VoidCallback onTap;
  final double width;
  final VoidCallback? onView;

  const _DoctorPortraitBox({
    required this.doctor,
    required this.isSelected,
    required this.onTap,
    required this.width,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = width.clamp(240.0, 320.0);
    final h = 360.0; // taller portrait box
    final Color sexTint = () {
      switch (doctor.sex) {
        case DoctorSex.female:
          return Colors.pinkAccent.withOpacity(0.10);
        case DoctorSex.other:
          return Colors.teal.withOpacity(0.10);
        case DoctorSex.male:
        default:
          return Colors.blueAccent.withOpacity(0.10);
      }
    }();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.35 : 0.25),
              blurRadius: isSelected ? 16 : 10,
              offset: Offset(0, isSelected ? 8 : 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full background image
              _buildBackgroundImage(),
              // Subtle dark overlay for text readability
              Container(color: Colors.black.withOpacity(isSelected ? 0.25 : 0.15)),
              Container(color: sexTint),
              // Top-right view button
              if (onView != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onView,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.visibility, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              // Bottom gradient for stronger text contrast
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.55),
                      ],
                    ),
                  ),
                ),
              ),
              // Text overlay
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doctor.role.label(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Selection border
              if (isSelected)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: true,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.primary, width: 3),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundImage() {
    if (doctor.photoPath != null && doctor.photoPath!.isNotEmpty) {
      final p = doctor.photoPath!;
      if (p.startsWith('data:')) {
        return Image.network(p, fit: BoxFit.cover, errorBuilder: (c, e, s) => _defaultBackgroundImage());
      }
      return Image.file(
        File(p),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _defaultBackgroundImage(),
      );
    }
    return _defaultBackgroundImage();
  }

  Widget _defaultBackgroundImage() {
    // Sex-based default images
    String asset;
    switch (doctor.sex) {
      case DoctorSex.female:
        asset = 'assets/images/doctor_female.jpg';
        break;
      case DoctorSex.male:
        asset = 'assets/images/doctor_male.jpg';
        break;
      case DoctorSex.other:
      default:
        asset = 'assets/images/doctor_avatar.png';
    }
    return Image.asset(asset, fit: BoxFit.cover);
  }
}

class _DoctorProfileBlock extends StatelessWidget {
  final Doctor doctor;
  const _DoctorProfileBlock({required this.doctor});

  @override
  Widget build(BuildContext context) {
    String? dobStr = doctor.dob == null ? null : '${doctor.dob!.year}-${doctor.dob!.month.toString().padLeft(2, '0')}-${doctor.dob!.day.toString().padLeft(2, '0')}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Profile', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 24, runSpacing: 8, children: [
        _miniKv('Sex', doctor.sex.label()),
        if (doctor.age != null) _miniKv('Age', doctor.age.toString()),
        if (dobStr != null) _miniKv('DOB', dobStr),
        _miniKv('Employment', doctor.employmentType.label()),
        if (doctor.phone != null && doctor.phone!.isNotEmpty) _miniKv('Phone', doctor.phone!),
        if (doctor.registrationNumber != null && doctor.registrationNumber!.isNotEmpty) _miniKv('Reg No.', doctor.registrationNumber!),
        if (doctor.registeredState != null && doctor.registeredState!.isNotEmpty) _miniKv('Reg State', doctor.registeredState!),
      ]),
      if (doctor.address != null && doctor.address!.isNotEmpty) ...[
        const SizedBox(height: 8),
        _miniKv('Address', doctor.address!),
      ]
    ]);
  }

  Widget _miniKv(String k, String v) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w600)),
      Text(v),
    ]);
  }
}

class _DoctorDetailsView extends StatelessWidget {
  final String doctorId;

  const _DoctorDetailsView({required this.doctorId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorProvider>();
    final doctor = provider.byId(doctorId);
    
    if (doctor == null) return const SizedBox.shrink();

    final rules = doctor.rules;
    final summary = provider.summaryFor(doctor.id);
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with doctor info and controls
            Row(
              children: [
                if (doctor.photoPath?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _headerImage(doctor.photoPath!, doctor.sex),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${doctor.name} • ${doctor.role.label()}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Doctor: ₹${summary.doctorEarned.toStringAsFixed(0)}  •  Payouts: ₹${summary.payouts.toStringAsFixed(0)}  •  Outstanding: ₹${summary.outstanding.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: doctor.active,
                      onChanged: (v) => provider.updateDoctor(doctor.id, active: v),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditDoctorDialog(context, doctor),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete doctor?'),
                            content: Text('Are you sure you want to remove ${doctor.name}? This action cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        // Ask for email + password to re-verify identity before deletion
                        final emailCtrl = TextEditingController();
                        final passCtrl = TextEditingController();
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Verify your identity'),
                            content: SizedBox(
                              width: 420,
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')), 
                                const SizedBox(height: 8),
                                TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                              ]),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Verify')),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        try {
                          // Reauthenticate current user with provided email/password
                          // Only proceeds if reauth succeeds
                          final auth = FirebaseAuth.instance;
                          final user = auth.currentUser;
                          final email = emailCtrl.text.trim();
                          final pass = passCtrl.text;
                          if (user != null) {
                            final cred = EmailAuthProvider.credential(email: email, password: pass);
                            await user.reauthenticateWithCredential(cred);
                            provider.removeDoctor(doctor.id);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Verification failed. Could not delete doctor.')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // Payment Rules section (Profile moved to View dialog only)
            Row(
              children: [
                const Text('Payment Rules', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAddRuleDialog(context, doctor.id),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Rule'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (rules.isEmpty)
              const Text('No rules set')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in rules.entries) 
                    _RuleChip(doctorId: doctor.id, procedureKey: e.key, rule: e.value)
                ],
              ),
            // (Quick Allocation Calculator moved to global section)
            // Record Payment button
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => _showRecordPaymentDialog(context, doctor.id),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Record Payment'),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // For consultants: show ledger first. For permanent staff: show attendance first then ledger.
            if (doctor.employmentType == EmploymentType.consultant) ...[
              _DoctorOwnLedger(doctorId: doctor.id),
            ] else ...[
              const Text('Attendance', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(height: 380, child: StaffAttendanceWidget(showHeader: true, selectedStaff: doctor.name, showMonthToggle: true)),
              const SizedBox(height: 8),
              // Quick mark controls (present/absent/half-day) similar to staff dashboard
              _DoctorAttendanceQuickActions(doctorName: doctor.name),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              _DoctorOwnLedger(doctorId: doctor.id),
            ],
          ],
        ),
      ),
    );
  }

  Widget _headerImage(String path, DoctorSex sex) {
    String fallback;
    switch (sex) {
      case DoctorSex.female:
        fallback = 'assets/images/doctor_female.jpg';
        break;
      case DoctorSex.male:
        fallback = 'assets/images/doctor_male.jpg';
        break;
      case DoctorSex.other:
      default:
        fallback = 'assets/images/doctor_avatar.png';
    }
    if (path.startsWith('data:')) {
      return Image.network(
        path,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Image.asset(fallback, width: 40, height: 40, fit: BoxFit.cover),
      );
    }
    return Image.file(
      File(path),
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        fallback,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
      ),
    );
  }

  void _showEditDoctorDialog(BuildContext context, Doctor d) {
    final nameCtrl = TextEditingController(text: d.name);
    DoctorRole role = d.role;
    DoctorSex sex = d.sex;
    EmploymentType employmentType = d.employmentType;
    final ageCtrl = TextEditingController(text: d.age?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: d.phone ?? '');
    final addressCtrl = TextEditingController(text: d.address ?? '');
    final regNoCtrl = TextEditingController(text: d.registrationNumber ?? '');
    final regStateCtrl = TextEditingController(text: d.registeredState ?? '');
    DateTime? dob = d.dob;
    String? photoPath = d.photoPath;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Doctor'),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            StatefulBuilder(builder: (context, setSt) {
              return DropdownButtonFormField<DoctorRole>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role in clinic'),
                items: DoctorRole.values
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.label())))
                    .toList(),
                onChanged: (v) => setSt(() => role = v ?? role),
              );
            }),
            const SizedBox(height: 8),
            StatefulBuilder(builder: (context, setSt) {
              return DropdownButtonFormField<DoctorSex>(
                value: sex,
                decoration: const InputDecoration(labelText: 'Sex'),
                items: DoctorSex.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.label())))
                    .toList(),
                onChanged: (v) => setSt(() => sex = v ?? sex),
              );
            }),
            const SizedBox(height: 8),
            StatefulBuilder(builder: (context, setSt) {
              return DropdownButtonFormField<EmploymentType>(
                value: employmentType,
                decoration: const InputDecoration(labelText: 'Employment type'),
                items: EmploymentType.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.label())))
                    .toList(),
                onChanged: (v) => setSt(() => employmentType = v ?? employmentType),
              );
            }),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: ageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age (optional)'))),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(context: context, initialDate: dob ?? DateTime(now.year - 25, now.month, now.day), firstDate: DateTime(1900), lastDate: now);
                  if (picked != null) {
                    dob = picked;
                    (context as Element).markNeedsBuild();
                  }
                },
                child: Text('DOB: ' + (dob == null ? 'Select' : '${dob!.year}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}')),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
            const SizedBox(height: 8),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: regNoCtrl, decoration: const InputDecoration(labelText: 'Registration number'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: regStateCtrl, decoration: const InputDecoration(labelText: 'Registered state'))),
            ]),
            const SizedBox(height: 12),
            StatefulBuilder(builder: (context, setSt) {
              return Row(children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: kIsWeb);
                    if (res != null) {
                      final f = res.files.single;
                      if (kIsWeb && f.bytes != null) {
                        final ext = (f.extension ?? '').toLowerCase();
                        final mime = (ext == 'jpg' || ext == 'jpeg')
                          ? 'image/jpeg'
                          : (ext == 'gif')
                            ? 'image/gif'
                            : (ext == 'bmp')
                              ? 'image/bmp'
                              : (ext == 'webp')
                                ? 'image/webp'
                                : 'image/png';
                        final dataUrl = 'data:$mime;base64,${base64Encode(f.bytes!)}';
                        setSt(() => photoPath = dataUrl);
                      } else if (f.path != null) {
                        setSt(() => photoPath = f.path);
                      }
                    }
                  },
                  icon: const Icon(Icons.photo),
                  label: const Text('Choose Photo'),
                ),
                const SizedBox(width: 8),
                if (photoPath != null)
                  Expanded(
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: (photoPath!.startsWith('data:')
                            ? Image.network(photoPath!, width: 32, height: 32, fit: BoxFit.cover)
                            : Image.file(File(photoPath!), width: 32, height: 32, fit: BoxFit.cover)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(File(photoPath!).path.split(Platform.pathSeparator).last, overflow: TextOverflow.ellipsis)),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () => setSt(() => photoPath = ''),
                        icon: const Icon(Icons.clear, size: 18),
                      )
                    ]),
                  ),
              ]);
            }),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              context.read<DoctorProvider>().updateDoctor(
                d.id,
                name: name,
                role: role,
                photoPath: photoPath,
                sex: sex,
                employmentType: employmentType,
                age: int.tryParse(ageCtrl.text),
                dob: dob,
                phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                registrationNumber: regNoCtrl.text.trim().isEmpty ? null : regNoCtrl.text.trim(),
                registeredState: regStateCtrl.text.trim().isEmpty ? null : regStateCtrl.text.trim(),
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  void _showAddRuleDialog(BuildContext context, String doctorId) {
    final procCtrl = ValueNotifier<String>(Procedures.rct);
    final modeCtrl = ValueNotifier<PaymentMode>(PaymentMode.fixed);
    final valueCtrl = TextEditingController(text: '0');
    final priceCtrl = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Payment Rule'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: procCtrl.value,
              decoration: const InputDecoration(labelText: 'Procedure'),
              items: const [
                DropdownMenuItem(value: Procedures.rct, child: Text('Root Canal (RCT)')),
                DropdownMenuItem(value: Procedures.ortho, child: Text('Orthodontic (Ortho)')),
                DropdownMenuItem(value: Procedures.prostho, child: Text('Prosthodontic')),
                DropdownMenuItem(value: Procedures.perio, child: Text('Periodontic')),
                DropdownMenuItem(value: Procedures.pedo, child: Text('Pedodontic')),
                DropdownMenuItem(value: Procedures.oms, child: Text('Oral & Maxillofacial Surgery')),
              ],
              onChanged: (v) => procCtrl.value = v ?? Procedures.rct,
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<PaymentMode>(
              valueListenable: modeCtrl,
              builder: (context, mode, _) => DropdownButtonFormField<PaymentMode>(
                value: mode,
                decoration: const InputDecoration(labelText: 'Doctor Share Type'),
                items: const [
                  DropdownMenuItem(value: PaymentMode.fixed, child: Text('Fixed amount')),
                  DropdownMenuItem(value: PaymentMode.percent, child: Text('Percent')),
                ],
                onChanged: (m) => modeCtrl.value = m ?? PaymentMode.fixed,
              ),
            ),
            const SizedBox(height: 8),
            TextField(controller: valueCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Doctor share (amount or %)')),
            const SizedBox(height: 8),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Clinic price (optional)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final key = procCtrl.value;
              final mode = modeCtrl.value;
              final val = double.tryParse(valueCtrl.text) ?? 0;
              final price = double.tryParse(priceCtrl.text);
              final rule = mode == PaymentMode.fixed ? PaymentRule.fixed(val, clinicPrice: price) : PaymentRule.percent(val, clinicPrice: price);
              context.read<DoctorProvider>().setRule(doctorId, key, rule);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  void _showDoctorProfileDialog(BuildContext context, Doctor doctor) {
    final rules = doctor.rules;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Doctor Profile — ${doctor.name}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              _DoctorProfileBlock(doctor: doctor),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Payment Rules', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (rules.isEmpty) const Text('No rules set') else Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in rules.entries) _RuleChip(doctorId: doctor.id, procedureKey: e.key, rule: e.value),
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _DoctorOwnLedger extends StatelessWidget {
  final String doctorId;
  const _DoctorOwnLedger({required this.doctorId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorProvider>();
    final entries = provider.filteredLedger(doctorId: doctorId).reversed.toList();
    // Totals for this doctor view (exclude payouts for clinic/doctor split sums)
    double docTotal = 0, clinicTotal = 0;
    for (final e in entries) {
      if (e.type == EntryType.payment) {
        docTotal += e.doctorShare;
        clinicTotal += e.clinicShare;
      }
    }
    final doctorName = provider.byId(doctorId)?.name ?? 'Doctor';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, cons) {
          final narrow = cons.maxWidth < 520;
          if (narrow) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Payments Ledger — $doctorName', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: () => _showMakePayoutDialogForDoctor(context, doctorId),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Make Payment'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportLedgerPdf(context, entries),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Export PDF'),
                ),
              ]),
            ]);
          }
          return Row(children: [
            Text('Payments Ledger — $doctorName', style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Row(children: [
              OutlinedButton.icon(
                onPressed: () => _showMakePayoutDialogForDoctor(context, doctorId),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Make Payment'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _exportLedgerPdf(context, entries),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export PDF'),
              ),
            ]),
          ]);
        }),
        const SizedBox(height: 8),
        Text('Totals — Doctor: ₹${docTotal.toStringAsFixed(0)}    Clinic: ₹${clinicTotal.toStringAsFixed(0)}'),
        const SizedBox(height: 8),
        const Divider(height: 1),
        if (entries.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No payments recorded yet'))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = entries[i];
              final dateStr = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
              final isPayout = e.type == EntryType.payout;
              final friendly = _prettyLedgerSubtitle(context, e, dateStr);
              return ListTile(
                title: Text('${doctorName} • ${isPayout ? 'PAYOUT' : e.procedureKey.toUpperCase()} • ${isPayout ? '₹${e.doctorShare.toStringAsFixed(0)}' : '₹${e.amountReceived.toStringAsFixed(0)}'}'),
                subtitle: Text(friendly),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'View details',
                    icon: const Icon(Icons.visibility_outlined),
                    onPressed: () => _showLedgerEntryDetails(context, e),
                  ),
                  IconButton(
                    tooltip: 'Delete entry',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete entry?'),
                          content: const Text('This will permanently remove the ledger entry.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        context.read<DoctorProvider>().deleteLedgerEntry(e.id);
                      }
                    },
                  ),
                ]),
              );
            },
          ),
      ],
    );
  }
}

void _showMakePayoutDialogForDoctor(BuildContext context, String doctorId) {
  final provider = context.read<DoctorProvider>();
  final amountCtrl = TextEditingController(text: '0');
  final noteCtrl = TextEditingController();
  final modeCtrl = ValueNotifier<String>('Cash');
  DateTime date = DateTime.now();
  final doctorName = provider.byId(doctorId)?.name ?? 'Doctor';
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Make Payment to $doctorName'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: modeCtrl.value,
            decoration: const InputDecoration(labelText: 'Mode of transaction'),
            items: const [
              DropdownMenuItem(value: 'Cash', child: Text('Cash')),
              DropdownMenuItem(value: 'UPI', child: Text('UPI')),
              DropdownMenuItem(value: 'Card', child: Text('Card')),
              DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
            ],
            onChanged: (v) => modeCtrl.value = v ?? 'Cash',
          ),
          const SizedBox(height: 8),
          TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Date:'),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 1));
                if (picked != null) {
                  date = picked;
                }
              },
              child: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
            ),
          ])
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        // Show Pay via UPI when selected
        ValueListenableBuilder<String>(
          valueListenable: modeCtrl,
          builder: (ctx, mode, _) {
            if (mode != 'UPI') return const SizedBox.shrink();
            return TextButton.icon(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Pay via UPI'),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0;
                final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                final extra = noteCtrl.text.trim();
                final note = 'Doctor payout — $doctorName — $dateStr' + (extra.isEmpty ? '' : ' — $extra');
                await upi.launchUPIPayment(
                  context: context,
                  amount: amt > 0 ? amt : null,
                  note: note,
                );
              },
            );
          },
        ),
        ElevatedButton(
          onPressed: () async {
            final amt = double.tryParse(amountCtrl.text) ?? 0;
            if (amt <= 0) return;
            // For UPI, ask if the payment completed to keep ledger consistent.
            if (modeCtrl.value == 'UPI') {
              final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final completed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('UPI Payment Completed?'),
                  content: Text('Did the UPI payment of ₹${amt.toStringAsFixed(0)} to $doctorName on $dateStr complete successfully?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Completed')),
                  ],
                ),
              );
              if (completed != true) return; // Don't record unless confirmed completed
            } else {
              // Non-UPI modes: regular confirmation
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Confirm Payment'),
                  content: Text('Pay ₹${amt.toStringAsFixed(0)} to $doctorName?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
                  ],
                ),
              );
              if (confirm != true) return;
            }
            provider.recordPayoutWithMode(
              doctorId: doctorId,
              amount: amt,
              date: date,
              note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              mode: modeCtrl.value,
            );
            Navigator.pop(context);
          },
          child: const Text('Done'),
        )
      ],
    ),
  );
}



void _showRecordPaymentDialog(BuildContext context, String doctorId) {
  final proc = ValueNotifier<String>(Procedures.rct);
  final amountCtrl = TextEditingController(text: '0');
  final patientCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  DateTime date = DateTime.now();
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Record Payment'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: proc.value,
            decoration: const InputDecoration(labelText: 'Procedure'),
            items: const [
              DropdownMenuItem(value: Procedures.rct, child: Text('Root Canal (RCT)')),
              DropdownMenuItem(value: Procedures.ortho, child: Text('Orthodontic (Ortho)')),
              DropdownMenuItem(value: Procedures.prostho, child: Text('Prosthodontic')),
              DropdownMenuItem(value: Procedures.perio, child: Text('Periodontic')),
              DropdownMenuItem(value: Procedures.pedo, child: Text('Pedodontic')),
              DropdownMenuItem(value: Procedures.oms, child: Text('OMS')),
            ],
            onChanged: (v) => proc.value = v ?? Procedures.rct,
          ),
          const SizedBox(height: 8),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount received (this visit)')),
          const SizedBox(height: 8),
          TextField(controller: patientCtrl, decoration: const InputDecoration(labelText: 'Patient (optional)')),
          const SizedBox(height: 8),
          TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Date:'),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 1));
                if (picked != null) {
                  date = picked;
                }
              },
              child: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
            ),
          ])
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final amt = double.tryParse(amountCtrl.text) ?? 0;
            final attendance = context.read<DoctorAttendanceProvider>();
            final provider = context.read<DoctorProvider>();
            final err = provider.recordPayment(
              doctorId: doctorId,
              procedureKey: proc.value,
              amountReceived: amt,
              date: date,
              patient: patientCtrl.text.trim().isEmpty ? null : patientCtrl.text.trim(),
              note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              attendance: attendance,
            );
            if (err != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              return;
            }
            Navigator.pop(context);
          },
          child: const Text('Save'),
        )
      ],
    ),
  );
}

// Helper functions used by doctor-specific ledger and dialogs -----------------

// Hide raw rx: tags and show patient/purpose more nicely, similar to revenue ledger behavior.
String _prettyLedgerSubtitle(BuildContext context, PaymentEntry e, String dateStr) {
  final base = StringBuffer();
  final isPayout = e.type == EntryType.payout;
  if (!isPayout) {
    base.write('Doctor: ₹${e.doctorShare.toStringAsFixed(0)}  |  Clinic: ₹${e.clinicShare.toStringAsFixed(0)}  •  ');
  }
  base.write(dateStr);
  if (e.mode != null) base.write('  •  ${e.mode}');
  // If note contains rx:<sessionId>:... convert to readable label using existing revenue logic pattern
  if (e.note != null && e.note!.startsWith('rx:')) {
    final desc = _friendlyDescriptionFromRx(context, e);
    if (desc != null) base.write('  •  $desc');
  } else if (e.patient != null) {
    base.write('  •  ${e.patient}');
  } else if (e.note != null) {
    base.write('  •  ${e.note}');
  }
  return base.toString();
}

String? _friendlyDescriptionFromRx(BuildContext context, PaymentEntry e) {
  // We only have patient name in PaymentEntry, not patientId/session graph here.
  // Prefer showing patient name if available; otherwise hide the opaque rx tag.
  if (e.patient != null && e.patient!.isNotEmpty) return e.patient;
  return null;
}

Future<void> _exportLedgerPdf(BuildContext context, List<PaymentEntry> entries) async {
  final patientProvider = context.read<PatientProvider>();
  final doctorProvider = context.read<DoctorProvider>();

  String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<List<String>> rows = [];
  for (final e in entries) {
    // Resolve doctor
    final doctorName = doctorProvider.byId(e.doctorId)?.name ?? '—';

    // Resolve patient + session (rx tag in note) similar to dialog
    String? sessionId;
    if (e.note != null && e.note!.startsWith('rx:')) {
      final rest = e.note!.substring(3);
      final parts = rest.split(':');
      if (parts.isNotEmpty) sessionId = parts.first;
    }
    Patient? patient;
    TreatmentSession? session;
    if (sessionId != null) {
      for (final p in patientProvider.patients) {
        TreatmentSession? match;
        for (final s in p.sessions) {
          if (s.id == sessionId) { match = s; break; }
        }
        if (match != null) { patient = p; session = match; break; }
      }
    }
    if (patient == null && e.patient != null) {
      final nameLower = e.patient!.toLowerCase();
      for (final p in patientProvider.patients) {
        if (p.name.toLowerCase() == nameLower) { patient = p; break; }
      }
    }

    final pid = patient?.displayNumber.toString() ?? '—';
    final pname = patient?.name ?? (e.patient ?? '—');
    final date = fmt(session?.date ?? e.date);
    final done = (session != null && session!.treatmentsDone.isNotEmpty) ? _doneSummary(session!.treatmentsDone) : '—';
    final doctor = doctorName;
    final payout = e.type == EntryType.payout ? 'Rs ${e.doctorShare.toStringAsFixed(0)}' : '';

    rows.add([pid, pname, date, done, doctor, payout]);
  }

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Text('Doctors Payments Ledger', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Table.fromTextArray(
          headers: ['Patient ID', 'Patient name', 'Date of treatment', 'Treatment done', 'Doctor in charge', 'Payment made to doctor'],
          data: rows,
        ),
      ],
    ),
  );
  await Printing.layoutPdf(onLayout: (format) async => doc.save());
}

void _showLedgerEntryDetails(BuildContext context, PaymentEntry e) {
  final doctorProvider = context.read<DoctorProvider>();
  final patientProvider = context.read<PatientProvider>();
  final doctorName = doctorProvider.byId(e.doctorId)?.name ?? '—';

  // Attempt to resolve patient + session from note (rx:<sessionId>:..)
  String? sessionId;
  if (e.note != null && e.note!.startsWith('rx:')) {
    final rest = e.note!.substring(3);
    final parts = rest.split(':');
    if (parts.isNotEmpty) sessionId = parts.first;
  }
  Patient? patient;
  TreatmentSession? session;
  if (sessionId != null) {
    // brute force scan across patients to find the session id
    for (final p in patientProvider.patients) {
      TreatmentSession? match;
      for (final s in p.sessions) {
        if (s.id == sessionId) { match = s; break; }
      }
      if (match != null) { patient = p; session = match; break; }
    }
  }
  // Fallback: try match by patient name field in entry
  if (patient == null && e.patient != null) {
    final nameLower = e.patient!.toLowerCase();
    for (final p in patientProvider.patients) {
      if (p.name.toLowerCase() == nameLower) { patient = p; break; }
    }
  }

  String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final dateStr = fmt(session?.date ?? e.date);
  final patientIdStr = patient?.displayNumber.toString() ?? '—';
  final patientNameStr = patient?.name ?? (e.patient ?? '—');
  final chiefComplaintStr = (session?.chiefComplaint?.complaints.isNotEmpty == true)
      ? session!.chiefComplaint!.complaints.first
      : '—';
  final treatmentDoneStr = (session != null && session!.treatmentsDone.isNotEmpty)
      ? _doneSummary(session!.treatmentsDone)
      : '—';
  final paymentStr = '₹${(e.type == EntryType.payout ? e.doctorShare : e.amountReceived).toStringAsFixed(0)}';
  final clinicRevStr = e.type == EntryType.payment ? '₹${e.clinicShare.toStringAsFixed(0)}' : '—';
  final doctorRevStr = e.type == EntryType.payment ? '₹${e.doctorShare.toStringAsFixed(0)}' : '—';

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Ledger entry details'),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Patient ID', patientIdStr),
            _kv('Patient name', patientNameStr),
            _kv('Date of treatment', dateStr),
            _kv('Chief complaint', chiefComplaintStr),
            _kv('Treatment done', treatmentDoneStr),
            _kv('Payment done', paymentStr),
            _kv('Clinic revenue', clinicRevStr),
            _kv('Doctor revenue', doctorRevStr),
            _kv('Doctor in charge', doctorName),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    ),
  );
}

String _doneSummary(List<ToothTreatmentDoneEntry> done) {
  final items = <String>[];
  for (final d in done.take(2)) {
    final tooth = d.toothNumber.isNotEmpty ? '${d.toothNumber}: ' : '';
    items.add('$tooth${d.treatment}');
  }
  var s = items.join(', ');
  if (done.length > 2) s += ' …';
  return s.isEmpty ? '—' : s;
}

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 160, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        Expanded(child: Text(v)),
      ],
    ),
  );
}

void _showCsvDialog(BuildContext context, String csv) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Export CSV'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(child: SelectableText(csv)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    ),
  );
}

void _showMakePayoutDialog(BuildContext context) {
  final provider = context.read<DoctorProvider>();
  final allDocs = provider.doctors;
  if (allDocs.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No doctors available')));
    return;
  }
  String doctorId = allDocs.first.id;
  final amountCtrl = TextEditingController(text: '0');
  final noteCtrl = TextEditingController();
  final modeCtrl = ValueNotifier<String>('Cash');
  DateTime date = DateTime.now();
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Make Payment to Doctor'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: doctorId,
            decoration: const InputDecoration(labelText: 'Doctor'),
            items: [for (final d in allDocs) DropdownMenuItem(value: d.id, child: Text(d.name))],
            onChanged: (v) => doctorId = v ?? doctorId,
          ),
          const SizedBox(height: 8),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: modeCtrl.value,
            decoration: const InputDecoration(labelText: 'Mode of transaction'),
            items: const [
              DropdownMenuItem(value: 'Cash', child: Text('Cash')),
              DropdownMenuItem(value: 'UPI', child: Text('UPI')),
              DropdownMenuItem(value: 'Card', child: Text('Card')),
              DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
            ],
            onChanged: (v) => modeCtrl.value = v ?? 'Cash',
          ),
          const SizedBox(height: 8),
          TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Date:'),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 1));
                if (picked != null) {
                  date = picked;
                }
              },
              child: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
            ),
          ])
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        // Show Pay via UPI when selected
        ValueListenableBuilder<String>(
          valueListenable: modeCtrl,
          builder: (ctx, mode, _) {
            if (mode != 'UPI') return const SizedBox.shrink();
            return TextButton.icon(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Pay via UPI'),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0;
                final doctorName = provider.byId(doctorId)?.name ?? 'Doctor';
                final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                final extra = noteCtrl.text.trim();
                final note = 'Doctor payout — $doctorName — $dateStr' + (extra.isEmpty ? '' : ' — $extra');
                await upi.launchUPIPayment(
                  context: context,
                  amount: amt > 0 ? amt : null,
                  note: note,
                );
              },
            );
          },
        ),
        ElevatedButton(
          onPressed: () async {
            final amt = double.tryParse(amountCtrl.text) ?? 0;
            if (amt <= 0) return;
            // For UPI, ask if the payment completed to keep ledger consistent.
            if (modeCtrl.value == 'UPI') {
              final doctorName = provider.byId(doctorId)?.name ?? 'doctor';
              final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final completed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('UPI Payment Completed?'),
                  content: Text('Did the UPI payment of ₹${amt.toStringAsFixed(0)} to $doctorName on $dateStr complete successfully?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Completed')),
                  ],
                ),
              );
              if (completed != true) return; // Don't record unless confirmed completed
            } else {
              // Non-UPI modes: regular confirmation
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Confirm Payment'),
                  content: Text('Pay ₹${amt.toStringAsFixed(0)} to ${provider.byId(doctorId)?.name ?? 'doctor'}?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
                  ],
                ),
              );
              if (confirm != true) return;
            }
            provider.recordPayoutWithMode(
              doctorId: doctorId,
              amount: amt,
              date: date,
              note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              mode: modeCtrl.value,
            );
            Navigator.pop(context);
          },
          child: const Text('Done'),
        )
      ],
    ),
  );
}

class _RuleChip extends StatelessWidget {
  final String doctorId;
  final String procedureKey;
  final PaymentRule rule;
  const _RuleChip({required this.doctorId, required this.procedureKey, required this.rule});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorProvider>();
    final label = _ruleLabel(procedureKey, rule);
    return InputChip(
      label: Text(label),
      onDeleted: () => provider.removeRule(doctorId, procedureKey),
    );
  }

  String _ruleLabel(String key, PaymentRule r) {
    String proc;
    switch (key) {
      case Procedures.rct:
        proc = 'RCT';
        break;
      case Procedures.ortho:
        proc = 'Ortho';
        break;
      case Procedures.prostho:
        proc = 'Prostho';
        break;
      case Procedures.perio:
        proc = 'Perio';
        break;
      case Procedures.pedo:
        proc = 'Pedo';
        break;
      case Procedures.oms:
        proc = 'OMS';
        break;
      default:
        proc = key;
    }
    final val = r.mode == PaymentMode.fixed ? '₹${r.value.toStringAsFixed(0)}' : '${r.value.toStringAsFixed(0)}%';
    return '$proc — $val';
  }
}

class _AllocationQuickCalc extends StatefulWidget {
  final String doctorId;
  const _AllocationQuickCalc({required this.doctorId});

  @override
  State<_AllocationQuickCalc> createState() => _AllocationQuickCalcState();
}

class _GlobalAllocationQuickCalc extends StatefulWidget {
  const _GlobalAllocationQuickCalc();

  @override
  State<_GlobalAllocationQuickCalc> createState() => _GlobalAllocationQuickCalcState();
}

class _GlobalAllocationQuickCalcState extends State<_GlobalAllocationQuickCalc> {
  String? _doctorId;
  String proc = Procedures.rct;
  final amtCtrl = TextEditingController(text: '0');

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorProvider>();
    final docs = provider.doctors;
    if (docs.isEmpty) return const SizedBox.shrink();
    _doctorId ??= docs.first.id;
    final charge = double.tryParse(amtCtrl.text) ?? 0;
    final split = provider.allocate(_doctorId!, proc, charge);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Quick Allocation Calculator', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              return Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _doctorId,
                    decoration: const InputDecoration(labelText: 'Doctor'),
                    items: [for (final d in docs) DropdownMenuItem(value: d.id, child: Text(d.name))],
                    onChanged: (v) => setState(() => _doctorId = v ?? _doctorId),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: proc,
                    decoration: const InputDecoration(labelText: 'Procedure'),
                    items: const [
                      DropdownMenuItem(value: Procedures.rct, child: Text('Root Canal (RCT)')),
                      DropdownMenuItem(value: Procedures.ortho, child: Text('Orthodontic (Ortho)')),
                      DropdownMenuItem(value: Procedures.prostho, child: Text('Prosthodontic')),
                      DropdownMenuItem(value: Procedures.perio, child: Text('Periodontic')),
                      DropdownMenuItem(value: Procedures.pedo, child: Text('Pedodontic')),
                      DropdownMenuItem(value: Procedures.oms, child: Text('OMS')),
                    ],
                    onChanged: (v) => setState(() => proc = v ?? Procedures.rct),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: amtCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Charge amount (this visit)'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Doctor: ₹${split.$1.toStringAsFixed(0)}  |  Clinic: ₹${split.$2.toStringAsFixed(0)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

class _DoctorAttendanceQuickActions extends StatelessWidget {
  final String doctorName;
  const _DoctorAttendanceQuickActions({required this.doctorName});

  @override
  Widget build(BuildContext context) {
    DateTime date = DateTime.now();
    return StatefulBuilder(builder: (context, setSt) {
      String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final att = context.read<StaffAttendanceProvider?>();
      return Row(children: [
        OutlinedButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 1));
            if (picked != null) setSt(() => date = picked);
          },
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text('Mark for ${fmt(date)}'),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: att == null ? null : () => att.setSplit(doctorName, date, morning: true, evening: true),
          child: const Text('Present'),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: att == null ? null : () => att.setSplit(doctorName, date, morning: false, evening: false),
          child: const Text('Absent'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: att == null ? null : () => att.setSplit(doctorName, date, morning: true, evening: false),
          child: const Text('Half AM'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: att == null ? null : () => att.setSplit(doctorName, date, morning: false, evening: true),
          child: const Text('Half PM'),
        ),
      ]);
    });
  }
}

class _AllocationQuickCalcState extends State<_AllocationQuickCalc> {
  String proc = Procedures.rct;
  final amtCtrl = TextEditingController(text: '0');

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorProvider>();
    final charge = double.tryParse(amtCtrl.text) ?? 0;
    final split = provider.allocate(widget.doctorId, proc, charge);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Quick Allocation Calculator', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              return Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: proc,
                    decoration: const InputDecoration(labelText: 'Procedure'),
                    items: const [
                      DropdownMenuItem(value: Procedures.rct, child: Text('Root Canal (RCT)')),
                      DropdownMenuItem(value: Procedures.ortho, child: Text('Orthodontic (Ortho)')),
                      DropdownMenuItem(value: Procedures.prostho, child: Text('Prosthodontic')),
                      DropdownMenuItem(value: Procedures.perio, child: Text('Periodontic')),
                      DropdownMenuItem(value: Procedures.pedo, child: Text('Pedodontic')),
                      DropdownMenuItem(value: Procedures.oms, child: Text('OMS')),
                    ],
                    onChanged: (v) => setState(() => proc = v ?? Procedures.rct),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: amtCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Charge amount (this visit)'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Doctor: ₹${split.$1.toStringAsFixed(0)}  |  Clinic: ₹${split.$2.toStringAsFixed(0)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}
