import 'package:uuid/uuid.dart';

class BillEntry {
  final String id;
  DateTime date;
  String itemName;
  double amount;
  String? receiptPath; // optional attachment path or note

  BillEntry({String? id, required this.date, required this.itemName, required this.amount, this.receiptPath})
      : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'itemName': itemName,
        'amount': amount,
        'receiptPath': receiptPath,
      };

  factory BillEntry.fromJson(Map<String, dynamic> j) => BillEntry(
        id: j['id'] as String?,
        date: DateTime.parse(j['date'] as String),
        itemName: j['itemName'] as String,
        amount: (j['amount'] as num).toDouble(),
        receiptPath: j['receiptPath'] as String?,
      );
}
