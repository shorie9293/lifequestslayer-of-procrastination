import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/data/task_template_repository.dart';
import 'package:rpg_todo/features/guild/domain/task_template.dart';
import 'package:rpg_todo/features/guild/presentation/task_template_screen.dart';

Future<void> _pumpWith(
  WidgetTester tester, {
  required TaskTemplateRepository repository,
  void Function(Task task)? onTaskCreated,
  Size viewSize = const Size(1080, 6000),
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TaskTemplateScreen(
        repository: repository,
        onTaskCreated: onTaskCreated,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('空状態: 定型0件では空状態が表示される', (tester) async {
    await _pumpWith(tester, repository: InMemoryTaskTemplateRepository());
    expect(find.byKey(AppKeys.taskTemplateEmptyState), findsOneWidget);
    expect(find.byKey(AppKeys.taskTemplateCount), findsOneWidget);
  });

  testWidgets('一覧: 保存済み定型が件数つきで表示される', (tester) async {
    final repo = InMemoryTaskTemplateRepository();
    await repo.save([
      TaskTemplate(
          id: 't1',
          name: '朝のあいさつ',
          title: '朝のクエスト',
          rank: QuestRank.A,
          subTaskTitles: ['洗面']),
      TaskTemplate(id: 't2', name: '夜の整理', title: '夜のクエスト'),
    ]);
    await _pumpWith(tester, repository: repo);
    expect(find.byKey(AppKeys.taskTemplateRow('t1')), findsOneWidget);
    expect(find.byKey(AppKeys.taskTemplateRow('t2')), findsOneWidget);
    expect(find.text('2件'), findsOneWidget);
  });

  testWidgets('検索: 部分一致で絞り込み・件数も連動・クリアで復元', (tester) async {
    final repo = InMemoryTaskTemplateRepository();
    await repo.save([
      TaskTemplate(id: 't1', name: '朝のあいさつ', title: '朝のクエスト'),
      TaskTemplate(id: 't2', name: '夜の整理', title: '夜のクエスト'),
    ]);
    await _pumpWith(tester, repository: repo);

    await tester.enterText(find.byKey(AppKeys.taskTemplateSearchField), '朝');
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.taskTemplateRow('t1')), findsOneWidget);
    expect(find.byKey(AppKeys.taskTemplateRow('t2')), findsNothing);
    expect(find.text('1件'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.taskTemplateSearchClear));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.taskTemplateRow('t2')), findsOneWidget);
  });

  testWidgets('ワンタップ起票: 起票ボタンで組立済みTaskがコールバックに渡る', (tester) async {
    final repo = InMemoryTaskTemplateRepository();
    final created = <Task>[];
    await repo.save([
      TaskTemplate(
        id: 't1',
        name: '朝のあいさつ',
        title: '朝のクエスト',
        rank: QuestRank.S,
        repeatInterval: RepeatInterval.weekly,
        repeatWeekdays: [1, 3],
        subTaskTitles: ['洗面', '着替え'],
        targetTimeMinutes: 10,
      ),
    ]);
    await _pumpWith(
      tester,
      repository: repo,
      onTaskCreated: created.add,
    );

    await tester.tap(find.byKey(AppKeys.taskTemplateCreateQuestButton)
        .first);
    await tester.pumpAndSettle();

    expect(created.length, 1);
    final task = created.single;
    expect(task.title, '朝のクエスト');
    expect(task.rank, QuestRank.S);
    expect(task.status, TaskStatus.inGuild);
    expect(task.isCompleted, isFalse);
    expect(task.repeatWeekdays, [1, 3]);
    expect(task.subTasks.map((s) => s.title).toList(), ['洗面', '着替え']);
    expect(task.targetTimeMinutes, 10);
    expect(task.id, isNot('t1'), reason: '起票IDは定型IDを流用しない');
  });

  testWidgets('追加→保存: ダイアログで入力した定型が一覧とリポジトリに反映される', (tester) async {
    final repo = InMemoryTaskTemplateRepository();
    await _pumpWith(tester, repository: repo);

    await tester.tap(find.byKey(AppKeys.taskTemplateCreateButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(AppKeys.taskTemplateNameField), '散歩');
    await tester.enterText(find.byKey(AppKeys.taskTemplateTitleField), '朝の散歩');
    await tester.enterText(find.byKey(AppKeys.taskTemplateSubTaskField), '着替え');
    await tester.tap(find.byKey(AppKeys.taskTemplateSubTaskAdd));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.taskTemplateSaveButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.taskTemplateRow('t1')), findsNothing,
        reason: '新規IDは採番されるため固定idではない');
    expect(find.text('1件'), findsOneWidget);
    final loaded = await repo.load();
    expect(loaded.length, 1);
    expect(loaded.first.name, '散歩');
    expect(loaded.first.title, '朝の散歩');
    expect(loaded.first.subTaskTitles, ['着替え']);
  });

  testWidgets('追加→保存: 同名の定型は保存されずエラー表示が出る', (tester) async {
    final repo = InMemoryTaskTemplateRepository();
    await repo.save([TaskTemplate(id: 't1', name: '散歩', title: 'x')]);
    await _pumpWith(tester, repository: repo);

    await tester.tap(find.byKey(AppKeys.taskTemplateCreateButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.taskTemplateNameField), '散歩');
    await tester.enterText(find.byKey(AppKeys.taskTemplateTitleField), 'y');
    await tester.tap(find.byKey(AppKeys.taskTemplateSaveButton));
    await tester.pumpAndSettle();

    expect(find.text('同名の定型が既に存在します'), findsOneWidget);
    expect(find.byKey(AppKeys.taskTemplateSaveButton), findsOneWidget,
        reason: 'ダイアログは開いたまま');
    expect((await repo.load()).length, 1);
  });

  testWidgets('削除: 確認ダイアログの確定で一覧とリポジトリから消える', (tester) async {
    final repo = InMemoryTaskTemplateRepository();
    await repo.save([
      TaskTemplate(id: 't1', name: '朝', title: 'x'),
      TaskTemplate(id: 't2', name: '夜', title: 'y'),
    ]);
    await _pumpWith(tester, repository: repo);

    // 正規化名の Unicode 昇順では「夜」(t2) が先頭
    await tester.tap(find.byKey(AppKeys.taskTemplateDeleteButton).first);
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.taskTemplateConfirmDelete), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.deleteButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.taskTemplateRow('t2')), findsNothing);
    expect(find.text('1件'), findsOneWidget);
    final loaded = await repo.load();
    expect(loaded.map((t) => t.id).toList(), ['t1']);
  });

  testWidgets('削除: キャンセルでは消えない', (tester) async {
    final repo = InMemoryTaskTemplateRepository();
    await repo.save([TaskTemplate(id: 't1', name: '朝', title: 'x')]);
    await _pumpWith(tester, repository: repo);

    await tester.tap(find.byKey(AppKeys.taskTemplateDeleteButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.taskTemplateRow('t1')), findsOneWidget);
    expect((await repo.load()).length, 1);
  });
}
