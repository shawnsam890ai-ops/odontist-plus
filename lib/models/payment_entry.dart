enum EntryType { payment, payout }

class PaymentEntry {
  final String id;
  final String doctorId;
  final DateTime date;
  final String procedureKey;
  final double amountReceived;
  final double doctorShare;
  final double clinicShare;
  final String? patient;
  final String? note;
  final String? mode; // e.g., Cash, UPI, Card, Bank Transfer
  final EntryType type;

  PaymentEntry({
    required this.id,
    required this.doctorId,
    required this.date,
    required this.procedureKey,
    required this.amountReceived,
    required this.doctorShare,
    required this.clinicShare,
    this.patient,
    this.note,
    this.mode,
    this.type = EntryType.payment,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'doctorId': doctorId,
        'date': date.toIso8601String(),
        'procedureKey': procedureKey,
        'amountReceived': amountReceived,
        'doctorShare': doctorShare,
        'clinicShare': clinicShare,
        'patient': patient,
        'note': note,
        'mode': mode,
    'type': type.name,
      };

  factory PaymentEntry.fromJson(Map<String, dynamic> j) => PaymentEntry(
        id: j['id'] as String,
        doctorId: j['doctorId'] as String,
        date: DateTime.parse(j['date'] as String),
        procedureKey: j['procedureKey'] as String,
        amountReceived: (j['amountReceived'] as num).toDouble(),
        doctorShare: (j['doctorShare'] as num).toDouble(),
        clinicShare: (j['clinicShare'] as num).toDouble(),
        patient: j['patient'] as String?,
        note: j['note'] as String?,
        mode: j['mode'] as String?,
        type: _parseType(j['type'] as String?),
      );

  static EntryType _parseType(String? s) {
    switch (s) {
      case 'payout':
        return EntryType.payout;
      case 'payment':
      default:
        return EntryType.payment;
    }
  }
}
