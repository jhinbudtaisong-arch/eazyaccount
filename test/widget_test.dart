import 'package:eazyaccount/features/auth/auth_screen.dart';
import 'package:eazyaccount/features/home/home_screen.dart';
import 'package:eazyaccount/shared/models/money_entry.dart';
import 'package:eazyaccount/shared/models/parsed_money_entry.dart';
import 'package:eazyaccount/shared/services/speech_recognition_service.dart';
import 'package:eazyaccount/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('auth screen shows real email login form', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          onSignIn: (_, __) async {},
          onSignUp: (_, __, ___) async {},
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
          onTogglePendingEntry: (_) async {},
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

  testWidgets('speech listens for multiple sentences until 10 seconds silence',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final speech = _FakeSpeechRecognitionService();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(
          entries: const [],
          isLoading: false,
          isSaving: false,
          onRefresh: () async {},
          onPreviewText: (rawText) async => ParsedMoneyEntry(
            rawText: rawText,
            items: [
              ParsedMoneyItem(
                name: rawText,
                amount: 50,
                type: EntryType.expense,
              ),
            ],
          ),
          onSaveParsedEntry: (_) async {},
          onTogglePendingEntry: (_) async {},
          onOpenDetails: () {},
          isDarkMode: false,
          onToggleThemeMode: () {},
          speechService: speech,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();

    expect(speech.listenFor, const Duration(hours: 1));
    expect(speech.pauseFor, const Duration(seconds: 10));
    expect(find.textContaining('10 วินาที'), findsOneWidget);
  });

  testWidgets('speech waits for listening to stop before parsing final text',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final speech = _FakeSpeechRecognitionService();
    var previewCount = 0;
    String? previewRawText;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(
          entries: const [],
          isLoading: false,
          isSaving: false,
          onRefresh: () async {},
          onPreviewText: (rawText) async {
            previewCount++;
            previewRawText = rawText;
            return ParsedMoneyEntry(
              rawText: rawText,
              items: [
                const ParsedMoneyItem(
                  name: 'ขายข้าว',
                  amount: 50,
                  type: EntryType.expense,
                ),
              ],
            );
          },
          onSaveParsedEntry: (_) async {},
          onTogglePendingEntry: (_) async {},
          onOpenDetails: () {},
          isDarkMode: false,
          onToggleThemeMode: () {},
          speechService: speech,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();

    speech.emit('ขายข้าว 50 ซื้อถุง 30', isFinal: true);
    await tester.pump();

    expect(previewCount, 0);

    speech.finish();
    await tester.pumpAndSettle();

    expect(previewCount, 1);
    expect(previewRawText, 'ขายข้าว 50 ซื้อถุง 30');
    expect(find.text('ตรวจรายการก่อนบันทึก'), findsOneWidget);
  });

  testWidgets('speech does not parse manual placeholder when no voice is heard',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final speech = _FakeSpeechRecognitionService();
    var previewCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(
          entries: const [],
          isLoading: false,
          isSaving: false,
          onRefresh: () async {},
          onPreviewText: (rawText) async {
            previewCount++;
            return ParsedMoneyEntry(
              rawText: rawText,
              items: [
                ParsedMoneyItem(
                  name: rawText,
                  amount: 50,
                  type: EntryType.expense,
                ),
              ],
            );
          },
          onSaveParsedEntry: (_) async {},
          onTogglePendingEntry: (_) async {},
          onOpenDetails: () {},
          isDarkMode: false,
          onToggleThemeMode: () {},
          speechService: speech,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();

    speech.finish();
    await tester.pumpAndSettle();

    expect(previewCount, 0);
    expect(
        find.text('หยุดฟังแล้ว เพราะไม่มีเสียงพูด 10 วินาที'), findsOneWidget);
  });
}

class _FakeSpeechRecognitionService extends SpeechRecognitionService {
  SpeechTextCallback? _onText;
  SpeechStatusCallback? _onStatus;
  bool _isListening = false;

  Duration? listenFor;
  Duration? pauseFor;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> initialize({
    SpeechStatusCallback? onStatus,
    SpeechErrorCallback? onError,
  }) async {
    _onStatus = onStatus;
    return true;
  }

  @override
  Future<void> startListening({
    required SpeechTextCallback onText,
    Duration listenFor = const Duration(hours: 1),
    Duration pauseFor = const Duration(seconds: 10),
  }) async {
    _onText = onText;
    this.listenFor = listenFor;
    this.pauseFor = pauseFor;
    _isListening = true;
    _onStatus?.call('listening');
  }

  @override
  Future<void> stop() async {
    finish();
  }

  @override
  Future<void> cancel() async {
    _isListening = false;
  }

  void emit(String text, {bool isFinal = false}) {
    _onText?.call(text, isFinal);
  }

  void finish() {
    _isListening = false;
    _onStatus?.call('done');
  }
}
