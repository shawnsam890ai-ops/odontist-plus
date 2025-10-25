import 'package:flutter_test/flutter_test.dart';
import 'package:dental_clinic_app/core/utils/currency.dart';

void main() {
  test('INR formatting without decimals', () {
    expect(Currency.inrFormat(0), '₹0');
    expect(Currency.inrFormat(123), '₹123');
    expect(Currency.inrFormat(1234), '₹1,234');
    expect(Currency.inrFormat(123456), '₹1,23,456');
  });

  test('INR formatting with decimals', () {
    expect(Currency.inrFormat(1234.5, decimalDigits: 2), '₹1,234.50');
    expect(Currency.inrFormat(123456.78, decimalDigits: 2), '₹1,23,456.78');
  });
}
