// 見積もり精度レポート画面の試練（改善提案 #131）。
//
// - recordsOverride でサマリー値が EstimateAccuracyService の集計と一致すること
// - 記録行が新しい順に並び、レベル・誤差率・日付が表示されること
// - 0件のとき emptyState が出てリストが出ないこと
// - 追加ダイアログ→保存→再読込がリポジトリに到達し、新しい画面インスタンスで復元されること
// - 削除がリポジトリに到達して行が消えること

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/data/task_time_record_repository.dart';
import 'package:rpg_todo/features/guild/domain/estimate_accuracy.dart';
import 'package:rpg_todo/features/guild/domain/task_time_record.dart';
import 'package:rpg_todo/features/guild/presentation/estimate_accuracy_keys.dart';
import 'package:rpg_todo/features/guild/presentation/estimate_accuracy_screen.dart';

/// 見積もり100分の記録を作る（actual でずれ幅を変える）。
TaskTimeRecord rec(int actual, {DateTime? at, String taskId = 'task-1'}) =>
    TaskTimeRecord(
      taskId: taskId,
      title: 'クエスト$taskId',
      estimatedMinutes: 100,
      actualMinutes: actual,
      recordedAt: at,
    );

Task task(String id, {String? title, int estimate = 30}) => Task(
      id: id,
      title: title ?? 'クエスト$id',
      rank: QuestRank.B,
      targetTimeMinutes: estimate,
    );

/// 記録3件（的中1・超過1・余裕1、時刻をずらす）。
List<TaskTimeRecord> threeRecords() => [
      rec(100, at: DateTime(2026, 1, 1)), // 的中
      rec(150, at: DateTime(2026, 1, 2), taskId: 'task-2'), // 超過 +50%
      rec(60, at: DateTime(2026, 1, 3), taskId: 'task-3'), // 余裕 -40%
    ];

