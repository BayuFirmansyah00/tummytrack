import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart' as main_app;
import 'package:myapp/app.dart';
import 'package:myapp/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen displays with animations and navigates to Placeholder',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(main_app.MyApp());

    // Verify that the splash screen is displayed (initial frame).
    expect(find.text('MyApp'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    // Wait for animations to complete (1.2 detik maksimum dari fade-in teks).
    await tester.pumpAndSettle(const Duration(milliseconds: 1300));

    // Simulate the 3-second timer by pumping the widget tree.
    await tester.pumpAndSettle(const Duration(seconds: 4)); // Tunggu lebih dari 3 detik

    // Verify that the app has navigated to PlaceholderScreen.
    expect(find.text('Ini akan menjadi layar login atau dashboard'), findsOneWidget);
    expect(find.text('MyApp'), findsNothing); // Splash screen tidak lagi terlihat
  });
}