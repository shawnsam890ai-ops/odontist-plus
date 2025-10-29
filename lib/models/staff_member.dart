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
  String? bloodGroup; // e.g., A+, O-, etc.
  int? preferredPaymentDay; // Day of month to pay salary (1-31)

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
    this.bloodGroup,
    this.preferredPaymentDay,
  }) : phoneNumbers = phoneNumbers ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'sex': sex,
        'address': address,
        'phoneNumbers': phoneNumbers,
        'emergencyContact': emergencyContact?.toJson(),
        'foodAllergy': foodAllergy,
        'medicalConditions': medicalConditions,
        'medications': medications,
        'bloodGroup': bloodGroup,
        'preferredPaymentDay': preferredPaymentDay,
      };

  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
        id: (j['id'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        age: (j['age'] as num?)?.toInt(),
        sex: j['sex'] as String?,
        address: j['address'] as String?,
        phoneNumbers: (j['phoneNumbers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
        emergencyContact: j['emergencyContact'] == null
            ? null
            : EmergencyContact.fromJson(j['emergencyContact'] as Map<String, dynamic>),
        foodAllergy: j['foodAllergy'] as String?,
        medicalConditions: j['medicalConditions'] as String?,
        medications: j['medications'] as String?,
        bloodGroup: j['bloodGroup'] as String?,
        preferredPaymentDay: (j['preferredPaymentDay'] as num?)?.toInt(),
      );
}

class EmergencyContact {
  String name;
  String relation;
  String phone;
  String? address;
  EmergencyContact({required this.name, required this.relation, required this.phone, this.address});

  Map<String, dynamic> toJson() => {
        'name': name,
        'relation': relation,
        'phone': phone,
        'address': address,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        name: (j['name'] as String?) ?? '',
        relation: (j['relation'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
        address: j['address'] as String?,
      );
}
