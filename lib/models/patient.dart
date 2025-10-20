import '../core/enums.dart';
import 'treatment_session.dart';
import 'lab_work.dart';

class Patient {
  String id; // internal unique id (uuid)
  int displayNumber; // sequential number shown to user (reindexed on delete)
  String customNumber; // manually editable id number in backend (optional)
  String name;
  int age;
  Sex sex;
  String address;
  String phone;
  DateTime createdAt;
  final List<TreatmentSession> sessions;
  final List<LabWork> labWorks;
  // New medical/dental history fields
  final List<String> pastDentalHistory;
  final List<String> pastMedicalHistory;
  final List<String> currentMedications;
  final List<String> drugAllergies;
  // AI-related flags
  final bool pregnant;
  final bool breastfeeding;

  Patient({
    required this.id,
    required this.displayNumber,
    required this.name,
    required this.age,
    required this.sex,
    required this.address,
    required this.phone,
    required this.createdAt,
    this.customNumber = '',
    List<TreatmentSession>? sessions,
  List<LabWork>? labWorks,
  List<String>? pastDentalHistory,
  List<String>? pastMedicalHistory,
  List<String>? currentMedications,
  List<String>? drugAllergies,
  bool? pregnant,
  bool? breastfeeding,
  })  : sessions = sessions ?? [],
    labWorks = labWorks ?? [],
    pastDentalHistory = pastDentalHistory ?? [],
    pastMedicalHistory = pastMedicalHistory ?? [],
    currentMedications = currentMedications ?? [],
    drugAllergies = drugAllergies ?? [],
    pregnant = pregnant ?? false,
    breastfeeding = breastfeeding ?? false;

  Patient copyWith({
    String? id,
    int? displayNumber,
    String? customNumber,
    String? name,
    int? age,
    Sex? sex,
    String? address,
    String? phone,
    DateTime? createdAt,
    List<TreatmentSession>? sessions,
    List<LabWork>? labWorks,
    List<String>? pastDentalHistory,
    List<String>? pastMedicalHistory,
    List<String>? currentMedications,
    List<String>? drugAllergies,
    bool? pregnant,
    bool? breastfeeding,
  }) => Patient(
        id: id ?? this.id,
        displayNumber: displayNumber ?? this.displayNumber,
        customNumber: customNumber ?? this.customNumber,
        name: name ?? this.name,
        age: age ?? this.age,
        sex: sex ?? this.sex,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        createdAt: createdAt ?? this.createdAt,
        sessions: sessions ?? List.from(this.sessions),
        labWorks: labWorks ?? List.from(this.labWorks),
        pastDentalHistory: pastDentalHistory ?? List.from(this.pastDentalHistory),
        pastMedicalHistory: pastMedicalHistory ?? List.from(this.pastMedicalHistory),
        currentMedications: currentMedications ?? List.from(this.currentMedications),
        drugAllergies: drugAllergies ?? List.from(this.drugAllergies),
        pregnant: pregnant ?? this.pregnant,
        breastfeeding: breastfeeding ?? this.breastfeeding,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayNumber': displayNumber,
        'customNumber': customNumber,
        'name': name,
        'age': age,
        'sex': sex.index,
        'address': address,
        'phone': phone,
        'createdAt': createdAt.toIso8601String(),
        'sessions': sessions.map((e) => e.toJson()).toList(),
        'labWorks': labWorks.map((e) => e.toJson()).toList(),
        'pastDentalHistory': pastDentalHistory,
        'pastMedicalHistory': pastMedicalHistory,
        'currentMedications': currentMedications,
        'drugAllergies': drugAllergies,
        'pregnant': pregnant,
        'breastfeeding': breastfeeding,
      };

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
        id: json['id'] as String,
        displayNumber: json['displayNumber'] as int,
        customNumber: json['customNumber'] as String? ?? '',
        name: json['name'] as String,
        age: json['age'] as int,
        sex: Sex.values[json['sex'] as int],
        address: json['address'] as String,
        phone: json['phone'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        sessions: (json['sessions'] as List<dynamic>).map((e) => TreatmentSession.fromJson(e as Map<String, dynamic>)).toList(),
        labWorks: (json['labWorks'] as List<dynamic>).map((e) => LabWork.fromJson(e as Map<String, dynamic>)).toList(),
        pastDentalHistory: (json['pastDentalHistory'] as List<dynamic>? ?? []).cast<String>(),
        pastMedicalHistory: (json['pastMedicalHistory'] as List<dynamic>? ?? []).cast<String>(),
        currentMedications: (json['currentMedications'] as List<dynamic>? ?? []).cast<String>(),
        drugAllergies: (json['drugAllergies'] as List<dynamic>? ?? []).cast<String>(),
        pregnant: json['pregnant'] as bool? ?? false,
        breastfeeding: json['breastfeeding'] as bool? ?? false,
      );
}
