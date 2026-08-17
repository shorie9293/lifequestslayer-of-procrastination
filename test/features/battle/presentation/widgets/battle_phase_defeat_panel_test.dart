import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/battle/presentation/widgets/battle_phase.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

void main() {
  Task buildTask({required List<SubTask> subtasks}) => Task(
        id: 'task-1',
        title: '討伐試験',
        subTasks: subtasks,
      );

  Future<void> pumpPanel(WidgetTester tester, Task task,
      {ValueChanged<SubTask>? onSubTaskTap}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DefeatSubTaskPanel(
              task: task,
              onSubTaskTap: onSubTaskTap ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  group('DefeatSubTaskPanel（UX-3: 討伐失敗時の残サブタスク表示）', () {
    testWidgets('残りサブタスク数を表示する', (tester) async {
      final task = buildTask(subtasks: [
        SubTask(title: '完了', isCompleted: true),
        SubTask(title: '残りA', isCompleted: false),
        SubTask(title: '残りB', isCompleted: false),
      ]);
      await pumpPanel(tester, task);

      expect(find.text('残りサブタスク: 2'), findsOneWidget);
      expect(find.byKey(AppKeys.defeatSubTaskCount), findsOneWidget);
    });

    testWidgets('未完了サブタスク一覧を表示する（完了済みは非表示）', (tester) async {
      final task = buildTask(subtasks: [
        SubTask(title: '完了サブ', isCompleted: true),
        SubTask(title: '残りサブ1', isCompleted: false),
        SubTask(title: '残りサブ2', isCompleted: false),
      ]);
      await pumpPanel(tester, task);

      expect(find.text('・残りサブ1'), findsOneWidget);
      expect(find.text('・残りサブ2'), findsOneWidget);
      expect(find.text('・完了サブ'), findsNothing);
    });

    testWidgets('未完了サブタスクをタップすると onSubTaskTap が呼ばれる', (tester) async {
      SubTask? tapped;
      final task = buildTask(subtasks: [
        SubTask(title: '残りA', isCompleted: false),
      ]);
      await pumpPanel(tester, task, onSubTaskTap: (s) => tapped = s);

      await tester.tap(find.text('・残りA'));
      await tester.pump();

      expect(tapped, isNotNull);
      expect(tapped!.title, '残りA');
    });

    testWidgets('未完了リストはスクロール可能（dragUntilVisible で末尾まで到達）', (tester) async {
      // 十分な数の未完了サブタスクでリストを溢れさせる
      final task = buildTask(subtasks: List.generate(30, (i) {
        final done = i < 5;
        return SubTask(
            title: done ? '完了サブ$i' : '残りサブ$i', isCompleted: done);
      }));
      await pumpPanel(tester, task);

      // 初期表示では末尾のサブタスクは見えていない
      expect(find.text('・残りサブ29'), findsNothing);

      // スクロールで末尾のサブタスクを可視化
      await tester.dragUntilVisible(
        find.text('・残りサブ29'),
        find.byKey(AppKeys.defeatSubTaskList),
        const Offset(0, -100),
      );
      expect(find.text('・残りサブ29'), findsOneWidget);
    });

    testWidgets('未完了サブタスクが無い場合はパネルを表示しない', (tester) async {
      final task = buildTask(subtasks: [
        SubTask(title: '完了', isCompleted: true),
      ]);
      await pumpPanel(tester, task);

      expect(find.byKey(AppKeys.defeatSubTaskPanel), findsNothing);
    });
  });
}
