import 'payment_rule.dart';

enum DoctorSex { male, female, other }

extension DoctorSexLabel on DoctorSex {
  String label() {
    switch (this) {
      case DoctorSex.male:
        return 'Male';
      case DoctorSex.female:
        return 'Female';
      case DoctorSex.other:
        return 'Other';
    }
  }
}

enum EmploymentType { consultant, permanent }

extension EmploymentTypeLabel on EmploymentType {
  String label() {
    switch (this) {
      case EmploymentType.consultant:
        return 'Consultant';
      case EmploymentType.permanent:
        return 'Permanent Staff';
    }
  }
}

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
  // Optional local file path to a photo/avatar for this doctor
  String? photoPath;
  // Additional profile fields
  DoctorSex sex;
  int? age; // optional explicit age
  DateTime? dob;
  String? phone;
  String? address;
  String? registrationNumber;
  String? registeredState;
  EmploymentType employmentType;

  Doctor({
    required this.id,
    required this.name,
    required this.role,
    Map<String, PaymentRule>? rules,
    this.active = true,
    this.photoPath,
    this.sex = DoctorSex.male,
    this.age,
    this.dob,
    this.phone,
    this.address,
    this.registrationNumber,
    this.registeredState,
    this.employmentType = EmploymentType.consultant,
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
