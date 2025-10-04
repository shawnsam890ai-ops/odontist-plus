class RevenueEntry {
  final String id;
  final DateTime date;
  final String patientId;
  final String description; // e.g. Payment for Root Canal Step
  final double amount;

  RevenueEntry({
    required this.id,
    required this.date,
    required this.patientId,
    required this.description,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'patientId': patientId,
        'description': description,
        'amount': amount,
      };

  factory RevenueEntry.fromJson(Map<String, dynamic> json) => RevenueEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        patientId: json['patientId'] as String,
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
      );
}
