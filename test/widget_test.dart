import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TummyTrack/main.dart';

void main() {
  testWidgets('Splash screen displays with animations',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Verify that the splash screen is displayed (initial frame).
    expect(find.text('TummyTrack'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for animations to complete.
    await tester.pumpAndSettle(const Duration(milliseconds: 1500));

    // Verify splash screen elements are still visible during animation.
    expect(find.text('TummyTrack'), findsOneWidget);
    expect(find.text('Smart Baby Monitoring'), findsOneWidget);
  });
}