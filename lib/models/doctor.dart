import 'payment_rule.dart';

enum DoctorRole {
  endodontist,
  orthodontist,
  pedodontist,
  oralMaxillofacialSurgeon,
  prosthodontist,
  periodontist,
  chiefDentalSurgeon,
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

extension DoctorRoleLabel on DoctorRole {
  String label() {
    switch (this) {
      case DoctorRole.endodontist:
        return 'Endodontist';
      case DoctorRole.orthodontist:
        return 'Orthodontist';
      case DoctorRole.pedodontist:
        return 'Pedodontist';
      case DoctorRole.oralMaxillofacialSurgeon:
        return 'Oral & Maxillofacial Surgeon';
      case DoctorRole.prosthodontist:
        return 'Prosthodontist';
      case DoctorRole.periodontist:
        return 'Periodontist';
      case DoctorRole.chiefDentalSurgeon:
        return 'Chief Dental Surgeon';
    }
  }
}
