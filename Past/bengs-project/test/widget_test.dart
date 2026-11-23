import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bengs/widgets/main_scaffold.dart';

void main() {
  testWidgets('MainScaffold shows all 5 tabs with Schedule selected by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MainScaffold(isDriverVerified: false)),
    );
    await tester.pump();

    expect(find.text('Schedule'), findsWidgets);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Find a ride'), findsNothing);
  });

  testWidgets('Tapping Home switches to the Quick Beng landing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MainScaffold(isDriverVerified: false)),
    );

    await tester.tap(find.text('Home'));
    await tester.pump();

    expect(find.text('Quick Beng!'), findsOneWidget);
    expect(find.text('Add a Quick Beng'), findsOneWidget);
    expect(find.text('Find a Quick Beng'), findsOneWidget);
  });
}
