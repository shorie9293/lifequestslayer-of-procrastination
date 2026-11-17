// 空状態の共通部品（EmptyStateView）普及の試練。
//
// 0件データのとき、各画面が生 Text ではなく EmptyStateView を1つ描くこと、
// および行動導線がある画面では行動ボタン（Semantics id 'btn_empty_state_action'）
// が1つだけ出ることを検める。文言は既存のまま（一字も変えない）ので、
// 旧来の文言が見出し・説明として残っていることも併せて確認する。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rpg_todo/core/crash/crash_log_repository.dart';
import 'package:rpg_todo/core/crash/crash_log_screen.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/widgets/empty_state.dart';
import 'package:rpg_todo/domain/models/job.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/battle/presentation/enemy_catalog_screen.dart';
import 'package:rpg_todo/features/calendar_export/presentation/calendar_export_screen.dart';
import 'package:rpg_todo/features/crossapp/presentation/cross_app_title_encyclopedia_screen.dart';
import 'package:rpg_todo/features/guild/data/task_template_repository.dart';
import 'package:rpg_todo/features/guild/presentation/estimate_accuracy_screen.dart';
import 'package:rpg_todo/features/guild/presentation/quest_streak_screen.dart';
import 'package:rpg_todo/features/guild/presentation/task_template_screen.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/project/presentation/project_keys.dart';
import 'package:rpg_todo/features/project/presentation/project_list_screen.dart';

const String _actionSemanticsId = 'btn_empty_state_action';

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

void main() {
  testWidgets('計画の陣: 0件で EmptyStateView と行動ボタンが1つ出る', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _MockPlayerRepo();
    final vm = PlayerViewModel(repo);
    final player = Player(currentJob: Job.mystic, jobLevels: {Job.mystic: 12});
    await repo.savePlayer(player);
    vm.player = player;

    await tester.pumpWidget(
      ChangeNotifierProvider<PlayerViewModel>.value(
        value: vm,
        child: const MaterialApp(home: ProjectListScreen(tasksOverride: [])),
      ),
    );
    await tester.pump();

    expect(find.byType(EmptyStateView), findsOneWidget);
    // 旧 Key・旧文言は不変。
    expect(find.byKey(ProjectAppKeys.projectEmptyState), findsOneWidget);
    expect(find.text('プロジェクトがありません'), findsOneWidget);
    expect(find.text('右下の ＋ から新しい計画を作ろう。'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsOneWidget);
  });

  testWidgets('見積もり精度: 0件で EmptyStateView と行動ボタンが1つ出る', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EstimateAccuracyScreen(recordsOverride: [], tasksOverride: []),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('まだ記録がありません。'), findsOneWidget);
    expect(find.text('「実績を記録」から見積もりと実績を残そう。'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsOneWidget);
  });

  testWidgets('定型一覧: 0件で EmptyStateView と行動ボタンが1つ出る', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TaskTemplateScreen(repository: InMemoryTaskTemplateRepository()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.byKey(AppKeys.taskTemplateEmptyState), findsOneWidget);
    expect(find.text('定型はまだありません\n右下の + で追加できます'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsOneWidget);
  });

  testWidgets('ストリーク: 0件で EmptyStateView を出し行動ボタンは出さない', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: QuestStreakScreen(
        tasksOverride: [],
        streaksOverride: {},
        now: null,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('まだストリークがありません。'), findsOneWidget);
    expect(find.text('クエストを完了すると連続記録が育ちます。'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsNothing);
  });

  testWidgets('称号図鑑: 0件で EmptyStateView、絞り込み中は解除の行動ボタン', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CrossAppTitleEncyclopediaScreen(ownedTitles: [], definitions: []),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('該当する称号はありません'), findsOneWidget);
    // すべて表示（絞り込みなし）では解除の導線を差し出さない。
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsNothing);

    // 絞り込みを掛けると解除の行動ボタンが1つ出る。
    await tester.tap(find.byKey(
        AppKeys.crossAppTitleFilterChip('earned')));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsOneWidget);
  });

  testWidgets('カレンダー書き出し: 0件で EmptyStateView を出し行動ボタンは出さない', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CalendarExportScreen(tasksOverride: []),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('書き出せるクエストがありません'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsNothing);
  });

  testWidgets('不具合ログ: 0件で EmptyStateView を出す', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CrashLogScreen(repository: InMemoryCrashLogRepository()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.byKey(AppKeys.crashLogEmpty), findsOneWidget);
    expect(find.text('記録された不具合はありません'), findsOneWidget);
  });

  testWidgets('敵図鑑: 0件で EmptyStateView を出す', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EnemyCatalogScreen(entriesOverride: []),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.byKey(AppKeys.enemyCatalogEmpty), findsOneWidget);
    expect(find.text('図鑑の情報がありません。'), findsOneWidget);
  });
}
