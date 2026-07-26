import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/studio/presentation/pages/studio_recipe_editor_page.dart';

void main() {
  testWidgets('new recipe editor exposes the complete authoring sections',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: StudioRecipeEditorPage()),
      ),
    );

    expect(find.text('Новий рецепт'), findsOneWidget);
    expect(find.text('Основне'), findsOneWidget);
    expect(find.text('Фотографія та кадрування'), findsOneWidget);
    expect(find.text('Інгредієнти'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Кроки приготування'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Кроки приготування'), findsOneWidget);
    expect(find.text('Зберегти чернетку'), findsOneWidget);
    expect(find.text('Опублікувати'), findsOneWidget);
  });

  testWidgets('new recipe editor has no initial overflow at phone width',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: StudioRecipeEditorPage()),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Зберегти чернетку'), findsOneWidget);
    expect(find.byTooltip('Опублікувати'), findsOneWidget);
  });
}
