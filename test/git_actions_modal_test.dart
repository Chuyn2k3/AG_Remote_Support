import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_support/screens/remote/widgets/git_actions_modal.dart';

void main() {
  testWidgets('GitActionsModal renders tabs and preset commands', (tester) async {
    String? sentPrompt;
    bool? wasAutoSubmit;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GitActionsModal(
            onSendPrompt: (prompt, autoSubmit) {
              sentPrompt = prompt;
              wasAutoSubmit = autoSubmit;
            },
          ),
        ),
      ),
    );

    // Verify title and tabs exist
    expect(find.text('Git & Code Diff Lệnh Nhanh'), findsOneWidget);
    expect(find.text('Diff & Status'), findsOneWidget);
    expect(find.text('Lịch sử'), findsOneWidget);
    expect(find.text('Tác vụ'), findsOneWidget);

    // Verify initial Diff & Status presets exist
    expect(find.text('Kiểm tra file thay đổi'), findsOneWidget);
    expect(find.text('git status'), findsOneWidget);
    expect(find.text('git diff'), findsOneWidget);

    // Tap on git status preset
    await tester.tap(find.text('Kiểm tra file thay đổi'));
    await tester.pumpAndSettle();

    expect(sentPrompt, contains('git status'));
    expect(wasAutoSubmit, isTrue);
  });

  testWidgets('GitActionsModal edit icon triggers insert-only mode', (tester) async {
    String? sentPrompt;
    bool? wasAutoSubmit;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GitActionsModal(
            onSendPrompt: (prompt, autoSubmit) {
              sentPrompt = prompt;
              wasAutoSubmit = autoSubmit;
            },
          ),
        ),
      ),
    );

    // Tap edit icon on first preset
    final editButtons = find.byIcon(Icons.edit_note_rounded);
    expect(editButtons, findsWidgets);

    await tester.tap(editButtons.first);
    await tester.pumpAndSettle();

    expect(sentPrompt, isNotNull);
    expect(wasAutoSubmit, isFalse);
  });

  testWidgets('GitActionsModal custom command input works', (tester) async {
    String? sentPrompt;
    bool? wasAutoSubmit;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GitActionsModal(
            onSendPrompt: (prompt, autoSubmit) {
              sentPrompt = prompt;
              wasAutoSubmit = autoSubmit;
            },
          ),
        ),
      ),
    );

    // Enter custom command in text field
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    await tester.enterText(textField, 'git checkout -b feature/test');
    await tester.pump();

    // Tap send button
    final sendButton = find.byIcon(Icons.send_rounded);
    expect(sendButton, findsOneWidget);

    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    expect(sentPrompt, 'git checkout -b feature/test');
    expect(wasAutoSubmit, isTrue);
  });
}
