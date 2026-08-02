import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shitaka_memes/main.dart';

void main() {
  testWidgets('App builds and shows home', (WidgetTester tester) async {
    await tester.pumpWidget(const ShitakaMemesApp());
    await tester.pumpAndSettle();

    expect(find.text('SHITAKA MEMES'), findsOneWidget);
    expect(find.byIcon(Icons.history_outlined), findsWidgets);
    expect(find.byIcon(Icons.info_outline), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
