// 天浮橋計画 — Integration Test v3
// 単一testWidgetsで全フロー実行（Hive重複回避）
// 天照大神（アマテラス）鍛造

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:rpg_todo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('フルE2E: 起動→チュートリアル突破→タスク作成', (tester) async {
    // === アプリ起動 ===
    app.main();
    // 実機では pumpAndSettle が効かない場合あり。段階的にpump
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));
    // 追加で安定させる
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    // === 画面確認 ===
    expect(find.text('冒険者ギルド'), findsOneWidget);

    // === チュートリアル「理解した！」 ===
    final understood = find.text('理解した！');
    if (understood.evaluate().isNotEmpty) {
      await tester.tap(understood);
      await tester.pump(const Duration(seconds: 2));
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    // === チュートリアル「スキップ」 ===
    final skipBtn = find.text('スキップ');
    if (skipBtn.evaluate().isNotEmpty) {
      await tester.tap(skipBtn.first);
      await tester.pump(const Duration(seconds: 2));
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    // === 恩賞ダイアログ ===
    final reward = find.text('ありがたき幸せ！');
    if (reward.evaluate().isNotEmpty) {
      await tester.tap(reward);
      await tester.pump(const Duration(seconds: 2));
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    // === ギルド画面到達確認 ===
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('冒険者ギルド'), findsOneWidget);
    expect(find.text('ギルド'), findsOneWidget);

    // === タブ遷移テスト ===
    // 戦場タブ
    await tester.tap(find.text('戦場'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('神殿'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('街'));
    await tester.pump(const Duration(seconds: 2));
    // ギルドに戻る
    await tester.tap(find.text('ギルド'));
    await tester.pump(const Duration(seconds: 2));

    // === タスク作成 ===
    // +ボタン（FloatingActionButton）
    final addBtn = find.byType(FloatingActionButton);
    if (addBtn.evaluate().isNotEmpty) {
      await tester.tap(addBtn.first);
      await tester.pump(const Duration(seconds: 2));
    }

    // フォームが開くのを待つ
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    // フォーム表示確認
    final formTitle = find.text('新規クエスト作成');
    if (formTitle.evaluate().isNotEmpty) {
      // タイトル入力
      final fields = find.byType(TextFormField);
      if (fields.evaluate().isNotEmpty) {
        await tester.enterText(fields.first, 'e2e_smoke_test');
        await tester.pump(const Duration(seconds: 1));
      }

      // 作成ボタン
      final create = find.text('作成');
      if (create.evaluate().isNotEmpty) {
        await tester.tap(create);
        await tester.pump(const Duration(seconds: 3));
        for (int i = 0; i < 3; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }
    }

    // === 結果確認 ===
    // 画面にタスクが表示されていれば成功
    await tester.pump(const Duration(seconds: 1));
    final taskText = find.textContaining('e2e');
    expect(taskText, findsOneWidget);
  });
}