Future<void> pumpScreen(
  WidgetTester tester, {
  List<TaskTimeRecord>? records,
  List<Task>? tasks,
  TaskTimeRecordRepository? repository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: EstimateAccuracyScreen(
        recordsOverride: records,
        tasksOverride: tasks,
        repository: repository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('サマリー表示', () {
    testWidgets('サマリーラベルがサービス集計と一致する', (tester) async {
      final records = threeRecords();
      final stats = EstimateAccuracyService.buildStats(records);
      await pumpScreen(tester, records: records);

      expect(find.byKey(EstimateAccuracyKeys.summaryCard), findsOneWidget);
      expect(find.text(EstimateAccuracyService.summaryLabel(stats)),
          findsOneWidget);
    });

    testWidgets('的中率・平均誤差・平均時間がサービス集計と一致する', (tester) async {
      final records = threeRecords();
      final stats = EstimateAccuracyService.buildStats(records);
      await pumpScreen(tester, records: records);

      expect(
        find.descendant(
          of: find.byKey(EstimateAccuracyKeys.summaryCard),
          matching: find.text(stats.onTargetRateLabel),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(EstimateAccuracyKeys.summaryCard),
          matching: find.text(stats.averageErrorRateLabel),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(EstimateAccuracyKeys.summaryCard),
          matching: find.text(stats.averageTimeLabel),
        ),
        findsOneWidget,
      );
    });

    testWidgets('0件のときは「記録がありません」を出す', (tester) async {
      await pumpScreen(tester, records: const []);
      expect(find.text('記録がありません'), findsOneWidget);
    });

    testWidgets('平均時間ラベルは小数第1位固定の形式', (tester) async {
      await pumpScreen(tester, records: threeRecords());
      // avg est = 100.0, avg act = (100+150+60)/3 = 103.333...
      expect(find.text('見積 100.0分 / 実績 103.3分'), findsOneWidget);
    });

    testWidgets('サマリーに件数（3件）が含まれる', (tester) async {
      await pumpScreen(tester, records: threeRecords());
      expect(find.textContaining('（3件）'), findsOneWidget);
    });
  });

  group('記録行', () {
    testWidgets('行数が記録数と一致し、全行のKeyが存在する', (tester) async {
      final records = threeRecords();
      await pumpScreen(tester, records: records);

      expect(find.byKey(EstimateAccuracyKeys.list), findsOneWidget);
      for (final r in records) {
        expect(find.byKey(EstimateAccuracyKeys.recordRow(r.id)),
            findsOneWidget);
      }
    });

    testWidgets('記録行が新しい順に並ぶ', (tester) async {
      final records = threeRecords(); // recordedAt: 1/1, 1/2, 1/3
      await pumpScreen(tester, records: records);

      // sortByRecordedAtDesc の先頭は最も新しい task-3
      final positions = <String, double>{};
      for (final r in records) {
        final row = find.byKey(EstimateAccuracyKeys.recordRow(r.id));
        positions[r.taskId] = tester.getTopLeft(row).dy;
      }
      expect(positions['task-3']!, lessThan(positions['task-2']!));
      expect(positions['task-2']!, lessThan(positions['task-1']!));
    });

    testWidgets('レベルの絵文字とラベル・誤差率・日付が表示される', (tester) async {
      final records = threeRecords();
      await pumpScreen(tester, records: records);

      expect(find.text('🔥 超過'), findsOneWidget);
      expect(find.text('🎯 的中'), findsOneWidget);
      expect(find.text('🍃 余裕'), findsOneWidget);
      expect(find.text('誤差 +50%'), findsOneWidget);
      expect(find.text('誤差 -40%'), findsOneWidget);
      expect(find.text('誤差 ±0%'), findsOneWidget);
      expect(find.text('2026/01/03'), findsOneWidget);
      expect(find.text('見積 100分 / 実績 150分'), findsOneWidget);
    });

    testWidgets('0件のときは emptyState を出しリストを出さない', (tester) async {
      await pumpScreen(tester, records: const []);

      expect(find.byKey(EstimateAccuracyKeys.emptyState), findsOneWidget);
      expect(find.byKey(EstimateAccuracyKeys.list), findsNothing);
    });
  });

  group('記録追加（合成）', () {
    testWidgets('追加ダイアログ→保存がリポジトリに到達し、新しい画面インスタンスで復元される', (tester) async {
      final repo = InMemoryTaskTimeRecordRepository();
      final tasks = [task('q1'), task('q2', estimate: 45)];

      // リポジトリ注入（recordsOverride なし → ロードする）
      await tester.pumpWidget(MaterialApp(
        home: EstimateAccuracyScreen(
          tasksOverride: tasks,
          repository: repo,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(EstimateAccuracyKeys.emptyState), findsOneWidget);

      // FAB → ダイアログ
      await tester.tap(find.byKey(EstimateAccuracyKeys.addButton));
      await tester.pumpAndSettle();
      expect(find.byKey(EstimateAccuracyKeys.dialog), findsOneWidget);

      // クエスト選択 → 見積もり欄にプリフィル
      await tester.tap(find.byKey(EstimateAccuracyKeys.taskField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('クエストq2（見積 45分）').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(
          find.byKey(EstimateAccuracyKeys.estimatedField),
        ).controller!.text,
        '45',
      );

      // 実績を入れて保存
      await tester.enterText(
          find.byKey(EstimateAccuracyKeys.estimatedField), '45');
      await tester.enterText(find.byKey(EstimateAccuracyKeys.actualField), '60');
      await tester.tap(find.byKey(EstimateAccuracyKeys.saveButton));
      await tester.pumpAndSettle();

      // リポジトリに到達した
      final saved = await repo.loadAll();
      expect(saved.length, 1);
      expect(saved.first.taskId, 'q2');
      expect(saved.first.estimatedMinutes, 45);
      expect(saved.first.actualMinutes, 60);

      // ダイアログが閉じ、再読込で行が出る
      expect(find.byKey(EstimateAccuracyKeys.dialog), findsNothing);
      expect(
          find.byKey(EstimateAccuracyKeys.recordRow(saved.first.id)),
          findsOneWidget);

      // ★合成: 新しい画面インスタンスでも復元される
      await tester.pumpWidget(MaterialApp(
        home: EstimateAccuracyScreen(repository: repo),
      ));
      await tester.pumpAndSettle();
      expect(
        find.byKey(EstimateAccuracyKeys.recordRow(saved.first.id)),
        findsOneWidget,
      );
      expect(find.byKey(EstimateAccuracyKeys.emptyState), findsNothing);
    });

    testWidgets('数値不正のときはエラー表示のみで保存しない', (tester) async {
      final repo = InMemoryTaskTimeRecordRepository();
      await tester.pumpWidget(MaterialApp(
        home: EstimateAccuracyScreen(
          tasksOverride: [task('q1')],
          repository: repo,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(EstimateAccuracyKeys.addButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EstimateAccuracyKeys.taskField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('クエストq1（見積 30分）').last);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(EstimateAccuracyKeys.estimatedField), 'abc');
      await tester.enterText(find.byKey(EstimateAccuracyKeys.actualField), '60');
      await tester.tap(find.byKey(EstimateAccuracyKeys.saveButton));
      await tester.pumpAndSettle();

      expect(find.text('見積もり・実績は1以上の整数で入力してください'), findsOneWidget);
      expect(find.byKey(EstimateAccuracyKeys.dialog), findsOneWidget);
      expect((await repo.loadAll()).length, 0);
    });

    testWidgets('クエストが空のときは保存不可のメッセージを出す', (tester) async {
      final repo = InMemoryTaskTimeRecordRepository();
      await tester.pumpWidget(MaterialApp(
        home: EstimateAccuracyScreen(tasksOverride: const [], repository: repo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(EstimateAccuracyKeys.addButton));
      await tester.pumpAndSettle();

      expect(find.text('記録できるクエストがありません。'), findsOneWidget);
      final save = tester.widget<FilledButton>(
        find.byKey(EstimateAccuracyKeys.saveButton),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('キャンセルで保存しない', (tester) async {
      final repo = InMemoryTaskTimeRecordRepository();
      await tester.pumpWidget(MaterialApp(
        home: EstimateAccuracyScreen(
          tasksOverride: [task('q1')],
          repository: repo,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(EstimateAccuracyKeys.addButton));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(EstimateAccuracyKeys.estimatedField), '30');
      await tester.enterText(find.byKey(EstimateAccuracyKeys.actualField), '30');
      await tester.tap(find.byKey(EstimateAccuracyKeys.cancelButton));
      await tester.pumpAndSettle();

      expect(find.byKey(EstimateAccuracyKeys.dialog), findsNothing);
      expect((await repo.loadAll()).length, 0);
    });

    testWidgets('クエスト選択を替えると見積もりプリフィルも替わる', (tester) async {
      final repo = InMemoryTaskTimeRecordRepository();
      await tester.pumpWidget(MaterialApp(
        home: EstimateAccuracyScreen(
          tasksOverride: [task('q1'), task('q2', estimate: 45)],
          repository: repo,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(EstimateAccuracyKeys.addButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EstimateAccuracyKeys.taskField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('クエストq2（見積 45分）').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(
          find.byKey(EstimateAccuracyKeys.estimatedField),
        ).controller!.text,
        '45',
      );

      await tester.tap(find.byKey(EstimateAccuracyKeys.taskField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('クエストq1（見積 30分）').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(
          find.byKey(EstimateAccuracyKeys.estimatedField),
        ).controller!.text,
        '30',
      );
    });

    testWidgets('連続保存で複数行が蓄積される', (tester) async {
      final repo = InMemoryTaskTimeRecordRepository();
      final tasks = [task('q1'), task('q2')];
      await tester.pumpWidget(MaterialApp(
        home: EstimateAccuracyScreen(tasksOverride: tasks, repository: repo),
      ));
      await tester.pumpAndSettle();

      for (final (name, act) in [('q1', 30), ('q2', 90)]) {
        await tester.tap(find.byKey(EstimateAccuracyKeys.addButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(EstimateAccuracyKeys.taskField));
        await tester.pumpAndSettle();
        await tester.tap(find.text('クエスト$name（見積 30分）').last);
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byKey(EstimateAccuracyKeys.estimatedField), '30');
        await tester.enterText(
            find.byKey(EstimateAccuracyKeys.actualField), '$act');
        await tester.tap(find.byKey(EstimateAccuracyKeys.saveButton));
        await tester.pumpAndSettle();
      }

      expect((await repo.loadAll()).length, 2);
      expect(find.byKey(EstimateAccuracyKeys.list), findsOneWidget);
    });

    testWidgets('リポジトリ未注入（getIt未登録）でも実Hiveを開かず0件表示で落ちない', (tester) async {
      // getIt に登録がなければ InMemoryTaskTimeRecordRepository にフォールバックする。
      await tester.pumpWidget(const MaterialApp(
        home: EstimateAccuracyScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(EstimateAccuracyKeys.screen), findsOneWidget);
      expect(find.byKey(EstimateAccuracyKeys.emptyState), findsOneWidget);
      expect(find.byKey(EstimateAccuracyKeys.addButton), findsOneWidget);
    });
  });

  group('削除', () {
    testWidgets('削除がリポジトリに到達して行が消える', (tester) async {
      final repo = InMemoryTaskTimeRecordRepository();
      final r1 = rec(100, at: DateTime(2026, 1, 1));
      final r2 = rec(150, at: DateTime(2026, 1, 2), taskId: 'task-2');
      await repo.save(r1);
      await repo.save(r2);

      await tester.pumpWidget(MaterialApp(
        home: EstimateAccuracyScreen(repository: repo),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(EstimateAccuracyKeys.recordRow(r1.id)), findsOneWidget);
      expect(find.byKey(EstimateAccuracyKeys.recordRow(r2.id)), findsOneWidget);

      await tester.tap(find.byKey(EstimateAccuracyKeys.deleteButton(r1.id)));
      await tester.pumpAndSettle();

      expect(find.byKey(EstimateAccuracyKeys.recordRow(r1.id)), findsNothing);
      expect(find.byKey(EstimateAccuracyKeys.recordRow(r2.id)), findsOneWidget);
      final remaining = await repo.loadAll();
      expect(remaining.length, 1);
      expect(remaining.first.id, r2.id);
    });

    testWidgets('削除後にサマリーの件数表示も減る', (tester) async {
      final repo = InMemoryTaskTimeRecordRepository();
      await repo.save(rec(100, at: DateTime(2026, 1, 1)));
      await repo.save(rec(150, at: DateTime(2026, 1, 2), taskId: 'task-2'));

      await tester.pumpWidget(MaterialApp(
        home: EstimateAccuracyScreen(repository: repo),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('（2件）'), findsOneWidget);

      final first = (await repo.loadAll()).first;
      await tester.tap(find.byKey(EstimateAccuracyKeys.deleteButton(first.id)));
      await tester.pumpAndSettle();

      expect(find.textContaining('（2件）'), findsNothing);
      expect(find.textContaining('（1件）'), findsOneWidget);
    });
  });
}
