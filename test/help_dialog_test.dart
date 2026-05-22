import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/widgets/help_dialog.dart';

Widget buildTestApp() {
  return const MaterialApp(
    home: Scaffold(
      body: HelpDialog(),
    ),
  );
}

void main() {
  group('HelpDialog Widget', () {
    testWidgets('タイトル「アプリのコンセプト」が表示される', (tester) async {
      await tester.pumpWidget(buildTestApp());
      expect(find.text('アプリのコンセプト'), findsOneWidget);
    });

    testWidgets('3つのセクションが表示される', (tester) async {
      await tester.pumpWidget(buildTestApp());
      expect(find.text('RPG風依頼管理'), findsOneWidget);
      expect(find.text('レベルアップと依頼枠'), findsOneWidget);
      expect(find.text('転職と新機能の解放'), findsOneWidget);
    });

    testWidgets('「理解した！」ボタンが表示される', (tester) async {
      await tester.pumpWidget(buildTestApp());
      expect(find.text('理解した！'), findsOneWidget);
    });
  });
}
