class LabWork {
  final String id;
  final String patientId; // link to patient
  final String labName;
  final String workType; // e.g. Crown, Bridge etc
  final String shade;
  final DateTime expectedDelivery;
  final bool delivered;
  final String? attachmentPath; // optional file

  LabWork({
    required this.id,
    required this.patientId,
    required this.labName,
    required this.workType,
    required this.shade,
    required this.expectedDelivery,
    this.delivered = false,
    this.attachmentPath,
  });

  LabWork copyWith({
    String? id,
    String? patientId,
    String? labName,
    String? workType,
    String? shade,
    DateTime? expectedDelivery,
    bool? delivered,
    String? attachmentPath,
  }) => LabWork(
        id: id ?? this.id,
        patientId: patientId ?? this.patientId,
        labName: labName ?? this.labName,
        workType: workType ?? this.workType,
        shade: shade ?? this.shade,
        expectedDelivery: expectedDelivery ?? this.expectedDelivery,
        delivered: delivered ?? this.delivered,
        attachmentPath: attachmentPath ?? this.attachmentPath,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'labName': labName,
        'workType': workType,
        'shade': shade,
        'expectedDelivery': expectedDelivery.toIso8601String(),
        'delivered': delivered,
        'attachmentPath': attachmentPath,
      };

  factory LabWork.fromJson(Map<String, dynamic> json) => LabWork(
        id: json['id'] as String,
        patientId: json['patientId'] as String,
        labName: json['labName'] as String,
        workType: json['workType'] as String,
        shade: json['shade'] as String,
        expectedDelivery: DateTime.parse(json['expectedDelivery'] as String),
        delivered: json['delivered'] as bool? ?? false,
        attachmentPath: json['attachmentPath'] as String?,
      );
}
