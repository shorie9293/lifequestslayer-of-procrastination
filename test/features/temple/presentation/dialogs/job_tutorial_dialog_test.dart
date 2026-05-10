import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/temple/presentation/dialogs/job_tutorial_dialog.dart';

/// テスト用のDI注入済みGameViewModelを生成せずとも、
/// JobTutorialDialog は自己完結したWidgetのためHive依存不要。
void main() {
  Future<void> pumpJobTutorialDialog(WidgetTester tester,
      {bool jobTutorialCompleted = false}) async {
    // JobTutorialDialog は showJobTutorialDialog() 関数で表示される
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

  group('JobTutorialDialog', () {
    testWidgets('ダイアログが正しく表示され、4ページ構成である',
        (tester) async {
      await pumpJobTutorialDialog(tester);

      // 1ページ目：祝福ページ
      expect(find.text('🌸 祝福'), findsOneWidget);
      expect(
        find.text('修行、お疲れ様でありんす！\n浪人Lv.10到達、誠におめでとうございます。'),
        findsOneWidget,
      );
      expect(find.text('次へ →'), findsOneWidget);

      // 「次へ」を押して2ページ目へ
      await tester.tap(find.text('次へ →'));
      await tester.pumpAndSettle();

      // 2ページ目：職業説明ページ
      expect(find.text('🏯 職業解説'), findsOneWidget);
      expect(find.text('浪人'), findsOneWidget);
      expect(find.text('侍'), findsOneWidget);
      expect(find.text('法師'), findsOneWidget);
      expect(find.text('陰陽師'), findsOneWidget);
      expect(find.text('← 戻る'), findsOneWidget);
      expect(find.text('次へ →'), findsOneWidget);
    });

    testWidgets('職業説明ページで各職業の説明文が表示される', (tester) async {
      await pumpJobTutorialDialog(tester);

      // 1ページ目→2ページ目
      await tester.tap(find.text('次へ →'));
      await tester.pumpAndSettle();

      // 浪人の説明
      expect(find.textContaining('基本の職業'), findsOneWidget);
      expect(find.textContaining('ランク'), findsWidgets);

      // 侍の説明
      expect(find.textContaining('攻撃特化'), findsOneWidget);
      expect(find.textContaining('コンボ'), findsWidgets);

      // 法師の説明
      expect(find.textContaining('回復・支援'), findsOneWidget);
      expect(find.textContaining('繰り返し'), findsWidgets);

      // 陰陽師の説明
      expect(find.textContaining('知識・管理'), findsOneWidget);
      expect(find.textContaining('サブタスク'), findsWidgets);
    });

    testWidgets('マスタリー説明ページが表示される', (tester) async {
      await pumpJobTutorialDialog(tester);

      // 1ページ目→2ページ目
      await tester.tap(find.text('次へ →'));
      await tester.pumpAndSettle();
      // 2ページ目→3ページ目
      await tester.tap(find.text('次へ →'));
      await tester.pumpAndSettle();

      // 3ページ目：マスタリー説明
      expect(find.text('⭐ マスタリー'), findsOneWidget);
      expect(find.textContaining('Lv.14'), findsWidgets);
      expect(find.textContaining('スキル継承'), findsWidgets);
    });

    testWidgets('寺院への導線ページが表示され、閉じられる', (tester) async {
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

      // 1→2→3→4ページ目
      await tester.tap(find.text('次へ →'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('次へ →'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('次へ →'));
      await tester.pumpAndSettle();

      // 4ページ目：寺院への導線
      expect(find.text('🏛️ 寺院へ'), findsOneWidget);
      expect(find.textContaining('「社」タブ'), findsWidgets);
      expect(find.text('閉じる'), findsOneWidget);

      // 閉じるを押す
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();

      expect(closed, true);
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

      // スキップボタンが存在する
      expect(find.text('スキップ'), findsOneWidget);

      await tester.tap(find.text('スキップ'));
      await tester.pumpAndSettle();

      expect(skipped, true);
    });
  });
}
