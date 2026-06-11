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
    testWidgets('タイトル「現世の導き — 神託管理の心得」が表示される', (tester) async {
      await tester.pumpWidget(buildTestApp());
      expect(find.text('現世の導き — 神託管理の心得'), findsOneWidget);
    });

    testWidgets('3つのセクションが表示される', (tester) async {
      await tester.pumpWidget(buildTestApp());
      expect(find.text('神託（クエスト）管理の道'), findsOneWidget);
      expect(find.text('神位昇格（レベルアップ）と神託枠'), findsOneWidget);
      expect(find.text('神職転換（転職）と神器解放'), findsOneWidget);
    });

    testWidgets('「拝承した！」ボタンが表示される', (tester) async {
      await tester.pumpWidget(buildTestApp());
      expect(find.text('拝承した！'), findsOneWidget);
    });
  });
}
