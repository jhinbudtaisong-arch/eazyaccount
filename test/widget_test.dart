import 'package:eazyaccount/features/auth/auth_screen.dart';
import 'package:eazyaccount/features/home/home_screen.dart';
import 'package:eazyaccount/shared/models/money_entry.dart';
import 'package:eazyaccount/shared/models/parsed_money_entry.dart';
import 'package:eazyaccount/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('auth screen shows real email login form', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          onSignIn: (_, __) async {},
          onSignUp: (_, __) async {},
        ),
      ),
    );

    expect(find.text('EazyAccount'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsWidgets);
    expect(find.text('อีเมล'), findsOneWidget);
    expect(find.text('รหัสผ่าน'), findsOneWidget);
  });

  testWidgets('home appends newly parsed tags to unsaved pending tags',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ParsedMoneyEntry? savedEntry;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(
          entries: const [],
          isLoading: false,
          isSaving: false,
          onRefresh: () async {},
          onPreviewText: (rawText) async {
            final amount = rawText == 'first' ? 10 : 20;
            return ParsedMoneyEntry(
              rawText: rawText,
              items: [
                ParsedMoneyItem(
                  name: rawText,
                  amount: amount,
                  type: EntryType.expense,
                ),
              ],
            );
          },
          onSaveParsedEntry: (entry) async => savedEntry = entry,
          onOpenDetails: () {},
          isDarkMode: false,
          onToggleThemeMode: () {},
        ),
      ),
    );

    final manualTextField = find.byType(TextField);

    await tester.enterText(manualTextField, 'first');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('first10'), findsOneWidget);

    await tester.enterText(manualTextField, 'second');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('first10'), findsOneWidget);
    expect(find.text('second20'), findsOneWidget);

    await tester
        .tap(find.widgetWithIcon(FilledButton, Icons.check_rounded).last);
    await tester.pumpAndSettle();

    expect(savedEntry?.rawText, 'first\nsecond');
    expect(savedEntry?.items.map((item) => item.name), ['first', 'second']);
  });
}
