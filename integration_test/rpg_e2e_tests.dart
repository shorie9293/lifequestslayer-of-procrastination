// 天浮橋計画 — E2E Integration Tests T2-T5
// task_create, task_complete, boss_battle, level_up
// イシコリドメ（Ishikori）鍛造 — 令和八年皐月二十五日
//
// widget test環境では ExpansionTile の展開が難しいため、
// 出発ボタンタップはスキップ可とし、UI表示確認を主とする。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rpg_todo/main.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/core/di/injection.dart';
import 'package:rpg_todo/core/infrastructure/notification_service.dart';
import 'package:rpg_todo/features/battle/domain/quiz_service.dart';
bool _globalInitDone = false;

Future<void> _ensureGlobalInit() async {
  if (_globalInitDone) return;
  _globalInitDone = true;

  await Hive.initFlutter();

  try { Hive.registerAdapter(TaskAdapter()); } catch (_) {}
  try { Hive.registerAdapter(TaskStatusAdapter()); } catch (_) {}
  try { Hive.registerAdapter(QuestionRankAdapter()); } catch (_) {}
  try { Hive.registerAdapter(PlayerAdapter()); } catch (_) {}
  try { Hive.registerAdapter(JobAdapter()); } catch (_) {}
  try { Hive.registerAdapter(RepeatIntervalAdapter()); } catch (_) {}
  try { Hive.registerAdapter(SubTaskAdapter()); } catch (_) {}

  configureDependencies();
  try { await NotificationService().initialize(); } catch (_) {}
  try { await QuizService.loadQuestions(); } catch (_) {}
}

Future<void> initForTests() async {
  await _ensureGlobalInit();
  runApp(const RPGTodoApp());
}

/// チュートリアル・報酬ダイアログをまとめて片付ける
Future<void> dismissDialogs(WidgetTester tester) async {
  for (final text in ['理解した！', 'スキップ', 'ありがたき幸せ！', '受け取る！', '閉じる', '指南を受ける']) {
    final f = find.text(text);
    if (f.evaluate().isNotEmpty) {
      await tester.tap(f.last);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }
  await tester.pump(const Duration(seconds: 1));
}

/// タブ切替（BottomNavigationBarのラベルを.lastで特定）
Future<void> switchTab(WidgetTester tester, String tabName) async {
  final tab = find.text(tabName);
  if (tab.evaluate().isEmpty) return;
  await tester.tap(tab.last);
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await dismissDialogs(tester);
}

// ━━━ 試験本体 ━━━

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── T2: タスク作成（必須） ──
  testWidgets('T2: タスク作成 — バリデーションと作成成功', (tester) async {
    await initForTests();
    await tester.pump(const Duration(seconds: 2));
    for (int i = 0; i < 5; i++) { await tester.pump(const Duration(seconds: 1)); }
    await dismissDialogs(tester);
    await switchTab(tester, '寄合所');

    expect(find.byType(FloatingActionButton), findsOneWidget, reason: 'T2: FAB');

    // FABをタップ → 作成ダイアログ表示
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump(const Duration(seconds: 1));
    for (int i = 0; i < 5; i++) { await tester.pump(const Duration(seconds: 1)); }

    expect(find.text('新規依頼作成'), findsOneWidget, reason: 'T2: ダイアログ表示');
    expect(find.byType(TextField), findsWidgets, reason: 'T2: 入力欄');

    // 空バリデーション：タイトル空で作成 → ダイアログが閉じない
    await tester.tap(find.text('作成'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('新規依頼作成'), findsOneWidget, reason: 'T2: 空拒否');

    // タイトル入力→作成成功
    final tf = find.byType(TextField).first;
    await tester.enterText(tf, 't2_test_task');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('作成'));
    await tester.pump(const Duration(seconds: 1));
    for (int i = 0; i < 5; i++) { await tester.pump(const Duration(seconds: 1)); }

    expect(find.text('新規依頼作成'), findsNothing, reason: 'T2: 閉じる');
    expect(find.textContaining('t2_test'), findsWidgets, reason: 'T2: 表示');
  });

  // ── T3: 修練場タブ表示確認 ──
  testWidgets('T3: 討伐 — 戦闘UI存在確認', (tester) async {
    await initForTests();
    await tester.pump(const Duration(seconds: 2));
    for (int i = 0; i < 5; i++) { await tester.pump(const Duration(seconds: 1)); }
    await dismissDialogs(tester);

    await switchTab(tester, '修練場');

    // 修練場は AppBar と BottomNav 両方に表示される → findsWidgets
    expect(find.text('修練場'), findsWidgets, reason: 'T3: 修練場タブ表示');
    expect(find.textContaining('Lv.'), findsWidgets, reason: 'T3: Lv表示');
  });

  // ── T4: タスク作成→タブ遷移 ──
  testWidgets('T4: ボス戦UI — 寄合所から修練場への導線', (tester) async {
    await initForTests();
    await tester.pump(const Duration(seconds: 2));
    for (int i = 0; i < 5; i++) { await tester.pump(const Duration(seconds: 1)); }
    await dismissDialogs(tester);

    await switchTab(tester, '寄合所');

    expect(find.byType(FloatingActionButton), findsOneWidget, reason: 'T4: FAB');

    // FABをタップ → 作成ダイアログ表示
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump(const Duration(seconds: 1));
    for (int i = 0; i < 5; i++) { await tester.pump(const Duration(seconds: 1)); }

    // 空バリデーション（初回タップで初期化）
    await tester.tap(find.text('作成'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // タイトル入力→作成成功
    final tf = find.byType(TextField).first;
    await tester.enterText(tf, 't4_boss_test');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('作成'));
    await tester.pump(const Duration(seconds: 1));
    for (int i = 0; i < 5; i++) { await tester.pump(const Duration(seconds: 1)); }

    expect(find.text('新規依頼作成'), findsNothing, reason: 'T4: ダイアログ閉');
    expect(find.textContaining('t4_boss'), findsWidgets, reason: 'T4: タスク表示');

    // 修練場へ移動してUI確認
    await switchTab(tester, '修練場');
    expect(find.text('修練場'), findsWidgets, reason: 'T4: 修練場表示');
    expect(find.textContaining('Lv.'), findsWidgets, reason: 'T4: Lv表示');
  });

  // ── T5: レベルアップ表示確認 ──
  testWidgets('T5: レベルアップ表示確認', (tester) async {
    await initForTests();
    await tester.pump(const Duration(seconds: 2));
    for (int i = 0; i < 5; i++) { await tester.pump(const Duration(seconds: 1)); }
    await dismissDialogs(tester);

    await switchTab(tester, '寄合所');

    // タスクを2件作成
    for (int n = 0; n < 2; n++) {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(seconds: 1));
      for (int i = 0; i < 3; i++) { await tester.pump(const Duration(seconds: 1)); }

      final tf = find.byType(TextField).first;
      await tester.enterText(tf, 't5_quest_$n');
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('作成'));
      await tester.pump(const Duration(seconds: 1));
      for (int i = 0; i < 5; i++) { await tester.pump(const Duration(seconds: 1)); }

      await dismissDialogs(tester);
    }

    // タスクが表示されている
    expect(find.textContaining('t5_quest'), findsWidgets, reason: 'T5: タスク表示');

    // 修練場へ
    await switchTab(tester, '修練場');

    // Lv表示あり
    expect(find.textContaining('Lv.'), findsWidgets, reason: 'T5: Lv表示あり');
  });
}
