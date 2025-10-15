class StaffMember {
  final String id;
  String name;
  int? age;
  String? sex; // M / F / Other
  String? address;
  final List<String> phoneNumbers; // primary first
  EmergencyContact? emergencyContact;
  // Medical information
  String? foodAllergy;
  String? medicalConditions;
  String? medications;

  StaffMember({
    required this.id,
    required this.name,
    this.age,
    this.sex,
    this.address,
    List<String>? phoneNumbers,
    this.emergencyContact,
    this.foodAllergy,
    this.medicalConditions,
    this.medications,
  }) : phoneNumbers = phoneNumbers ?? [];
}

class EmergencyContact {
  String name;
  String relation;
  String phone;
  String? address;
  EmergencyContact({required this.name, required this.relation, required this.phone, this.address});
}
