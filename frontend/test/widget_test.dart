// Basic Flutter widget test for the cooking app

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/app.dart';

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: CookingApp(),
      ),
    );

    // Verify that the app loads (this is a basic smoke test)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
