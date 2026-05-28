import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/temple/presentation/dialogs/job_tutorial_dialog.dart';

/// テスト用のヘルパー：JobTutorialDialogを表示する
Future<void> pumpJobTutorialDialog(WidgetTester tester,
    {bool jobTutorialCompleted = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            showJobTutorialDialog(
              context,
              onClose: () {},
              jobTutorialCompleted: jobTutorialCompleted,
            );
          },
          child: const Text('Show'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Show'));
  await tester.pumpAndSettle();
}

/// 指定ページ数だけ「次へ →」をタップする
Future<void> tapNext(WidgetTester tester, int count) async {
  for (int i = 0; i < count; i++) {
    await tester.tap(find.text('次へ →'));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('JobTutorialDialog', () {
    testWidgets('7ページ構成である（ページインジケーター7個）', (tester) async {
      await pumpJobTutorialDialog(tester);

      // インジケーターが7つある（7ページ）
      // 各ページのインジケーターは Container（height: 4）で表現されている
      // ExpansionTile等との混同を避け、height制約で特定
      final indicators = find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxHeight == 4,
      );
      expect(indicators, findsNWidgets(7));
    });

    testWidgets('1ページ目：祝福ページ', (tester) async {
      await pumpJobTutorialDialog(tester);

      expect(find.text('🌸 祝福'), findsOneWidget);
      expect(
        find.text('修行、お疲れ様でありんす！\n浪人Lv.10到達、誠におめでとうございます。'),
        findsOneWidget,
      );
      // 全16スキルの告知
      expect(find.textContaining('4つの職業'), findsOneWidget);
      expect(find.text('次へ →'), findsOneWidget);
    });

    testWidgets('2ページ目：浪人スキルページ', (tester) async {
      await pumpJobTutorialDialog(tester);
      await tapNext(tester, 1);

      expect(find.text('🗡️ 浪人のスキル'), findsOneWidget);
      expect(find.text('冒険者の勘'), findsOneWidget);
      expect(find.text('果てなき挑戦'), findsOneWidget);
      expect(find.text('← 戻る'), findsOneWidget);
    });

    testWidgets('3ページ目：侍スキルページ', (tester) async {
      await pumpJobTutorialDialog(tester);
      await tapNext(tester, 2);

      expect(find.text('⚔️ 侍のスキル'), findsOneWidget);
      expect(find.text('連撃の構え'), findsOneWidget);
      expect(find.text('逆転の気魄'), findsOneWidget);
      expect(find.text('集中の型'), findsOneWidget);
      expect(find.text('武士道の極意'), findsOneWidget);
      expect(find.text('← 戻る'), findsOneWidget);
    });

    testWidgets('4ページ目：法師スキルページ', (tester) async {
      await pumpJobTutorialDialog(tester);
      await tapNext(tester, 3);

      expect(find.text('🛡️ 法師のスキル'), findsOneWidget);
      expect(find.text('後追いの祈り'), findsOneWidget);
      expect(find.text('微睡みの加護'), findsOneWidget);
      expect(find.text('連続の誓い'), findsOneWidget);
      expect(find.text('悟りの境地'), findsOneWidget);
    });

    testWidgets('5ページ目：陰陽師スキルページ', (tester) async {
      await pumpJobTutorialDialog(tester);
      await tapNext(tester, 4);

      expect(find.text('🔮 陰陽師のスキル'), findsOneWidget);
      expect(find.text('分割の理'), findsOneWidget);
      expect(find.text('札の掌握'), findsOneWidget);
      expect(find.text('計画の陣'), findsOneWidget);
      expect(find.text('俯瞰の魔眼'), findsOneWidget);
    });

    testWidgets('6ページ目：スキルスロット説明ページ', (tester) async {
      await pumpJobTutorialDialog(tester);
      await tapNext(tester, 5);

      expect(find.text('🔧 スキルスロットシステム'), findsOneWidget);
      expect(find.textContaining('基本1枠'), findsOneWidget);
      expect(find.textContaining('MASTERスキル'), findsOneWidget);
      expect(find.text('← 戻る'), findsOneWidget);
      expect(find.text('次へ →'), findsOneWidget);
    });

    testWidgets('7ページ目：寺院への導線ページ', (tester) async {
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showJobTutorialDialog(
                  context,
                  onClose: () => closed = true,
                  jobTutorialCompleted: false,
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // 6回「次へ」で最終ページ
      await tapNext(tester, 6);

      expect(find.text('🏛️ 寺院へ'), findsOneWidget);
      expect(find.textContaining('「社」タブ'), findsOneWidget);
      expect(find.text('閉じる'), findsOneWidget);

      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(closed, true);
    });

    testWidgets('戻るボタンで前のページに戻れる', (tester) async {
      await pumpJobTutorialDialog(tester);

      // 2ページ目へ
      await tapNext(tester, 1);
      expect(find.text('🗡️ 浪人のスキル'), findsOneWidget);

      // 戻る
      await tester.tap(find.text('← 戻る'));
      await tester.pumpAndSettle();
      expect(find.text('🌸 祝福'), findsOneWidget);
    });

    testWidgets('スキップ可能である', (tester) async {
      bool skipped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showJobTutorialDialog(
                  context,
                  onClose: () {},
                  jobTutorialCompleted: false,
                  onSkip: () => skipped = true,
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('スキップ'), findsOneWidget);

      await tester.tap(find.text('スキップ'));
      await tester.pumpAndSettle();
      expect(skipped, true);
    });

    testWidgets('jobTutorialCompleted=trueでダイアログが表示されない',
        (tester) async {
      await pumpJobTutorialDialog(tester, jobTutorialCompleted: true);

      // ダイアログが表示されていない
      expect(find.text('🌸 祝福'), findsNothing);
    });
  });
}
