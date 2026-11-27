// 「データの持ち出し／取り込み」の導線試練。
//
// 2026-11-28: 寺院画面のバックアップ／復元／CSVは管理操作なので設定ハブへ移設した
// （1機能1入口・寺院は「遊び」の画面へ戻す）。ここでは
//   ① 設定ハブに3つの導線がある（タップ可能）
//   ② 寺院画面からは消えている
// を撃つ。共有シート／ファイル選択（プラグイン）は叩かない。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/settings/presentation/settings_hub_screen.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/temple/presentation/temple_screen.dart';

class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player;
  _MockPlayerRepo([Player? player]) : _player = player ?? Player();
  @override
  Future<Player> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player p) async => _player = p;
  @override
  Future<void> close() async {}
}

class _FakeTaskRepository implements ITaskRepository {
  @override
  Future<List<Task>> loadTasks() async => [
        Task(id: 't1', title: '魔物討伐', rank: QuestRank.B),
      ];
  @override
  Future<void> saveTasks(List<Task> tasks) async {}
  @override
  Future<void> close() async {}
}

class _MockSettingsRepo extends SettingsRepository {
  @override
  Future<int> getTutorialStep() async => 0;
  @override
  Future<void> setTutorialStep(int v) async {}
  @override
  Future<bool> getHasSeenConcept() async => false;
  @override
  Future<void> setHasSeenConcept(bool v) async {}
  @override
  Future<double> getFontSizeScale() async => 0.85;
  @override
  Future<void> setFontSizeScale(double v) async {}
  @override
  Future<bool> getKnowledgeQuestEnabled() async => true;
  @override
  Future<void> setKnowledgeQuestEnabled(bool v) async {}
  @override
  Future<bool> getTutorialSkipped() async => false;
  @override
  Future<void> setTutorialSkipped(bool v) async {}
  @override
  Future<bool> getTutorialChoiceMade() async => false;
  @override
  Future<void> setTutorialChoiceMade(bool v) async {}
  @override
  Future<bool> getJobTutorialCompleted() async => false;
  @override
  Future<void> setJobTutorialCompleted(bool v) async {}
  @override
  Future<bool> getDebugModeEnabled() async => false;
  @override
  Future<void> setDebugModeEnabled(bool v) async {}
  @override
  Future<bool> getSfxEnabled() async => true;
  @override
  Future<void> setSfxEnabled(bool v) async {}
  @override
  Future<double> getSfxVolume() async => 0.7;
  @override
  Future<void> setSfxVolume(double v) async {}
  @override
  Future<bool> getBattleSceneEnabled() async => true;
  @override
  Future<void> setBattleSceneEnabled(bool v) async {}
  @override
  Future<bool> getMorningNotificationEnabled() async => true;
  @override
  Future<void> setMorningNotificationEnabled(bool v) async {}
  @override
  Future<ThemeMode> getThemeMode() async => ThemeMode.dark;
  @override
  Future<void> setThemeMode(ThemeMode mode) async {}
  @override
  Future<DateTime?> getFatiguePopupDate() async => null;
  @override
  Future<void> saveFatiguePopupDate(DateTime d) async {}
  @override
  Future<void> deleteFatiguePopupDate() async {}
  @override
  Future<void> resetTutorial() async {}
  @override
  Future<DateTime?> getLastBackupTime() async => null;
  @override
  Future<void> setLastBackupTime(DateTime time) async {}
}

Future<Widget> _createHub() async {
  final playerVM = PlayerViewModel(_MockPlayerRepo());
  await playerVM.load();
  final taskVM = TaskViewModel(_FakeTaskRepository(), playerVM);
  final settingsVM = SettingsViewModel(_MockSettingsRepo());
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
      ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
      ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
    ],
    child: const MaterialApp(home: SettingsHubScreen()),
  );
}

Future<void> _reveal(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  group('設定ハブ — データの持ち出し／取り込み', () {
    testWidgets('3つの導線が表示され、タップ可能', (tester) async {
      await tester.pumpWidget(await _createHub());
      await _reveal(tester, AppKeys.templeCsvExportButton);

      for (final key in [
        AppKeys.templeBackupButton,
        AppKeys.templeRestoreButton,
        AppKeys.templeCsvExportButton,
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key が無い');
      }
      expect(find.text('バックアップをファイルに書き出す'), findsOneWidget);
      expect(find.text('バックアップをファイルから復元'), findsOneWidget);
      expect(find.text('クエストをCSVで書き出す'), findsOneWidget);
      expect(tester.getSize(find.byKey(AppKeys.templeCsvExportButton)).width,
          greaterThan(0));
    });

    testWidgets('CSVタップで例外が出ない（共有層は握り潰して通知）', (tester) async {
      await tester.pumpWidget(await _createHub());
      await _reveal(tester, AppKeys.templeCsvExportButton);

      await tester.tap(find.byKey(AppKeys.templeCsvExportButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  });

  group('寺院画面 — 管理操作は移設済み', () {
    testWidgets('バックアップ／復元／CSVの導線は寺院に無い', (tester) async {
      final playerVM = PlayerViewModel(_MockPlayerRepo());
      await playerVM.load();
      final taskVM = TaskViewModel(_FakeTaskRepository(), playerVM);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
              ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
            ],
            child: const TempleScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(AppKeys.templeBackupButton), findsNothing);
      expect(find.byKey(AppKeys.templeRestoreButton), findsNothing);
      expect(find.byKey(AppKeys.templeCsvExportButton), findsNothing);
      expect(find.text('データバックアップ'), findsNothing);
      expect(find.text('データ復元'), findsNothing);
    });
  });
}
