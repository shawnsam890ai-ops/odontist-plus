class UtilityService {
  final String id;
  String name;
  String? regNumber; // optional registration / account / consumer number
  bool active;

  UtilityService({required this.id, required this.name, this.regNumber, this.active = true});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'regNumber': regNumber,
        'active': active,
      };

  factory UtilityService.fromJson(Map<String, dynamic> j) => UtilityService(
        id: j['id'] as String,
        name: j['name'] as String,
        regNumber: j['regNumber'] as String?,
        active: (j['active'] as bool?) ?? true,
      );
}
