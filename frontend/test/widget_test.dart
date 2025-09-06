// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zvonilka/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app starts without crashing.
    // For a smoke test, just ensuring it builds is often enough.
    // We can check for a known widget on the initial screen, for example, the SplashScreen.
    // Since SplashScreen quickly navigates away, we will just check for a MaterialApp.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
