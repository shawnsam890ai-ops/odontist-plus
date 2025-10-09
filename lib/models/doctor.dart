import 'payment_rule.dart';

enum DoctorRole {
  endodontist,
  orthodontist,
  pedodontist,
  oralMaxillofacialSurgeon,
  prosthodontist,
  periodontist,
}

class Doctor {
  final String id;
  String name;
  DoctorRole role;
  // Payment rules per procedure id (e.g., 'rct', 'ortho')
  final Map<String, PaymentRule> rules;
  bool active;

  Doctor({
    required this.id,
    required this.name,
    required this.role,
    Map<String, PaymentRule>? rules,
    this.active = true,
  }) : rules = rules ?? {};
}
