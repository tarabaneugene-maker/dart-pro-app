// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:dart_pro_app/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DartsApp());

    // Verify that the app title is present
    expect(find.text('Тренировка'), findsOneWidget);
    expect(find.text('Игра'), findsOneWidget);
    expect(find.text('Онлайн'), findsOneWidget);
  });

  testWidgets('Navigation works correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const DartsApp());

    // Initially on training page
    expect(find.text('Выбор режима'), findsOneWidget);

    // Tap on game tab
    await tester.tap(find.text('Игра'));
    await tester.pumpAndSettle();

    // Should be on game page
    expect(find.text('Локальные игры'), findsOneWidget);

    // Tap on online tab
    await tester.tap(find.text('Онлайн'));
    await tester.pumpAndSettle();

    // Should be on online stub page
    expect(find.text('Здесь позже будет онлайн-режим.'), findsOneWidget);
  });
}