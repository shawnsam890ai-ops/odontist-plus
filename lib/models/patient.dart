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
  })  : sessions = sessions ?? [],
        labWorks = labWorks ?? [];

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
      );
}
