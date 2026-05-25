import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/guild/presentation/guild_screen.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/kozuchi/domain/kozuchi_quest_model.dart';
import 'package:rpg_todo/features/kozuchi/data/kozuchi_quest_service.dart';

// ━━━ DI Mock リポジトリ（Hive非依存） ━━━

class _MockPlayerRepository implements IPlayerRepository {
  @override
  Future<Player?> loadPlayer() async => Player();
  @override
  Future<void> savePlayer(Player player) async {}
  @override
  Future<void> close() async {}
}

class _MockTaskRepository implements ITaskRepository {
  @override
  Future<List<Task>> loadTasks() async => [];
  @override
  Future<void> saveTasks(List<Task> tasks) async {}
  @override
  Future<void> close() async {}
}

/// SettingsRepository は具象クラスのため extend して全Hiveメソッドをオーバーライド
class _MockSettingsRepository extends SettingsRepository {
  @override
  Future<double> getFontSizeScale() async => 0.85;
  @override
  Future<void> setFontSizeScale(double scale) async {}
  @override
  Future<bool> getKnowledgeQuestEnabled() async => true;
  @override
  Future<void> setKnowledgeQuestEnabled(bool enabled) async {}
  @override
  Future<void> saveFatiguePopupDate(DateTime date) async {}
  @override
  Future<DateTime?> getFatiguePopupDate() async => null;
  @override
  Future<void> deleteFatiguePopupDate() async {}
  @override
  Future<int> getTutorialStep() async => 0;
  @override
  Future<void> setTutorialStep(int step) async {}
  @override
  Future<bool> getHasSeenConcept() async => false;
  @override
  Future<void> setHasSeenConcept(bool value) async {}
  @override
  Future<bool> getTutorialSkipped() async => false;
  @override
  Future<void> setTutorialSkipped(bool value) async {}
  @override
  Future<bool> getTutorialChoiceMade() async => false;
  @override
  Future<void> setTutorialChoiceMade(bool value) async {}
  @override
  Future<bool> getJobTutorialCompleted() async => false;
  @override
  Future<void> setJobTutorialCompleted(bool value) async {}
  @override
  Future<void> resetTutorial() async {}
  @override
  Future<bool> getDebugModeEnabled() async => false;
  @override
  Future<void> setDebugModeEnabled(bool v) async {}
}

/// テスト用のDI注入済みGameViewModelを生成し、ロード完了まで待つ
/// tester.runAsync() 内で呼び出す必要あり（非同期loadDataとの衝突回避）
Future<GameViewModel> createLoadedViewModel() async {
  final vm = GameViewModel(
    pr: _MockPlayerRepository(),
    tr: _MockTaskRepository(),
    sr: _MockSettingsRepository(),
  );
  final start = DateTime.now();
  while (!vm.isLoaded) {
    if (DateTime.now().difference(start) > const Duration(seconds: 5)) {
      throw Exception('GameViewModel のロードがタイムアウトしました');
    }
    await Future.delayed(const Duration(milliseconds: 10));
  }
  // loadData() 内の後続処理（autoDeploy等）の完了を待つ
  await Future.delayed(const Duration(milliseconds: 50));
  return vm;
}

/// KozuchiQuestService のモック
class MockKozuchiQuestService implements IKozuchiQuestService {
  KozuchiQuest? quest;

  MockKozuchiQuestService({this.quest});

  @override
  Future<KozuchiQuest?> fetchActiveQuest() async => quest;
}

/// GuildScreen をポンプするヘルパー
Future<void> pumpGuildScreen(WidgetTester tester, GameViewModel vm) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<GameViewModel>.value(
      value: vm,
      child: const MaterialApp(
        home: GuildScreen(),
      ),
    ),
  );
  // 画面が完全に描画されるのを待つ
  await tester.pump();
  await tester.pump();
}

