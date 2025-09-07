import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oasis_taxi/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(OasisTaxiApp());
    
    // Verify that the app launches successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}