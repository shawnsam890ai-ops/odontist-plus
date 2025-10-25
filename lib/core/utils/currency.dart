import 'package:intl/intl.dart';

/// Currency formatting helpers for INR (₹)
class Currency {
  static String inrFormat(num amount, {int decimalDigits = 0}) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: decimalDigits);
    return formatter.format(amount);
  }
}
