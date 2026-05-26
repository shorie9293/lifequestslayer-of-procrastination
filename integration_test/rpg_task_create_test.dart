// 天浮橋計画 — T2: タスク作成フローテスト
// rpg_task_create — バリデーションと作成成功
// イシコリドメ（Ishikori）鍛造 — 令和八年皐月二十五日
//
// 単独実行: flutter test --no-pub integration_test/rpg_task_create_test.dart

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

  try {
    Hive.registerAdapter(TaskAdapter());
  } catch (_) {}
  try {
    Hive.registerAdapter(TaskStatusAdapter());
  } catch (_) {}
  try {
    Hive.registerAdapter(QuestionRankAdapter());
  } catch (_) {}
  try {
    Hive.registerAdapter(PlayerAdapter());
  } catch (_) {}
  try {
    Hive.registerAdapter(JobAdapter());
  } catch (_) {}
  try {
    Hive.registerAdapter(RepeatIntervalAdapter());
  } catch (_) {}
  try {
    Hive.registerAdapter(SubTaskAdapter());
  } catch (_) {}

  configureDependencies();
  try {
    await NotificationService().initialize();
  } catch (_) {}
  try {
    await QuizService.loadQuestions();
  } catch (_) {}
}

Future<void> initForTests() async {
  await _ensureGlobalInit();
  runApp(const RPGTodoApp());
}

/// チュートリアル・報酬ダイアログをまとめて片付ける
Future<void> dismissDialogs(WidgetTester tester) async {
  for (final text in [
    '理解した！',
    'スキップ',
    'ありがたき幸せ！',
    '受け取る！',
    '閉じる',
    '指南を受ける',
  ]) {
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

  testWidgets('T2: タスク作成 — バリデーションと作成成功', (tester) async {
    await initForTests();
    await tester.pump(const Duration(seconds: 2));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await dismissDialogs(tester);
    await switchTab(tester, '寄合所');

    // FABの存在確認
    expect(
      find.byType(FloatingActionButton),
      findsOneWidget,
      reason: 'T2: FABが表示されていること',
    );

    // FABをタップ → 作成ダイアログ表示
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump(const Duration(seconds: 1));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    // ダイアログの表示確認
    expect(
      find.text('新規依頼作成'),
      findsOneWidget,
      reason: 'T2: 作成ダイアログが表示されること',
    );
    expect(
      find.byType(TextField),
      findsWidgets,
      reason: 'T2: タイトル入力欄が存在すること',
    );

    // 空バリデーション：タイトル空で作成 → ダイアログが閉じない
    await tester.tap(find.text('作成'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('新規依頼作成'),
      findsOneWidget,
      reason: 'T2: 空タイトルでは作成できずダイアログが閉じないこと（バリデーション）',
    );

    // タイトル入力 → 作成成功
    final tf = find.byType(TextField).first;
    await tester.enterText(tf, 't2_test_task');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('作成'));
    await tester.pump(const Duration(seconds: 1));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    // ダイアログが閉じたこと
    expect(
      find.text('新規依頼作成'),
      findsNothing,
      reason: 'T2: 作成成功後にダイアログが閉じること',
    );

    // 作成されたタスクが一覧に表示されていること
    expect(
      find.textContaining('t2_test'),
      findsWidgets,
      reason: 'T2: 作成したタスクが一覧に表示されること',
    );
  });
}
