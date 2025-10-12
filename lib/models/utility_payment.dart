import 'package:uuid/uuid.dart';

class UtilityPayment {
  final String id;
  final String serviceId;
  DateTime date;
  double amount;
  String? mode; // Cash/UPI/Card/Bank
  bool paid;
  String? receiptPath; // optional attachment path (placeholder)

  UtilityPayment({String? id, required this.serviceId, required this.date, required this.amount, this.mode, this.paid = false, this.receiptPath})
      : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'serviceId': serviceId,
        'date': date.toIso8601String(),
        'amount': amount,
        'mode': mode,
        'paid': paid,
        'receiptPath': receiptPath,
      };

  factory UtilityPayment.fromJson(Map<String, dynamic> j) => UtilityPayment(
        id: j['id'] as String?,
        serviceId: j['serviceId'] as String,
        date: DateTime.parse(j['date'] as String),
        amount: (j['amount'] as num).toDouble(),
        mode: j['mode'] as String?,
        paid: (j['paid'] as bool?) ?? false,
        receiptPath: j['receiptPath'] as String?,
      );
}
