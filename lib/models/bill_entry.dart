import 'package:uuid/uuid.dart';

class BillEntry {
  final String id;
  DateTime date;
  String itemName;
  double amount;
  String? receiptPath; // optional attachment path or note
  String category; // e.g., Consumables, Equipment, Maintenance, Other
  bool isPaid; // whether the bill has been paid
  bool isCredit; // whether the bill is on credit (to be paid later)
  DateTime? dueDate; // due date for credit bills

  BillEntry({
    String? id,
    required this.date,
    required this.itemName,
    required this.amount,
    this.receiptPath,
    this.category = 'Other',
    this.isPaid = false,
    this.isCredit = false,
    this.dueDate,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'itemName': itemName,
        'amount': amount,
        'receiptPath': receiptPath,
        'category': category,
        'isPaid': isPaid,
        'isCredit': isCredit,
        'dueDate': dueDate?.toIso8601String(),
      };

  factory BillEntry.fromJson(Map<String, dynamic> j) => BillEntry(
        id: j['id'] as String?,
        date: DateTime.parse(j['date'] as String),
        itemName: j['itemName'] as String,
        amount: (j['amount'] as num).toDouble(),
        receiptPath: j['receiptPath'] as String?,
        category: (j['category'] as String?) ?? 'Other',
        isPaid: (j['isPaid'] as bool?) ?? false,
        isCredit: (j['isCredit'] as bool?) ?? false,
        dueDate: j['dueDate'] != null ? DateTime.tryParse(j['dueDate'] as String) : null,
      );
}