void main() {
  group('GuildScreen 見積もり時間表示テスト', () {
    // ━━━ 見積もり表示あり ━━━

    testWidgets(
        'ギルドタスクに targetTimeMinutes がある場合、'
        '「未着手の依頼（見積もり）: XX分」が表示される', (tester) async {
      late GameViewModel vm;

      await tester.runAsync(() async {
        vm = await createLoadedViewModel();

        // 見積もり時間付きのタスクを追加（受注しない → guildTasks に留まる）
        vm.addTask('討伐クエスト', rank: QuestRank.B, targetTimeMinutes: 45);
      });

      await pumpGuildScreen(tester, vm);

      // 見積もり時間のテキストが表示されていることを確認（完全一致）
      expect(find.text('未着手の依頼（見積もり）: 45分'), findsOneWidget);
    });

    testWidgets('複数ギルドタスクの見積もりが合計表示される', (tester) async {
      late GameViewModel vm;

      await tester.runAsync(() async {
        vm = await createLoadedViewModel();

        vm.addTask('クエストA', rank: QuestRank.B, targetTimeMinutes: 20);
        vm.addTask('クエストB', rank: QuestRank.A, targetTimeMinutes: 35);
        vm.addTask('クエストC', rank: QuestRank.S, targetTimeMinutes: 60);
      });

      await pumpGuildScreen(tester, vm);

      // 合計115分が表示されていることを確認
      expect(find.text('未着手の依頼（見積もり）: 115分'), findsOneWidget);
    });

    testWidgets(
        'ギルドタスクの一部だけ targetTimeMinutes がある場合、'
        'あるものだけ合計される', (tester) async {
      late GameViewModel vm;

      await tester.runAsync(() async {
        vm = await createLoadedViewModel();

        // 見積もりありのタスクと、なしのタスクを混在させる
        vm.addTask('見積もりあり', rank: QuestRank.B, targetTimeMinutes: 30);
        vm.addTask('見積もりなし', rank: QuestRank.B);
      });

      await pumpGuildScreen(tester, vm);

      // 30分のみの合計が表示される
      expect(find.text('未着手の依頼（見積もり）: 30分'), findsOneWidget);
    });

    // ━━━ 見積もり表示なし ━━━

    testWidgets(
        'ギルドタスクの targetTimeMinutes が null の場合、見積もり表示は出ない',
        (tester) async {
      late GameViewModel vm;

      await tester.runAsync(() async {
        vm = await createLoadedViewModel();

        // targetTimeMinutes なしのタスクを追加
        vm.addTask('テストクエスト', rank: QuestRank.B);
      });

      await pumpGuildScreen(tester, vm);

      // 見積もり時間のテキストが表示されていないことを確認
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('未着手の依頼（見積もり）'),
        ),
        findsNothing,
      );
    });

    testWidgets('タスクがない場合は見積もり表示が出ない', (tester) async {
      late GameViewModel vm;

      await tester.runAsync(() async {
        vm = await createLoadedViewModel();
        // タスクを追加しない
      });

      await pumpGuildScreen(tester, vm);

      // 見積もり表示は存在しない
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('未着手の依頼（見積もり）'),
        ),
        findsNothing,
      );

      // 空状態が表示されている（AppKeyで検証）
      expect(find.byKey(AppKeys.guildEmptyState), findsOneWidget);
    });
  });

  group('GuildScreen KozuchiQuest セクション', () {
    testWidgets(
        'KozuchiQuest が null の時は Kozuchi セクションが表示されない',
        (tester) async {
      late GameViewModel vm;

      await tester.runAsync(() async {
        vm = await createLoadedViewModel();
        vm.refreshKozuchiQuest();
        // KozuchiQuestService は null なのでセクションは表示されない
      });

      await pumpGuildScreen(tester, vm);

      expect(find.byKey(AppKeys.kozuchiSection), findsNothing);
    });

    testWidgets(
        'KozuchiQuest がある時は KozuchiQuestCard が表示される',
        (tester) async {
      late GameViewModel vm;

      await tester.runAsync(() async {
        vm = await createLoadedViewModel();
        // KozuchiQuestService をモックで注入
        vm.kozuchiQuestService = MockKozuchiQuestService(
          quest: const KozuchiQuest(
            title: '朝の祈り',
            description: '新しい一日への感謝と祈りを捧げよ',
            suggestedOffering: 100,
            guardianDeityEmoji: '🦊',
            guardianDeityLabel: '稲荷神',
          ),
        );
        await vm.refreshKozuchiQuest();
      });

      await pumpGuildScreen(tester, vm);

      // Kozuchiセクションが表示されている
      expect(find.byKey(AppKeys.kozuchiSection), findsOneWidget);
      expect(find.byKey(AppKeys.kozuchiQuestCard), findsOneWidget);
    });

    testWidgets(
        'KozuchiQuest が完了状態の時も表示される',
        (tester) async {
      late GameViewModel vm;

      await tester.runAsync(() async {
        vm = await createLoadedViewModel();
        vm.kozuchiQuestService = MockKozuchiQuestService(
          quest: const KozuchiQuest(
            title: '完了した試練',
            description: '完了テスト',
            suggestedOffering: 50,
            guardianDeityEmoji: '🐉',
            guardianDeityLabel: '龍神',
            isCompleted: true,
          ),
        );
        await vm.refreshKozuchiQuest();
      });

      await pumpGuildScreen(tester, vm);

      expect(find.byKey(AppKeys.kozuchiSection), findsOneWidget);
      expect(find.text('完了した試練'), findsOneWidget);
      expect(find.text('✅ 達成済み'), findsOneWidget);
    });
  });

  group('GuildScreen 緊急依頼セクション', () {
    testWidgets('緊急タスクがない時は緊急セクションが表示されない',
        (tester) async {
      late GameViewModel vm;

      await tester.runAsync(() async {
        vm = await createLoadedViewModel();
      });

      await pumpGuildScreen(tester, vm);

      // 緊急タスクがないのでセクションは非表示
      expect(find.byKey(AppKeys.guildUrgentSection), findsNothing);
    });

    testWidgets('24時間以内の期限があるタスクで緊急セクションが表示される',
        (tester) async {
      late GameViewModel vm;

      await tester.runAsync(() async {
        vm = await createLoadedViewModel();
        // 残り12時間の緊急タスクを追加
        final deadline =
            DateTime.now().add(const Duration(hours: 12));
        vm.addTask('緊急討伐クエスト',
            rank: QuestRank.A, deadline: deadline);
      });

      await pumpGuildScreen(tester, vm);

      // 緊急セクションが表示されている
      expect(find.byKey(AppKeys.guildUrgentSection), findsOneWidget);
      // 緊急タスクのタイトルが表示されている
      expect(find.textContaining('緊急討伐クエスト'), findsOneWidget);
      // 残り時間表示がある（時計アイコン付き）
      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });

    testWidgets('緊急タスクがなく通常タスクのみの場合でも通常表示は崩れない',
        (tester) async {
      late GameViewModel vm;

      await tester.runAsync(() async {
        vm = await createLoadedViewModel();
        // 期限が48時間先 = 緊急ではない
        final deadline =
            DateTime.now().add(const Duration(hours: 48));
        vm.addTask('通常依頼', rank: QuestRank.B, deadline: deadline);
      });

      await pumpGuildScreen(tester, vm);

      // 緊急セクションは表示されない
      expect(find.byKey(AppKeys.guildUrgentSection), findsNothing);
      // 通常依頼はギルドリストに表示される
      expect(find.textContaining('通常依頼'), findsOneWidget);
    });
  });
}
