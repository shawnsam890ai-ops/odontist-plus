// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:dental_clinic_app/main.dart';

void main() {
  testWidgets('Splash screen shows modern splash content', (WidgetTester tester) async {
  await tester.pumpWidget(const DentalClinicApp());
  // Allow initial animations to start and settle one frame
  await tester.pump(const Duration(milliseconds: 16));
    // Should show app title and loading message
    expect(find.text('Dental Clinic'), findsOneWidget);
    expect(find.text('Loading your workspace...'), findsOneWidget);
  });
}
