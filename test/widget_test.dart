// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dental_clinic_app/ui/pages/splash_page.dart';

void main() {
  testWidgets('Splash screen shows modern splash content', (WidgetTester tester) async {
    // Pump only the SplashPage inside a minimal MaterialApp to avoid initializing
    // the full app graph (Firebase, providers, etc.) for a pure UI check.
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashPage(),
      ),
    );

    // Allow initial animations to start and settle one frame
    await tester.pump(const Duration(milliseconds: 16));

    // Should show app title and loading message
    expect(find.text('Odontist Plus'), findsOneWidget);
    expect(find.text('Loading your workspace...'), findsOneWidget);
  });
}
