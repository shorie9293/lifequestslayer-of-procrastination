import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/widgets/help_dialog.dart';

Widget buildTestApp({HelpScreen screen = HelpScreen.overview}) {
  return MaterialApp(
    home: Scaffold(
      body: HelpDialog(screen: screen),
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

  group('HelpDialog TownScreen', () {
    testWidgets('町画面ヘルプに町XPの獲得方法が表示される', (tester) async {
      await tester.pumpWidget(buildTestApp(screen: HelpScreen.town));
      // 町XP獲得に関するセクション（タイトル＋本文）が表示される
      expect(find.text('町の発展と町XP'), findsOneWidget);
      expect(find.textContaining('クエストを討伐すると町XP'), findsOneWidget);
    });
  });
}
