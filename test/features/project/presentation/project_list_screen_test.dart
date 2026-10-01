// 計画の陣（プロジェクト一覧）画面の試練
//
// PlayerViewModel は Fake リポジトリで headless 構築、
// クエスト一覧は tasksOverride で注入する。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rpg_todo/domain/models/job.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/project/presentation/project_keys.dart';
import 'package:rpg_todo/features/project/presentation/project_list_screen.dart';

class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player = Player();
  @override
  Future<Player> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player p) async => _player = p;
  @override
  Future<void> close() async {}
}

Player _mysticPlayer({
  List<ProjectGroup>? projects,
  Map<String, String>? taskProjects,
}) {
  return Player(
    currentJob: Job.mystic,
    jobLevels: {Job.mystic: 12},
    projects: projects,
    taskProjects: taskProjects,
  );
}

Task _task(String id, {bool isCompleted = false}) =>
    Task(id: id, title: 'クエスト$id', isCompleted: isCompleted);

Future<PlayerViewModel> _pump(
  WidgetTester tester, {
  Player? player,
  List<Task>? tasks,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _MockPlayerRepo();
  final vm = PlayerViewModel(repo);
  final effectivePlayer = player ?? _mysticPlayer();
  await repo.savePlayer(effectivePlayer);
  vm.player = effectivePlayer;

  await tester.pumpWidget(
    ChangeNotifierProvider<PlayerViewModel>.value(
      value: vm,
      child: MaterialApp(
        home: ProjectListScreen(tasksOverride: tasks),
      ),
    ),
  );
  await tester.pump();
  return vm;
}

void main() {
  testWidgets('画面キーと AppBar タイトル「計画の陣」が存在する', (tester) async {
    await _pump(tester);

    expect(find.byKey(ProjectAppKeys.projectScreen), findsOneWidget);
    expect(find.text('計画の陣'), findsOneWidget);
    expect(find.byKey(ProjectAppKeys.projectCreateFab), findsOneWidget);
  });

  testWidgets('プロジェクトが無いとき空状態が出る', (tester) async {
    await _pump(tester);

    expect(find.byKey(ProjectAppKeys.projectEmptyState), findsOneWidget);
  });

  testWidgets('プロジェクト行に名前・bonusExp・クエスト数・進捗ラベルが表示される', (tester) async {
    await _pump(tester, tasks: [
      _task('t1', isCompleted: true),
      _task('t2'),
    ], player: _mysticPlayer(
      projects: [ProjectGroup(name: 'P', taskIds: ['t1', 't2'], bonusExp: 50)],
      taskProjects: {'t1': 'P', 't2': 'P'},
    ));

    expect(find.byKey(ProjectAppKeys.projectRow(0)), findsOneWidget);
    expect(find.text('P'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(ProjectAppKeys.projectList), findsOneWidget);
  });

  testWidgets('作成ダイアログで名前とbonusExpを入力してプロジェクトを追加できる', (tester) async {
    final vm = await _pump(tester);

    await tester.tap(find.byKey(ProjectAppKeys.projectCreateFab));
    await tester.pumpAndSettle();
    expect(find.byKey(ProjectAppKeys.projectCreateDialog), findsOneWidget);

    await tester.enterText(find.byKey(ProjectAppKeys.projectNameField), '新計画');
    await tester.enterText(find.byKey(ProjectAppKeys.projectBonusField), '100');
    await tester.tap(find.byKey(ProjectAppKeys.projectSubmit));
    await tester.pumpAndSettle();

    expect(vm.player.projects.single.name, '新計画');
    expect(vm.player.projects.single.bonusExp, 100);
  });

  testWidgets('作成ダイアログ: 空名前で送信するとエラーが表示される', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(ProjectAppKeys.projectCreateFab));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ProjectAppKeys.projectSubmit));
    await tester.pumpAndSettle();

    expect(find.byKey(ProjectAppKeys.projectCreateDialog), findsOneWidget);
    expect(find.text('名前を入力してください。'), findsOneWidget);
  });

  testWidgets('作成ダイアログ: bonusExp が非数値のときエラーが表示される', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(ProjectAppKeys.projectCreateFab));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ProjectAppKeys.projectNameField), '計画');
    await tester.enterText(find.byKey(ProjectAppKeys.projectBonusField), 'abc');
    await tester.tap(find.byKey(ProjectAppKeys.projectSubmit));
    await tester.pumpAndSettle();

    expect(find.byKey(ProjectAppKeys.projectCreateDialog), findsOneWidget);
    expect(find.text('数値（0以上）を入力してください。'), findsOneWidget);
  });

  testWidgets('編集ダイアログで改名できる', (tester) async {
    final vm = await _pump(tester, player: _mysticPlayer(
      projects: [ProjectGroup(name: '旧', bonusExp: 10)],
    ));

    await tester.tap(find.byKey(ProjectAppKeys.projectMenu(0)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    expect(find.byKey(ProjectAppKeys.projectEditDialog), findsOneWidget);

    await tester.enterText(find.byKey(ProjectAppKeys.projectNameField), '新');
    await tester.tap(find.byKey(ProjectAppKeys.projectEditSubmit));
    await tester.pumpAndSettle();

    expect(vm.player.projects.single.name, '新');
  });

  testWidgets('削除は確認ダイアログ経由で行われ、所属タスクの割り当ても消える', (tester) async {
    final vm = await _pump(tester, tasks: [_task('t1')], player: _mysticPlayer(
      projects: [ProjectGroup(name: 'P')],
      taskProjects: {'t1': 'P'},
    ));

    await tester.tap(find.byKey(ProjectAppKeys.projectMenu(0)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(find.byKey(ProjectAppKeys.projectDeleteDialog), findsOneWidget);

    await tester.tap(find.byKey(ProjectAppKeys.projectDeleteConfirm));
    await tester.pumpAndSettle();

    expect(vm.player.projects, isEmpty);
    expect(vm.player.taskProjects.containsKey('t1'), isFalse);
  });

  testWidgets('行タップで詳細シートが開き、未割り当てクエストを assign できる', (tester) async {
    final vm = await _pump(tester, tasks: [_task('t1'), _task('t2')], player: _mysticPlayer(
      projects: [ProjectGroup(name: 'P')],
    ));

    await tester.tap(find.byKey(ProjectAppKeys.projectRow(0)));
    await tester.pumpAndSettle();
    expect(find.byKey(ProjectAppKeys.projectDetailSheet), findsOneWidget);

    await tester.tap(find.byKey(ProjectAppKeys.assignButton('t2')));
    await tester.pumpAndSettle();

    expect(vm.player.taskProjects['t2'], 'P');
    expect(vm.player.projects.single.taskIds, contains('t2'));
  });

  testWidgets('詳細シートで所属クエストを unassign できる', (tester) async {
    final vm = await _pump(tester, tasks: [_task('t1')], player: _mysticPlayer(
      projects: [ProjectGroup(name: 'P')],
      taskProjects: {'t1': 'P'},
    ));

    await tester.tap(find.byKey(ProjectAppKeys.projectRow(0)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ProjectAppKeys.unassignButton('t1')));
    await tester.pumpAndSettle();

    expect(vm.player.taskProjects.containsKey('t1'), isFalse);
    expect(vm.player.projects.single.taskIds, isEmpty);
  });

  testWidgets('スキル未所持のプレイヤーには解放前ビューが出る', (tester) async {
    await _pump(tester, player: Player(currentJob: Job.adventurer));

    expect(find.byKey(ProjectAppKeys.projectRow(0)), findsNothing);
    expect(find.byKey(ProjectAppKeys.projectCreateFab), findsNothing);
    expect(find.text('魔導師Lv10で解放'), findsOneWidget);
  });
}