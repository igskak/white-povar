import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/router/app_router.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveNavigationShell(
          selectedIndex: 1,
          onDestinationSelected: (_) {},
          child: const KeyedSubtree(
            key: ValueKey('tab-content'),
            child: Text('Збережений стан вкладки'),
          ),
        ),
      ),
    );
  }

  testWidgets('uses bottom navigation at 390 pixels', (tester) async {
    await pumpShell(tester, const Size(390, 844));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Збережений стан вкладки'), findsOneWidget);
  });

  testWidgets('uses navigation rail at 768 pixels', (tester) async {
    await pumpShell(tester, const Size(768, 1024));

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(find.byType(NavigationBar), findsNothing);
    expect(rail.extended, isFalse);
    expect(find.text('Збережений стан вкладки'), findsOneWidget);
  });

  testWidgets('uses desktop composition at 1280 pixels', (tester) async {
    await pumpShell(tester, const Size(1280, 900));

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.byType(ConstrainedBox), findsWidgets);
    expect(find.text('Збережений стан вкладки'), findsOneWidget);
  });
}
